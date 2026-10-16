from datetime import time, timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from bookings.models import Booking
from grounds.models import Favourite, Ground

from .models import Notification


def client_for(profile):
    client = APIClient()
    client.force_authenticate(user=profile)
    return client


def make_ground(owner, name):
    return Ground.objects.create(owner=owner, name=name, area='Patan', latitude='27.67', longitude='85.32',
                                 morning_price=1000, day_price=1000, evening_price=1000,
                                 status=Ground.Status.APPROVED)


class AnnouncementTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.other_owner = make_profile(Role.GROUND_OWNER, 'Other Owner')
        self.arena = make_ground(self.owner, 'Arena')
        self.hub = make_ground(self.owner, 'Hub')
        self.elsewhere = make_ground(self.other_owner, 'Elsewhere')
        self.coming = make_profile(Role.CUSTOMER, 'Coming')      # upcoming booking at Arena
        self.played = make_profile(Role.CUSTOMER, 'Played')      # only an old booking at Arena
        self.at_hub = make_profile(Role.CUSTOMER, 'Hub fan')     # upcoming booking at Hub
        self.stranger = make_profile(Role.CUSTOMER, 'Stranger')  # booked at another owner's ground
        today = timezone.localdate()
        for customer, ground, day in ((self.coming, self.arena, today + timedelta(days=2)),
                                      (self.played, self.arena, today - timedelta(days=5)),
                                      (self.at_hub, self.hub, today + timedelta(days=1)),
                                      (self.stranger, self.elsewhere, today + timedelta(days=1))):
            Booking.objects.create(ground=ground, customer=customer, date=day, start_time=time(18), price=1000)

    def send(self, profile=None, url='/api/owner/announcements/', **body):
        return client_for(profile or self.owner).post(url, {'title': 'Free water', 'message': 'This week only',
                                                            **body}, format='json')

    def recipients(self):
        return sorted(n.recipient.full_name for n in Notification.objects.select_related('recipient'))

    def test_owner_messages_customers_with_upcoming_bookings_at_one_ground(self):
        response = self.send(ground=self.arena.id)
        self.assertEqual(response.json(), {'sent': 1})
        notice = Notification.objects.get()
        self.assertEqual((notice.recipient_id, notice.kind, notice.title, notice.body),
                         (self.coming.id, 'announcement', 'Arena: Free water', 'This week only'))

    def test_owner_messages_everyone_who_ever_booked_at_all_their_grounds(self):
        self.assertEqual(self.send(audience='all').json(), {'sent': 3})
        self.assertEqual(self.recipients(), ['Coming', 'Hub fan', 'Played'])  # never the other owner's customer
        self.assertTrue(Notification.objects.first().title.startswith('Owner: '))

    def test_owner_cannot_message_another_owners_customers(self):
        response = self.send(ground=self.elsewhere.id)
        self.assertEqual((response.status_code, set(response.json())), (400, {'ground'}))
        self.assertEqual(Notification.objects.count(), 0)

    def test_message_is_checked_and_only_owners_or_admins_can_send(self):
        self.assertEqual(set(self.send(title=' ', message='').json()), {'title', 'message'})
        self.assertEqual(self.send(profile=self.coming).status_code, 403)
        self.assertEqual(self.send(profile=self.owner, url='/api/admin/announcements/',
                                   audience='everyone').status_code, 403)

    def test_admin_messages_customers_owners_or_everyone(self):
        admin = make_profile(Role.ADMIN, 'Admin')
        self.assertEqual(self.send(admin, '/api/admin/announcements/', audience='owners').json(), {'sent': 2})
        self.assertEqual(Notification.objects.first().title, 'Futsal Finder: Free water')
        Notification.objects.all().delete()
        self.assertEqual(self.send(admin, '/api/admin/announcements/', audience='customers').json(), {'sent': 4})
        self.assertEqual(self.send(admin, '/api/admin/announcements/', audience='everyone').json(), {'sent': 6})
        self.assertEqual(self.send(admin, '/api/admin/announcements/', audience='aliens').status_code, 400)

    def test_customers_see_announcements_under_the_bell(self):
        self.send(ground=self.arena.id)
        body = client_for(self.coming).get('/api/notifications/').json()
        self.assertEqual((body['unread'], body['results'][0]['title']), (1, 'Arena: Free water'))


class MaintenanceNoticeTests(ProfilesTableMixin, TestCase):
    def test_only_people_booked_on_closed_days_hear_about_maintenance(self):
        owner = make_profile(Role.GROUND_OWNER, 'Owner')
        ground = make_ground(owner, 'Arena')
        day = timezone.localdate() + timedelta(days=3)
        paid = make_profile(Role.CUSTOMER, 'Paid online')
        cash = make_profile(Role.CUSTOMER, 'Pays cash')
        other_day = make_profile(Role.CUSTOMER, 'Other day')
        fan = make_profile(Role.CUSTOMER, 'Fan')
        Favourite.objects.create(customer=fan, ground=ground)
        Booking.objects.create(ground=ground, customer=paid, date=day, start_time=time(18), price=1000,
                               payment_method='esewa', payment_status='paid', payment_txn_id='E1')
        Booking.objects.create(ground=ground, customer=cash, date=day, start_time=time(19), price=1000)
        Booking.objects.create(ground=ground, customer=other_day, date=day + timedelta(days=1), start_time=time(18),
                               price=1000)

        client_for(owner).post(f'/api/owner/grounds/{ground.id}/maintenance/', {
            'starts_on': day.isoformat(), 'ends_on': day.isoformat(), 'reason': 'New turf'}, format='json')

        notices = {n.recipient.full_name: n for n in Notification.objects.select_related('recipient')}
        self.assertEqual(sorted(notices), ['Paid online', 'Pays cash'])
        self.assertIn('sent back to your eSewa account', notices['Paid online'].body)
        self.assertEqual(notices['Paid online'].kind, 'maintenance')
        refund = Booking.objects.get(customer=paid)
        self.assertEqual((refund.refund_amount, refund.refund_status), (1000, 'pending'))
