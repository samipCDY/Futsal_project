from datetime import time, timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from grounds.models import Ground, Maintenance
from notifications.models import Notification

from .models import Booking


def client_for(profile):
    client = APIClient()
    client.force_authenticate(user=profile)
    return client


class RescheduleTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.customer = make_profile(Role.CUSTOMER, 'Sita')
        self.ground = Ground.objects.create(
            owner=self.owner, name='Arena', area='Patan', latitude='27.67', longitude='85.32',
            morning_price=1000, day_price=1000, evening_price=1500, status=Ground.Status.APPROVED,
        )
        self.tomorrow = timezone.localdate() + timedelta(days=1)

    def booking(self, start=time(8), paid=False, **fields):
        online = {'payment_method': 'esewa', 'payment_status': 'paid'} if paid else {}
        return Booking.objects.create(ground=self.ground, customer=self.customer, date=self.tomorrow,
                                      start_time=start, price=self.ground.price_at(start), **online, **fields)

    def move(self, booking, start='09:00', day=None, profile=None):
        return client_for(profile or self.customer).post(
            f'/api/bookings/{booking.id}/reschedule/',
            {'date': (day or self.tomorrow).isoformat(), 'start_time': start}, format='json')

    def test_cash_booking_moves_and_takes_the_new_price(self):
        booking = self.booking()
        response = self.move(booking, '18:00', day=self.tomorrow + timedelta(days=1))
        self.assertEqual(response.status_code, 200, response.json())
        booking.refresh_from_db()
        self.assertEqual((booking.date, booking.start_time, booking.price),
                         (self.tomorrow + timedelta(days=1), time(18), 1500))
        notice = Notification.objects.get(recipient=self.customer)
        self.assertEqual(notice.title, 'Booking moved')
        self.assertIn('New price: Rs 1,500, pay at the ground.', notice.body)
        self.assertEqual(Notification.objects.get(recipient=self.owner).title, 'A customer moved their booking')

    def test_paid_booking_moves_only_to_the_same_price(self):
        booking = self.booking(paid=True)
        self.assertEqual(self.move(booking, '18:00').status_code, 400)  # Rs 1,500 vs Rs 1,000 paid
        self.assertEqual(self.move(booking, '09:00').status_code, 200)
        booking.refresh_from_db()
        self.assertEqual((booking.start_time, booking.price), (time(9), 1000))
        self.assertNotIn('New price', Notification.objects.get(recipient=self.customer).body)

    def test_taken_closed_or_bad_slots_are_refused(self):
        booking = self.booking()
        Booking.objects.create(ground=self.ground, customer=make_profile(), date=self.tomorrow,
                               start_time=time(9), price=1000)
        self.assertEqual(self.move(booking, '09:00').status_code, 409)
        self.assertEqual(self.move(booking, '08:00').status_code, 400)  # same time
        self.assertEqual(self.move(booking, '03:00').status_code, 400)  # before opening
        Maintenance.objects.create(ground=self.ground, starts_on=self.tomorrow + timedelta(days=2),
                                   ends_on=self.tomorrow + timedelta(days=2), reason='Turf')
        self.assertEqual(self.move(booking, '10:00', day=self.tomorrow + timedelta(days=2)).status_code, 400)
        booking.refresh_from_db()
        self.assertEqual(booking.start_time, time(8))

    def test_only_the_customer_and_only_upcoming_confirmed_bookings(self):
        booking = self.booking()
        self.assertEqual(self.move(booking, profile=make_profile()).status_code, 404)
        self.assertEqual(self.move(booking, profile=self.owner).status_code, 403)

        cancelled = self.booking(start=time(11), status=Booking.Status.CANCELLED)
        self.assertEqual(self.move(cancelled).status_code, 400)
        played = Booking.objects.create(ground=self.ground, customer=self.customer,
                                        date=timezone.localdate() - timedelta(days=1), start_time=time(8), price=1000)
        self.assertEqual(self.move(played).status_code, 400)
