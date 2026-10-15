from datetime import date, time, timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from grounds.models import Ground

from .models import Booking


class BookingApiTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.customer = make_profile(Role.CUSTOMER, 'Customer')
        self.other_customer = make_profile(Role.CUSTOMER, 'Other')
        self.ground = Ground.objects.create(
            owner=self.owner, name='Arena', area='Baneshwor',
            latitude=27.69, longitude=85.33, morning_price=1000, day_price=1200, evening_price=1400,
            opens_at=time(6), closes_at=time(22), status=Ground.Status.APPROVED,
        )
        self.tomorrow = timezone.localdate() + timedelta(days=1)

    def client_for(self, profile):
        client = APIClient()
        client.force_authenticate(user=profile)
        return client

    def book(self, profile, start='18:00', day=None, **extra):
        return self.client_for(profile).post('/api/bookings/', {
            'ground': self.ground.id,
            'date': (day or self.tomorrow).isoformat(),
            'start_time': start,
            **extra,
        }, format='json')

    def test_customer_books_slot_at_current_price(self):
        response = self.book(self.customer)
        self.assertEqual(response.status_code, 201, response.json())
        body = response.json()
        self.assertEqual(body['ground_name'], 'Arena')
        self.assertEqual(body['end_time'], '19:00:00')
        self.assertEqual(body['status'], 'confirmed')
        self.assertEqual(body['price'], '1400.00')
        self.assertTrue(body['booking_ref'].startswith('FF-'))

    def test_same_slot_cannot_be_booked_twice(self):
        self.book(self.customer)
        response = self.book(self.other_customer)
        self.assertEqual(response.status_code, 409)

    def test_cancelled_slot_can_be_booked_again(self):
        booking_id = self.book(self.customer).json()['id']
        cancel = self.client_for(self.customer).post(f'/api/bookings/{booking_id}/cancel/')
        self.assertEqual(cancel.json()['status'], 'cancelled')
        self.assertEqual(self.book(self.other_customer).status_code, 201)

    def test_rejects_slot_outside_opening_hours_or_off_the_hour(self):
        self.assertEqual(self.book(self.customer, start='22:00').status_code, 400)
        self.assertEqual(self.book(self.customer, start='05:00').status_code, 400)
        self.assertEqual(self.book(self.customer, start='18:30').status_code, 400)

    def test_rejects_past_and_far_future_dates(self):
        yesterday = timezone.localdate() - timedelta(days=1)
        self.assertEqual(self.book(self.customer, day=yesterday).status_code, 400)
        far = timezone.localdate() + timedelta(days=31)
        self.assertEqual(self.book(self.customer, day=far).status_code, 400)

    def test_only_customers_can_book(self):
        self.assertEqual(self.book(self.owner).status_code, 403)

    def test_each_role_sees_the_right_bookings(self):
        self.book(self.customer, start='18:00')
        self.book(self.other_customer, start='19:00')
        other_ground = Ground.objects.create(
            owner=make_profile(Role.GROUND_OWNER), name='Elsewhere', area='Patan',
            latitude=27.67, longitude=85.32, morning_price=1000, day_price=1000, evening_price=1000)
        Booking.objects.create(ground=other_ground, customer=self.customer,
                               date=self.tomorrow, start_time=time(18), price=1000)

        def count(profile):
            return len(self.client_for(profile).get('/api/bookings/').json())

        self.assertEqual(count(self.customer), 2)        # own bookings at both grounds
        self.assertEqual(count(self.other_customer), 1)
        self.assertEqual(count(self.owner), 2)           # only bookings at their ground

    def test_customer_cannot_cancel_someone_elses_booking(self):
        booking_id = self.book(self.customer).json()['id']
        response = self.client_for(self.other_customer).post(f'/api/bookings/{booking_id}/cancel/')
        self.assertEqual(response.status_code, 404)

    def test_slots_show_booked_times_as_unavailable(self):
        self.book(self.customer, start='18:00')
        response = self.client_for(self.other_customer).get(
            f'/api/grounds/{self.ground.id}/slots/', {'date': self.tomorrow.isoformat()})
        slots = {s['start_time']: s['available'] for s in response.json()['slots']}
        self.assertEqual(len(slots), 16)  # 06:00 .. 21:00
        self.assertFalse(slots['18:00'])
        self.assertTrue(slots['19:00'])

    def test_played_bookings_show_as_completed(self):
        Booking.objects.create(ground=self.ground, customer=self.customer,
                               date=timezone.localdate() - timedelta(days=1),
                               start_time=time(18), price=1400)
        statuses = [b['status'] for b in self.client_for(self.customer).get('/api/bookings/').json()]
        self.assertEqual(statuses, ['completed'])

    def test_slots_require_a_date(self):
        response = self.client_for(self.customer).get(f'/api/grounds/{self.ground.id}/slots/')
        self.assertEqual(response.status_code, 400)

    def test_inactive_grounds_are_hidden(self):
        self.ground.is_active = False
        self.ground.save()
        self.assertEqual(self.client_for(self.customer).get('/api/grounds/').json(), [])
        self.assertEqual(self.book(self.customer).status_code, 400)

    def test_grounds_waiting_for_approval_are_hidden(self):
        for status in (Ground.Status.PENDING, Ground.Status.REJECTED):
            self.ground.status = status
            self.ground.save()
            self.assertEqual(self.client_for(self.customer).get('/api/grounds/').json(), [])
            self.assertEqual(self.book(self.customer).status_code, 400)

    def test_price_depends_on_time_of_day(self):
        prices = {start: self.book(self.customer, start=start).json()['price']
                  for start in ('09:00', '10:00', '15:00', '16:00')}
        self.assertEqual(prices, {'09:00': '1000.00', '10:00': '1200.00', '15:00': '1200.00', '16:00': '1400.00'})
        response = self.client_for(self.other_customer).get(
            f'/api/grounds/{self.ground.id}/slots/', {'date': self.tomorrow.isoformat()})
        slot_prices = {s['start_time']: s['price'] for s in response.json()['slots']}
        self.assertEqual((slot_prices['06:00'], slot_prices['12:00'], slot_prices['21:00']),
                         ('1000.00', '1200.00', '1400.00'))

    def test_owner_sees_who_booked_but_customers_do_not(self):
        self.customer.mobile_number = '9800000001'
        self.customer.save()
        self.book(self.customer)
        owner_view = self.client_for(self.owner).get('/api/bookings/').json()[0]
        self.assertEqual((owner_view['customer_name'], owner_view['customer_phone']), ('Customer', '9800000001'))
        customer_view = self.client_for(self.customer).get('/api/bookings/').json()[0]
        self.assertIsNone(customer_view['customer_phone'])

    def test_filter_bookings_by_date(self):
        self.book(self.customer, start='18:00')
        self.book(self.customer, start='18:00', day=self.tomorrow + timedelta(days=1))
        response = self.client_for(self.owner).get('/api/bookings/', {'date': self.tomorrow.isoformat()})
        self.assertEqual(len(response.json()), 1)

    def test_owner_summary(self):
        self.book(self.customer, start='18:00')
        self.book(self.other_customer, start='19:00')
        cancelled = self.book(self.other_customer, start='20:00').json()['id']
        self.client_for(self.other_customer).post(f'/api/bookings/{cancelled}/cancel/')

        summary = self.client_for(self.owner).get('/api/owner/summary/').json()
        self.assertEqual([b['start_time'] for b in summary['upcoming']], ['18:00:00', '19:00:00'])
        self.assertEqual(summary['upcoming'][0]['customer_name'], 'Customer')
        self.assertEqual((summary['active_grounds'], summary['total_grounds']), (1, 1))
        self.assertEqual((summary['pending_grounds'], summary['rejected_grounds']), (0, 0))
        # Tomorrow may fall in next week (when today is Saturday), so only check what's certain.
        self.assertIn(summary['week_earnings'], ('2800.00', '0.00'))

    def test_customers_cannot_see_owner_summary(self):
        self.assertEqual(self.client_for(self.customer).get('/api/owner/summary/').status_code, 403)
