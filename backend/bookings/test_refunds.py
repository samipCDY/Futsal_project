from datetime import time, timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from grounds.models import Ground
from notifications.models import Notification

from .models import Booking


class RefundTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.customer = make_profile(Role.CUSTOMER, 'Sita')
        self.ground = Ground.objects.create(
            owner=self.owner, name='Arena', area='Baneshwor', latitude='27.69', longitude='85.33',
            morning_price=1000, day_price=1000, evening_price=1500, status=Ground.Status.APPROVED,
        )
        self.tomorrow = timezone.localdate() + timedelta(days=1)

    def client_for(self, profile):
        client = APIClient()
        client.force_authenticate(user=profile)
        return client

    def book(self, start='18:00', booked_hours_ago=0, paid=True):
        """A booking made `booked_hours_ago`, paid with eSewa unless `paid` is False (cash)."""
        response = self.client_for(self.customer).post('/api/bookings/', {
            'ground': self.ground.id, 'date': self.tomorrow.isoformat(), 'start_time': start,
        }, format='json')
        self.assertEqual(response.status_code, 201, response.json())
        online = {'payment_method': 'esewa', 'payment_status': 'paid', 'payment_txn_id': 'E1'} if paid else {}
        Booking.objects.filter(pk=response.json()['id']).update(
            created_at=timezone.now() - timedelta(hours=booked_hours_ago), **online)
        return response.json()['id']

    def cancel(self, booking_id, profile=None, **body):
        return self.client_for(profile or self.customer).post(
            f'/api/bookings/{booking_id}/cancel/', body, format='json').json()

    def test_full_refund_within_two_hours_of_booking(self):
        booking_id = self.book(booked_hours_ago=1.5)
        listed = self.client_for(self.customer).get('/api/bookings/').json()[0]
        self.assertEqual(listed['refund_if_cancelled_now'], '1500.00')

        cancelled = self.cancel(booking_id)
        self.assertEqual((cancelled['refund_amount'], cancelled['cancelled_by']), ('1500.00', 'customer'))

    def test_half_refund_after_two_hours_and_owner_keeps_half(self):
        booking_id = self.book(booked_hours_ago=3)
        listed = self.client_for(self.customer).get('/api/bookings/').json()[0]
        self.assertEqual(listed['refund_if_cancelled_now'], '750.00')

        self.assertEqual(self.cancel(booking_id)['refund_amount'], '750.00')
        owner_notice = Notification.objects.get(recipient=self.owner, kind='cancellation')
        self.assertIn('You keep Rs 750', owner_notice.body)

        summary = self.client_for(self.owner).get('/api/owner/summary/').json()
        # Tomorrow may fall in next week (when today is Saturday).
        self.assertIn(summary['week_earnings'], ('750.00', '0.00'))

    def test_owner_cancelling_always_refunds_in_full(self):
        booking_id = self.book(booked_hours_ago=10)
        listed = self.client_for(self.owner).get('/api/bookings/').json()[0]
        self.assertEqual(listed['refund_if_cancelled_now'], '1500.00')

        cancelled = self.cancel(booking_id, self.owner, reason='Water leak on the turf')
        self.assertEqual((cancelled['refund_amount'], cancelled['cancelled_by'], cancelled['cancel_reason']),
                         ('1500.00', 'owner', 'Water leak on the turf'))
        notice = Notification.objects.get(recipient=self.customer, kind='cancellation')
        self.assertIn('Water leak', notice.body)
        self.assertIn('full amount', notice.body)

    def test_customer_cannot_choose_a_reason_or_a_bigger_refund(self):
        booking_id = self.book(booked_hours_ago=5)
        cancelled = self.cancel(booking_id, reason='hack', refund_amount='1500')
        self.assertEqual((cancelled['refund_amount'], cancelled['cancel_reason']), ('750.00', ''))

    def test_booking_tells_customer_and_owner(self):
        self.book(start='09:00')
        customer_notice = Notification.objects.get(recipient=self.customer)
        self.assertEqual(customer_notice.title, 'Booking confirmed')
        self.assertIn('9:00 AM', customer_notice.body)
        self.assertEqual(Notification.objects.get(recipient=self.owner).title, 'New booking')

    def test_paid_booking_notice_explains_the_refund_rules(self):
        booking = Booking.objects.create(ground=self.ground, customer=self.customer, date=self.tomorrow,
                                         start_time=time(9), price=1500, payment_method='esewa',
                                         status=Booking.Status.PENDING)
        booking.mark_paid('E1')
        body = Notification.objects.get(recipient=self.customer).body
        self.assertIn('paid with eSewa. Free cancellation until', body)
        self.assertIn('50% refund', body)

    def test_owner_reason_without_full_stop_reads_as_a_sentence(self):
        booking_id = self.book()
        self.cancel(booking_id, self.owner, reason='Sorry, turf repair')
        body = Notification.objects.get(recipient=self.customer, kind='cancellation').body
        self.assertIn('Sorry, turf repair. Your booking is cancelled.', body)

    def test_cash_booking_notice_promises_no_refund(self):
        self.book(start='09:00', paid=False)
        body = Notification.objects.get(recipient=self.customer).body
        self.assertIn('pay at the ground. You can cancel any time before the game.', body)
        self.assertNotIn('refund', body)

    def test_cash_bookings_have_nothing_to_refund(self):
        booking_id = self.book(booked_hours_ago=5, paid=False)
        listed = self.client_for(self.customer).get('/api/bookings/').json()[0]
        self.assertEqual(listed['refund_if_cancelled_now'], '0.00')

        cancelled = self.cancel(booking_id, self.owner, reason='Rain')
        self.assertEqual((cancelled['refund_amount'], cancelled['refund_status']), ('0.00', ''))
        notice = Notification.objects.get(recipient=self.customer, kind='cancellation')
        self.assertIn('Nothing was paid', notice.body)
        self.assertNotIn('Refund:', notice.body)
        self.assertEqual(Booking.objects.get(pk=booking_id).owner_keeps, 0)

    def test_refund_rule_boundaries(self):
        booking = Booking(ground=self.ground, customer=self.customer, date=self.tomorrow, start_time=time(18),
                          price=1500, created_at=timezone.now())
        self.assertEqual(booking.customer_refund(at=booking.created_at + timedelta(hours=2)), 1500)
        self.assertEqual(booking.customer_refund(at=booking.created_at + timedelta(hours=2, seconds=1)), 750)

    def test_old_cancellations_without_a_recorded_refund_earn_nothing(self):
        booking = Booking.objects.create(ground=self.ground, customer=self.customer, date=self.tomorrow,
                                         start_time=time(18), price=1500, status=Booking.Status.CANCELLED)
        self.assertEqual(booking.owner_keeps, 0)
