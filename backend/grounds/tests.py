from datetime import time
from unittest.mock import patch

from django.conf import settings
from django.core import mail
from django.core.exceptions import ValidationError
from django.test import TestCase, override_settings
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


@override_settings(ADMIN_NOTIFY_EMAILS=[])
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

    @override_settings(ADMIN_NOTIFY_EMAILS=['boss@example.com', 'team@example.com'])
    def test_approval_email_can_go_to_chosen_inboxes(self):
        with self.captureOnCommitCallbacks(execute=True):
            self.add_ground()
        self.assertEqual(mail.outbox[0].to, ['boss@example.com', 'team@example.com'])

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

    def test_photo_gallery_cover_is_first_and_limited_to_ten(self):
        folder = f'{settings.SUPABASE_URL}/storage/v1/object/public/ground-photos/{self.owner.id}/'
        photos = [f'{folder}p{i}.jpg' for i in range(3)]
        response = self.client_for(self.owner).post('/api/owner/grounds/', {**self.valid, 'photos': photos},
                                                    format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual((response.json()['photos'], response.json()['image_url']), (photos, photos[0]))

        ground_id = response.json()['id']
        response = self.client_for(self.owner).patch(f'/api/owner/grounds/{ground_id}/', {'photos': []},
                                                     format='json')
        self.assertEqual((response.json()['photos'], response.json()['image_url']), ([], ''))

        for bad in ([f'{folder}p{i}.jpg' for i in range(11)], [photos[0], photos[0]],
                    [photos[0].replace(str(self.owner.id), str(self.other_owner.id))]):
            response = self.client_for(self.owner).patch(f'/api/owner/grounds/{ground_id}/', {'photos': bad},
                                                         format='json')
            self.assertEqual(response.status_code, 400, bad)

    def test_old_apps_sending_one_photo_fill_the_gallery(self):
        own = f'{settings.SUPABASE_URL}/storage/v1/object/public/ground-photos/{self.owner.id}/g.jpg'
        response = self.client_for(self.owner).post('/api/owner/grounds/', {**self.valid, 'image_url': own},
                                                    format='json')
        self.assertEqual(response.json()['photos'], [own])

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

    def test_ground_page_shows_owner_and_map(self):
        page = self.client.get(f'/admin/grounds/ground/{self.ground.pk}/change/').content.decode()
        self.assertIn('owner@example.com', page)
        self.assertIn('google.com/maps?q=27.69', page)


class AdminApprovalApiTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Ram Owner')
        self.owner.email, self.owner.mobile_number = 'ram@example.com', '9800000002'
        self.owner.save()
        self.admin = make_profile(Role.ADMIN)
        self.customer = make_profile()

        def ground(name, status):
            return Ground.objects.create(owner=self.owner, name=name, area='Patan', latitude='27.67',
                                         longitude='85.32', morning_price=1, day_price=1, evening_price=1,
                                         status=status, ownership_document=f'{self.owner.id}/photo-1.jpg')
        self.pending = ground('Waiting', Ground.Status.PENDING)
        self.live = ground('Live', Ground.Status.APPROVED)

    def client_for(self, profile):
        client = APIClient()
        client.force_authenticate(user=profile)
        return client

    def test_only_admins_can_review(self):
        for profile in (self.owner, self.customer):
            client = self.client_for(profile)
            self.assertEqual(client.get('/api/admin/grounds/').status_code, 403)
            self.assertEqual(client.post(f'/api/admin/grounds/{self.pending.id}/approve/').status_code, 403)
            self.assertEqual(client.get('/api/admin/summary/').status_code, 403)

    def test_admin_sees_pending_grounds_with_owner_details(self):
        client = self.client_for(self.admin)
        listed = client.get('/api/admin/grounds/').json()
        self.assertEqual([g['name'] for g in listed], ['Waiting'])
        self.assertEqual((listed[0]['owner_name'], listed[0]['owner_phone'], listed[0]['owner_email']),
                         ('Ram Owner', '9800000002', 'ram@example.com'))
        self.assertEqual([g['name'] for g in client.get('/api/admin/grounds/', {'status': 'approved'}).json()],
                         ['Live'])
        self.assertEqual(client.get('/api/admin/summary/').json(), {'pending': 1, 'approved': 1, 'rejected': 0})

    @override_settings(SUPABASE_SECRET_KEY='')
    def test_document_link_is_only_made_for_one_ground(self):
        client = self.client_for(self.admin)
        self.assertIsNone(client.get('/api/admin/grounds/').json()[0]['document_url'])
        with patch('grounds.serializers.signed_document_url', return_value='https://signed') as sign:
            detail = client.get(f'/api/admin/grounds/{self.pending.id}/').json()
        self.assertEqual(detail['document_url'], 'https://signed')
        sign.assert_called_once_with(f'{self.owner.id}/photo-1.jpg')

    def test_approve_and_reject(self):
        client = self.client_for(self.admin)
        with self.captureOnCommitCallbacks(execute=True):
            approved = client.post(f'/api/admin/grounds/{self.pending.id}/approve/').json()
        self.assertEqual(approved['status'], 'approved')
        self.assertEqual(mail.outbox[0].to, ['ram@example.com'])

        url = f'/api/admin/grounds/{self.live.id}/reject/'
        self.assertEqual(client.post(url, {'review_note': ' '}, format='json').status_code, 400)
        rejected = client.post(url, {'review_note': 'Name on lalpurja is different'}, format='json').json()
        self.assertEqual((rejected['status'], rejected['review_note']), ('rejected', 'Name on lalpurja is different'))
        self.assertIsNotNone(rejected['reviewed_at'])

    def test_search_finds_grounds_of_any_status(self):
        client = self.client_for(self.admin)

        def found(text):
            return sorted(g['name'] for g in client.get('/api/admin/grounds/', {'search': text}).json())

        self.assertEqual(found('live'), ['Live'])           # ground name, even though approved
        self.assertEqual(found('ram owner'), ['Live', 'Waiting'])  # owner name, any case
        self.assertEqual(found('98000000'), ['Live', 'Waiting'])   # owner phone
        self.assertEqual(found('patan'), ['Live', 'Waiting'])      # area
        self.assertEqual(found('nothing like this'), [])

    def test_admin_can_reject_an_approved_ground_after_a_complaint(self):
        client = self.client_for(self.admin)
        client.post(f'/api/admin/grounds/{self.live.id}/reject/', {'review_note': 'Customers reported a fake listing'},
                    format='json')
        self.assertEqual(client.get('/api/admin/summary/').json(), {'pending': 1, 'approved': 0, 'rejected': 1})
        self.assertEqual(self.client_for(self.customer).get('/api/grounds/').json(), [])
