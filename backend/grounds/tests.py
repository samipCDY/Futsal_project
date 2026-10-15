from datetime import time

from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile

from .models import Ground


class FavouriteApiTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        owner = make_profile(Role.GROUND_OWNER)
        self.arena = Ground.objects.create(owner=owner, name='Arena', area='Baneshwor', latitude=27.69,
                                           longitude=85.33, price_per_hour=1400, opens_at=time(6), closes_at=time(22))
        self.hub = Ground.objects.create(owner=owner, name='Hub', area='Patan', latitude=27.67,
                                         longitude=85.32, price_per_hour=1200)
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
