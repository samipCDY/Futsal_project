import base64
import hashlib
import hmac
from datetime import timedelta
from unittest.mock import patch

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from grounds.models import Ground
from notifications.models import Notification

from . import payments
from .models import Booking

TEST_KEY = '8gBm/:&EnhH.1/q'


def client_for(profile):
    client = APIClient()
    client.force_authenticate(user=profile)
    return client


@override_settings(ESEWA_SECRET_KEY=TEST_KEY, ESEWA_PRODUCT_CODE='EPAYTEST', KHALTI_SECRET_KEY='test-khalti-key')
class OnlinePaymentTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.customer = make_profile(Role.CUSTOMER, 'Sita')
        self.other = make_profile(Role.CUSTOMER, 'Ram')
        self.ground = Ground.objects.create(
            owner=self.owner, name='Arena', area='Baneshwor', latitude='27.69', longitude='85.33',
            morning_price=1000, day_price=1200, evening_price=1500, status=Ground.Status.APPROVED,
        )
        self.tomorrow = timezone.localdate() + timedelta(days=1)

    def book(self, method='esewa', profile=None, start='18:00'):
        return client_for(profile or self.customer).post('/api/bookings/', {
            'ground': self.ground.id, 'date': self.tomorrow.isoformat(), 'start_time': start,
            'payment_method': method,
        }, format='json')

    def verify(self, booking_id, profile=None):
        return client_for(profile or self.customer).post(f'/api/bookings/{booking_id}/verify-payment/')

    def test_esewa_booking_holds_the_slot_with_a_correctly_signed_form(self):
        response = self.book()
        self.assertEqual(response.status_code, 201, response.json())
        body = response.json()
        self.assertEqual((body['status'], body['payment_status']), ('pending', 'unpaid'))
        self.assertIsNotNone(body['payment_due_by'])

        fields = body['payment']['fields']
        self.assertEqual((fields['total_amount'], fields['product_code']), ('1500', 'EPAYTEST'))
        message = (f"total_amount=1500,transaction_uuid={fields['transaction_uuid']},product_code=EPAYTEST")
        expected = base64.b64encode(hmac.new(TEST_KEY.encode(), message.encode(), hashlib.sha256).digest()).decode()
        self.assertEqual(fields['signature'], expected)
        self.assertTrue(fields['success_url'].startswith(body['payment']['return_url_prefix']))

        # Held: nobody else can take it, and nobody is told it's booked yet.
        self.assertEqual(self.book(profile=self.other).status_code, 409)
        self.assertEqual(Notification.objects.count(), 0)

    def test_verified_payment_confirms_the_booking(self):
        booking_id = self.book().json()['id']
        booking = Booking.objects.get(pk=booking_id)
        status = {'status': 'COMPLETE', 'transaction_uuid': booking.payment_token, 'ref_id': '000ABC'}
        with patch('bookings.payments._call', return_value=status) as call:
            body = self.verify(booking_id).json()
        self.assertIn(f'transaction_uuid={booking.payment_token}', call.call_args.args[0].full_url)
        self.assertIn('total_amount=1500', call.call_args.args[0].full_url)
        self.assertEqual((body['status'], body['payment_status'], body['payment_txn_id']),
                         ('confirmed', 'paid', '000ABC'))
        self.assertEqual(Notification.objects.get(recipient=self.customer).title, 'Booking confirmed')
        self.assertIn('paid with eSewa', Notification.objects.get(recipient=self.owner).body)

    def test_unfinished_payment_is_not_confirmed(self):
        booking_id = self.book().json()['id']
        for answer in ({'status': 'PENDING'}, {'status': 'NOT_FOUND'},
                       {'status': 'COMPLETE', 'transaction_uuid': 'someone-elses'}):
            with patch('bookings.payments._call', return_value=answer):
                self.assertEqual(self.verify(booking_id).status_code, 400, answer)
        self.assertEqual(Booking.objects.get(pk=booking_id).status, 'pending')

    def test_khalti_payment_flow(self):
        initiate = {'pidx': 'PIDX123', 'payment_url': 'https://test-pay.khalti.com/?pidx=PIDX123'}
        with patch('bookings.payments._call', return_value=initiate) as call:
            body = self.book('khalti').json()
        sent = call.call_args.args[0]
        self.assertEqual(sent.get_header('Authorization'), 'Key test-khalti-key')
        self.assertIn(b'"amount": 150000', sent.data)  # paisa
        self.assertEqual(body['payment']['payment_url'], initiate['payment_url'])

        # Paying less than the price doesn't count.
        with patch('bookings.payments._call', return_value={'status': 'Completed', 'total_amount': 1000}):
            self.assertEqual(self.verify(body['id']).status_code, 400)
        with patch('bookings.payments._call',
                   return_value={'status': 'Completed', 'total_amount': 150000, 'transaction_id': 'KT9'}):
            confirmed = self.verify(body['id']).json()
        self.assertEqual((confirmed['status'], confirmed['payment_txn_id']), ('confirmed', 'KT9'))

    def test_gateway_down_frees_the_slot(self):
        with patch('bookings.payments._call', side_effect=payments.PaymentError('Khalti is down')):
            response = self.book('khalti')
        self.assertEqual((response.status_code, response.json()['detail']), (502, 'Khalti is down'))
        self.assertEqual(Booking.objects.count(), 0)

    def test_unpaid_hold_runs_out_after_15_minutes(self):
        booking_id = self.book().json()['id']
        Booking.objects.filter(pk=booking_id).update(created_at=timezone.now() - timedelta(minutes=16))
        self.assertEqual(self.book(profile=self.other, method='cash').status_code, 201)
        held = Booking.objects.get(pk=booking_id)
        self.assertEqual((held.status, held.refund_amount), ('cancelled', 0))
        self.assertEqual(client_for(self.customer).post(f'/api/bookings/{booking_id}/pay/').status_code, 400)

    def test_late_payment_gets_the_slot_back_if_still_free(self):
        booking_id = self.book().json()['id']
        Booking.objects.filter(pk=booking_id).update(created_at=timezone.now() - timedelta(minutes=16))
        client_for(self.customer).get('/api/bookings/')  # the hold runs out
        token = Booking.objects.get(pk=booking_id).payment_token
        with patch('bookings.payments._call',
                   return_value={'status': 'COMPLETE', 'transaction_uuid': token, 'ref_id': 'R1'}):
            body = self.verify(booking_id).json()
        self.assertEqual((body['status'], body['payment_status']), ('confirmed', 'paid'))

    def test_late_payment_for_a_taken_slot_is_refunded_in_full(self):
        booking_id = self.book().json()['id']
        Booking.objects.filter(pk=booking_id).update(created_at=timezone.now() - timedelta(minutes=16))
        self.assertEqual(self.book(profile=self.other, method='cash').status_code, 201)
        token = Booking.objects.get(pk=booking_id).payment_token
        with patch('bookings.payments._call',
                   return_value={'status': 'COMPLETE', 'transaction_uuid': token, 'ref_id': 'R1'}):
            body = self.verify(booking_id).json()
        self.assertEqual((body['status'], body['refund_amount'], body['refund_status']),
                         ('cancelled', '1500.00', 'pending'))

    def test_cancelling_a_paid_booking_queues_a_refund_for_the_admin(self):
        booking_id = self.book().json()['id']
        token = Booking.objects.get(pk=booking_id).payment_token
        with patch('bookings.payments._call',
                   return_value={'status': 'COMPLETE', 'transaction_uuid': token, 'ref_id': 'R1'}):
            self.verify(booking_id)
        Booking.objects.filter(pk=booking_id).update(created_at=timezone.now() - timedelta(hours=3))

        cancelled = client_for(self.customer).post(f'/api/bookings/{booking_id}/cancel/').json()
        self.assertEqual((cancelled['refund_amount'], cancelled['refund_status']), ('750.00', 'pending'))
        self.assertIn('sent back to your eSewa account',
                      Notification.objects.filter(recipient=self.customer).first().body)

        admin = client_for(make_profile(Role.ADMIN))
        self.assertEqual(client_for(self.customer).get('/api/admin/refunds/').status_code, 403)
        waiting = admin.get('/api/admin/refunds/').json()
        self.assertEqual([(r['id'], r['payment_txn_id'], r['customer_name']) for r in waiting],
                         [(booking_id, 'R1', 'Sita')])
        done = admin.post(f'/api/admin/refunds/{booking_id}/done/').json()
        self.assertEqual(done['refund_status'], 'done')
        self.assertEqual(admin.get('/api/admin/refunds/').json(), [])
        self.assertEqual(Notification.objects.filter(recipient=self.customer).first().title, 'Refund sent')
        self.assertEqual(admin.post(f'/api/admin/refunds/{booking_id}/done/').status_code, 404)

    def test_cancelling_before_paying_refunds_nothing(self):
        booking_id = self.book().json()['id']
        cancelled = client_for(self.customer).post(f'/api/bookings/{booking_id}/cancel/').json()
        self.assertEqual((cancelled['refund_amount'], cancelled['refund_status']), ('0.00', ''))
        self.assertEqual(Notification.objects.filter(recipient=self.owner).count(), 0)

    def test_only_offered_methods_can_be_used(self):
        self.assertEqual(client_for(self.customer).get('/api/payments/methods/').json(),
                         {'cash': True, 'esewa': True, 'khalti': True})
        with self.settings(KHALTI_SECRET_KEY=''):
            self.assertFalse(client_for(self.customer).get('/api/payments/methods/').json()['khalti'])
            self.assertEqual(self.book('khalti').status_code, 400)

    def test_someone_else_cannot_verify_or_pay_my_booking(self):
        booking_id = self.book().json()['id']
        self.assertEqual(self.verify(booking_id, self.other).status_code, 404)
        self.assertEqual(client_for(self.other).post(f'/api/bookings/{booking_id}/pay/').status_code, 404)

    def test_paying_after_cancelling_refunds_everything(self):
        booking_id = self.book().json()['id']
        client_for(self.customer).post(f'/api/bookings/{booking_id}/cancel/')
        token = Booking.objects.get(pk=booking_id).payment_token
        with patch('bookings.payments._call',
                   return_value={'status': 'COMPLETE', 'transaction_uuid': token, 'ref_id': 'R2'}):
            body = self.verify(booking_id).json()
        self.assertEqual((body['status'], body['refund_amount'], body['refund_status']),
                         ('cancelled', '1500.00', 'pending'))

    def test_blank_env_values_still_use_the_esewa_test_merchant(self):
        import importlib
        import os

        from futsal_backend import settings as settings_module
        with patch.dict(os.environ, {'ESEWA_SECRET_KEY': '', 'ESEWA_PRODUCT_CODE': ''}):
            reloaded = importlib.reload(settings_module)
            self.assertEqual((reloaded.ESEWA_SECRET_KEY, reloaded.ESEWA_PRODUCT_CODE), (TEST_KEY, 'EPAYTEST'))
        importlib.reload(settings_module)
