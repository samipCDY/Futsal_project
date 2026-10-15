from datetime import time

from django.conf import settings
from django.core import mail
from django.core.exceptions import ValidationError
from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Role, User
from accounts.tests import ProfilesTableMixin, make_profile

from .models import Ground


class FavouriteApiTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        owner = make_profile(Role.GROUND_OWNER)
        self.arena = Ground.objects.create(owner=owner, name='Arena', area='Baneshwor', latitude=27.69,
                                           longitude=85.33, morning_price=1400, day_price=1400, evening_price=1400,
                                           opens_at=time(6), closes_at=time(22), status=Ground.Status.APPROVED)
        self.hub = Ground.objects.create(owner=owner, name='Hub', area='Patan', latitude=27.67,
                                         longitude=85.32, morning_price=1200, day_price=1200, evening_price=1200,
                                         status=Ground.Status.APPROVED)
        self.customer = make_profile()
        self.other = make_profile()

    def client_for(self, profile):
        client = APIClient()
        client.force_authenticate(user=profile)
        return client

    def favourites_of(self, profile):
        return [g['name'] for g in self.client_for(profile).get('/api/grounds/favourites/').json()]

    def test_save_and_unsave_a_ground(self):
        client = self.client_for(self.customer)
        self.assertEqual(client.post(f'/api/grounds/{self.arena.id}/favourite/').json(), {'is_favourite': True})
        client.post(f'/api/grounds/{self.arena.id}/favourite/')  # saving twice is harmless
        self.assertEqual(self.favourites_of(self.customer), ['Arena'])

        client.delete(f'/api/grounds/{self.arena.id}/favourite/')
        self.assertEqual(self.favourites_of(self.customer), [])

    def test_favourites_are_per_user_and_shown_on_ground_list(self):
        self.client_for(self.customer).post(f'/api/grounds/{self.hub.id}/favourite/')
        self.assertEqual(self.favourites_of(self.other), [])

        grounds = {g['name']: g['is_favourite'] for g in self.client_for(self.customer).get('/api/grounds/').json()}
        self.assertEqual(grounds, {'Arena': False, 'Hub': True})
        others = {g['name']: g['is_favourite'] for g in self.client_for(self.other).get('/api/grounds/').json()}
        self.assertEqual(others, {'Arena': False, 'Hub': False})


class OwnerGroundApiTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER)
        self.other_owner = make_profile(Role.GROUND_OWNER)
        self.customer = make_profile()
        self.valid = {
            'name': ' Thunder Arena ', 'area': 'Koteshwor', 'latitude': '27.678900', 'longitude': '85.349100',
            'morning_price': '1200.00', 'day_price': '1500.00', 'evening_price': '1800.00',
            'opens_at': '07:00', 'closes_at': '21:00', 'ownership_document': f'{self.owner.id}/photo-1.jpg',
        }
        self.admin = User.objects.create_user('admin@example.com', 'pw', is_staff=True)

    def client_for(self, profile):
        client = APIClient()
        client.force_authenticate(user=profile)
        return client

    def add_ground(self, owner=None, **details):
        owner = owner or self.owner
        body = {**self.valid, 'ownership_document': f'{owner.id}/photo-1.jpg', **details}
        response = self.client_for(owner).post('/api/owner/grounds/', body, format='json')
        self.assertEqual(response.status_code, 201, response.json())
        return response.json()

    def approve(self, ground_id):
        Ground.objects.filter(pk=ground_id).update(status=Ground.Status.APPROVED)

    def customer_sees(self):
        return [g['name'] for g in self.client_for(self.customer).get('/api/grounds/').json()]

    def test_new_ground_waits_for_admin_approval(self):
        with self.captureOnCommitCallbacks(execute=True):
            ground = self.add_ground()
        self.assertEqual((ground['status'], ground['name']), ('pending', 'Thunder Arena'))
        self.assertEqual(Ground.objects.get().owner_id, self.owner.id)
        self.assertEqual(self.customer_sees(), [])
        self.assertEqual(mail.outbox[0].to, ['admin@example.com'])
        self.assertIn('Thunder Arena', mail.outbox[0].subject)

        self.approve(ground['id'])
        self.assertEqual(self.customer_sees(), ['Thunder Arena'])

    def test_lalpurja_photo_is_required_and_must_be_the_owners(self):
        body = {k: v for k, v in self.valid.items() if k != 'ownership_document'}
        response = self.client_for(self.owner).post('/api/owner/grounds/', body, format='json')
        self.assertEqual(set(response.json()), {'ownership_document'})
        for path in (f'{self.other_owner.id}/photo-1.jpg', f'{self.owner.id}/../x.jpg', f'{self.owner.id}/a.pdf'):
            response = self.client_for(self.owner).post(
                '/api/owner/grounds/', {**self.valid, 'ownership_document': path}, format='json')
            self.assertEqual(set(response.json()), {'ownership_document'}, path)

    def test_owner_cannot_approve_their_own_ground(self):
        ground = self.add_ground()
        response = self.client_for(self.owner).patch(f"/api/owner/grounds/{ground['id']}/",
                                                     {'status': 'approved'}, format='json')
        self.assertEqual(response.json()['status'], 'pending')

    def test_changing_checked_details_needs_approval_again(self):
        ground = self.add_ground()
        self.approve(ground['id'])
        url = f"/api/owner/grounds/{ground['id']}/"
        owner = self.client_for(self.owner)

        # Prices, hours and hiding/showing don't need checking.
        response = owner.patch(url, {'evening_price': '2000', 'closes_at': '22:00', 'is_active': True,
                                     'latitude': '27.678900'}, format='json')
        self.assertEqual(response.json()['status'], 'approved')

        with self.captureOnCommitCallbacks(execute=True):
            response = owner.patch(url, {'name': 'New Name'}, format='json')
        self.assertEqual(response.json()['status'], 'pending')
        self.assertEqual(self.customer_sees(), [])
        self.assertIn('changed', mail.outbox[0].body)

    def test_saving_a_rejected_ground_sends_it_back_for_approval(self):
        ground = self.add_ground()
        Ground.objects.filter(pk=ground['id']).update(status=Ground.Status.REJECTED, review_note='Blurry photo')
        url = f"/api/owner/grounds/{ground['id']}/"
        listed = self.client_for(self.owner).get('/api/owner/grounds/').json()[0]
        self.assertEqual((listed['status'], listed['review_note']), ('rejected', 'Blurry photo'))

        response = self.client_for(self.owner).patch(url, {'is_active': False}, format='json')
        self.assertEqual(response.json()['status'], 'rejected')
        response = self.client_for(self.owner).patch(
            url, {'ownership_document': f'{self.owner.id}/photo-2.jpg'}, format='json')
        self.assertEqual((response.json()['status'], response.json()['review_note']), ('pending', ''))

    def test_owner_cannot_set_someone_else_as_owner(self):
        self.client_for(self.owner).post('/api/owner/grounds/', {**self.valid, 'owner': str(self.other_owner.id)},
                                         format='json')
        self.assertEqual(Ground.objects.get().owner_id, self.owner.id)

    def test_owner_sees_and_edits_only_their_own_grounds(self):
        mine = self.add_ground()
        theirs = self.add_ground(owner=self.other_owner, name='Other')
        self.approve(mine['id'])
        self.approve(theirs['id'])

        self.assertEqual([g['name'] for g in self.client_for(self.owner).get('/api/owner/grounds/').json()],
                         ['Thunder Arena'])
        response = self.client_for(self.owner).patch(f"/api/owner/grounds/{theirs['id']}/", {'name': 'Mine now'},
                                                     format='json')
        self.assertEqual(response.status_code, 404)

        response = self.client_for(self.owner).patch(f"/api/owner/grounds/{mine['id']}/", {'is_active': False},
                                                     format='json')
        self.assertEqual(response.json()['is_active'], False)
        self.assertEqual(self.customer_sees(), ['Other'])

    def test_rejects_bad_ground_details(self):
        response = self.client_for(self.owner).post('/api/owner/grounds/', {
            **self.valid, 'name': ' ', 'morning_price': '0', 'evening_price': '-5', 'latitude': '120',
        }, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertEqual(set(response.json()), {'name', 'morning_price', 'evening_price', 'latitude'})

        response = self.client_for(self.owner).post('/api/owner/grounds/', {**self.valid, 'closes_at': '06:00'},
                                                    format='json')
        self.assertEqual(set(response.json()), {'closes_at'})

    def test_photo_must_be_in_owners_folder(self):
        own = f'{settings.SUPABASE_URL}/storage/v1/object/public/ground-photos/{self.owner.id}/g.jpg'
        response = self.client_for(self.owner).post('/api/owner/grounds/', {**self.valid, 'image_url': own},
                                                    format='json')
        self.assertEqual(response.status_code, 201)
        other = own.replace(str(self.owner.id), str(self.other_owner.id))
        response = self.client_for(self.owner).post('/api/owner/grounds/', {**self.valid, 'image_url': other},
                                                    format='json')
        self.assertEqual(response.status_code, 400)

    def test_customers_cannot_manage_grounds(self):
        self.assertEqual(self.client_for(self.customer).get('/api/owner/grounds/').status_code, 403)
        self.assertEqual(self.client_for(self.customer).post('/api/owner/grounds/', self.valid,
                                                             format='json').status_code, 403)


class GroundAdminTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER)
        self.owner.email = 'owner@example.com'
        self.owner.save()
        self.ground = Ground.objects.create(owner=self.owner, name='Arena', area='Baneshwor', latitude='27.69',
                                            longitude='85.33', morning_price=1, day_price=1, evening_price=1)
        admin_user = User.objects.create_superuser('admin@example.com', 'pw')
        self.client.force_login(admin_user)

    def test_approve_action_emails_the_owner(self):
        with self.captureOnCommitCallbacks(execute=True):
            self.client.post('/admin/grounds/ground/', {
                'action': 'approve', '_selected_action': [self.ground.pk]})
        self.ground.refresh_from_db()
        self.assertEqual(self.ground.status, Ground.Status.APPROVED)
        self.assertIsNotNone(self.ground.reviewed_at)
        self.assertEqual((mail.outbox[0].to, mail.outbox[0].subject), (['owner@example.com'], 'Arena is approved'))

    def test_rejecting_needs_a_reason(self):
        self.ground.status = Ground.Status.REJECTED
        with self.assertRaises(ValidationError):
            self.ground.full_clean()
        self.ground.review_note = 'Lalpurja photo is blurry'
        self.ground.full_clean()
