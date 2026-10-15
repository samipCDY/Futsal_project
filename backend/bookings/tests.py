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
            latitude=27.69, longitude=85.33, price_per_hour=1400,
            opens_at=time(6), closes_at=time(22),
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
            latitude=27.67, longitude=85.32, price_per_hour=1000)
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
