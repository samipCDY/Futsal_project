from datetime import time, timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from bookings.models import Booking
from notifications.models import Notification

from .models import Event, Favourite, Ground


def client_for(profile):
    client = APIClient()
    client.force_authenticate(user=profile)
    return client


def make_ground(owner, name='Arena'):
    return Ground.objects.create(owner=owner, name=name, area='Patan', latitude='27.67', longitude='85.32',
                                 morning_price=1000, day_price=1000, evening_price=1000,
                                 opens_at=time(6), closes_at=time(22), status=Ground.Status.APPROVED)


class MaintenanceTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.other_owner = make_profile(Role.GROUND_OWNER)
        self.customer = make_profile(Role.CUSTOMER, 'Hari')
        self.ground = make_ground(self.owner)
        self.today = timezone.localdate()
        self.day = self.today + timedelta(days=3)

    def close(self, starts=None, ends=None, reason='Replacing the turf', owner=None):
        starts = starts or self.day
        return client_for(owner or self.owner).post(f'/api/owner/grounds/{self.ground.id}/maintenance/', {
            'starts_on': starts.isoformat(), 'ends_on': (ends or starts).isoformat(), 'reason': reason,
        }, format='json')

    def test_closing_cancels_bookings_with_full_refund_and_tells_customers(self):
        inside = Booking.objects.create(ground=self.ground, customer=self.customer, date=self.day,
                                        start_time=time(18), price=1000, payment_method='khalti',
                                        payment_status='paid', payment_txn_id='K1')
        Booking.objects.filter(pk=inside.pk).update(created_at=timezone.now() - timedelta(days=2))
        outside = Booking.objects.create(ground=self.ground, customer=self.customer,
                                         date=self.day + timedelta(days=1), start_time=time(18), price=1000)

        response = self.close()
        self.assertEqual(response.status_code, 201, response.json())
        self.assertEqual(response.json()['cancelled_bookings'], 1)

        inside.refresh_from_db()
        outside.refresh_from_db()
        self.assertEqual((inside.status, inside.refund_amount, inside.cancelled_by), ('cancelled', 1000, 'owner'))
        self.assertEqual(outside.status, 'confirmed')
        notice = Notification.objects.get(recipient=self.customer, kind='maintenance')
        self.assertEqual(notice.title, 'Arena is under maintenance')
        self.assertIn('Replacing the turf', notice.body)
        self.assertIn('Refund: Rs 1,000 (full amount), sent back to your Khalti account.', notice.body)

    def test_customers_see_the_closure_and_cannot_book_those_days(self):
        self.close()
        customer = client_for(self.customer)
        ground = customer.get('/api/grounds/').json()[0]
        self.assertEqual(ground['maintenance'][0]['reason'], 'Replacing the turf')

        slots = customer.get(f'/api/grounds/{self.ground.id}/slots/', {'date': self.day.isoformat()}).json()
        self.assertEqual(slots['closed_reason'], 'Replacing the turf')
        self.assertFalse(any(slot['available'] for slot in slots['slots']))

        response = customer.post('/api/bookings/', {'ground': self.ground.id, 'date': self.day.isoformat(),
                                                    'start_time': '18:00'}, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertIn('maintenance', str(response.json()))

    def test_bad_dates_and_reason_are_refused(self):
        self.assertEqual(self.close(starts=self.today - timedelta(days=1)).status_code, 400)
        self.assertEqual(self.close(starts=self.day, ends=self.day - timedelta(days=1)).status_code, 400)
        self.assertEqual(self.close(reason='  ').status_code, 400)

    def test_only_the_owner_can_close_or_reopen(self):
        self.assertEqual(self.close(owner=self.other_owner).status_code, 404)
        period_id = self.close().json()['id']
        self.assertEqual(client_for(self.other_owner).delete(f'/api/owner/maintenance/{period_id}/').status_code,
                         404)
        self.assertEqual(client_for(self.owner).delete(f'/api/owner/maintenance/{period_id}/').status_code, 204)
        self.assertEqual(client_for(self.customer).get('/api/grounds/').json()[0]['maintenance'], [])


class EventTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.other_owner = make_profile(Role.GROUND_OWNER)
        self.customer = make_profile(Role.CUSTOMER)
        self.fan = make_profile(Role.CUSTOMER)
        self.ground = make_ground(self.owner)
        self.other_ground = make_ground(self.other_owner, 'Other Arena')
        Favourite.objects.create(customer=self.fan, ground=self.ground)
        self.when = timezone.now() + timedelta(days=5)

    def create(self, owner=None, **details):
        body = {'ground': self.ground.id, 'title': ' Weekend Cup ', 'description': '8 teams, Rs 5000 prize',
                'starts_at': self.when.isoformat(), **details}
        return client_for(owner or self.owner).post('/api/owner/events/', body, format='json')

    def titles(self, profile, **query):
        return [e['title'] for e in client_for(profile).get('/api/events/', query).json()]

    def test_draft_is_private_until_published(self):
        event = self.create().json()
        self.assertEqual((event['title'], event['is_published']), ('Weekend Cup', False))
        self.assertEqual(self.titles(self.customer), [])
        self.assertEqual(Notification.objects.count(), 0)

        published = client_for(self.owner).patch(f"/api/owner/events/{event['id']}/", {'is_published': True},
                                                 format='json').json()
        self.assertTrue(published['is_published'])
        self.assertEqual(self.titles(self.customer), ['Weekend Cup'])
        self.assertEqual(self.titles(self.other_owner), ['Weekend Cup'])  # other owners see it too
        self.assertEqual(self.titles(self.customer, ground=self.other_ground.id), [])
        # Every customer hears about it (not owners), whether or not they saved the ground.
        self.assertEqual(set(Notification.objects.values_list('recipient_id', flat=True)),
                         {self.customer.id, self.fan.id})
        notice = Notification.objects.get(recipient=self.customer)
        self.assertEqual((notice.kind, notice.title), ('event', 'New event at Arena'))

        # Unpublishing and publishing again doesn't notify twice.
        client_for(self.owner).patch(f"/api/owner/events/{event['id']}/", {'is_published': False}, format='json')
        client_for(self.owner).patch(f"/api/owner/events/{event['id']}/", {'is_published': True}, format='json')
        self.assertEqual(Notification.objects.filter(recipient=self.fan).count(), 1)

    def test_owner_edits_and_deletes_only_their_own_events(self):
        event_id = self.create(is_published=True).json()['id']
        other = client_for(self.other_owner)
        self.assertEqual(other.patch(f'/api/owner/events/{event_id}/', {'title': 'Mine'}, format='json').status_code,
                         404)
        self.assertEqual(other.delete(f'/api/owner/events/{event_id}/').status_code, 404)
        self.assertEqual(self.titles(self.other_owner), ['Weekend Cup'])
        self.assertFalse(other.get('/api/events/').json()[0]['is_mine'])

        mine = client_for(self.owner)
        self.assertTrue(mine.get('/api/events/').json()[0]['is_mine'])
        mine.patch(f'/api/owner/events/{event_id}/', {'title': 'Monsoon Cup'}, format='json')
        self.assertEqual(self.titles(self.customer), ['Monsoon Cup'])
        self.assertEqual(mine.delete(f'/api/owner/events/{event_id}/').status_code, 204)
        self.assertEqual(self.titles(self.customer), [])

    def test_event_details_are_checked(self):
        self.assertEqual(set(self.create(title='  ').json()), {'title'})
        self.assertEqual(set(self.create(starts_at=(timezone.now() - timedelta(hours=1)).isoformat()).json()),
                         {'starts_at'})
        self.assertEqual(set(self.create(ends_at=(self.when - timedelta(hours=1)).isoformat()).json()), {'ends_at'})
        self.assertEqual(set(self.create(ground=self.other_ground.id).json()), {'ground'})
        self.assertEqual(client_for(self.customer).post('/api/owner/events/', {}, format='json').status_code, 403)

    def test_customers_get_a_number_to_call_to_register(self):
        Profile = type(self.owner)
        Profile.objects.filter(pk=self.owner.pk).update(mobile_number='9800000001')
        self.create(is_published=True, title='Owner number')
        self.create(is_published=True, title='Own number', contact_phone=' 981-234 5678 ',
                    starts_at=(self.when + timedelta(hours=1)).isoformat())
        phones = {e['title']: e['contact_phone'] for e in client_for(self.customer).get('/api/events/').json()}
        self.assertEqual(phones, {'Owner number': '9800000001', 'Own number': '981-234 5678'})
        self.assertEqual(set(self.create(contact_phone='call me').json()), {'contact_phone'})

    def test_past_events_show_as_expired_after_coming_ones(self):
        self.create(is_published=True, title='Coming')
        Event.objects.create(owner=self.owner, ground=self.ground, title='Finished', is_published=True,
                             starts_at=timezone.now() - timedelta(days=2))
        Event.objects.create(owner=self.owner, ground=self.ground, title='Long ago', is_published=True,
                             starts_at=timezone.now() - timedelta(days=90))
        events = client_for(self.customer).get('/api/events/').json()
        self.assertEqual([(e['title'], e['is_expired']) for e in events], [('Coming', False), ('Finished', True)])


class NotificationApiTests(ProfilesTableMixin, TestCase):
    def test_list_and_mark_read(self):
        customer, other = make_profile(), make_profile()
        for title in ('First', 'Second'):
            Notification.objects.create(recipient=customer, kind='booking', title=title)
        Notification.objects.create(recipient=other, kind='booking', title='Not yours')

        body = client_for(customer).get('/api/notifications/').json()
        self.assertEqual((body['unread'], [n['title'] for n in body['results']]), (2, ['Second', 'First']))
        client_for(customer).post('/api/notifications/read/')
        self.assertEqual(client_for(customer).get('/api/notifications/').json()['unread'], 0)
        self.assertEqual(client_for(other).get('/api/notifications/').json()['unread'], 1)


class LongEventTests(ProfilesTableMixin, TestCase):
    def test_a_long_running_event_stays_listed_until_it_ends(self):
        owner = make_profile(Role.GROUND_OWNER)
        ground = make_ground(owner)
        Event.objects.create(owner=owner, ground=ground, title='League season', is_published=True,
                             starts_at=timezone.now() - timedelta(days=90),
                             ends_at=timezone.now() + timedelta(days=10))
        events = client_for(make_profile()).get('/api/events/').json()
        self.assertEqual([(e['title'], e['is_expired']) for e in events], [('League season', False)])
