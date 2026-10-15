import time
import uuid
from datetime import time as clock
from unittest import mock

import jwt
from cryptography.hazmat.primitives.asymmetric import ec
from django.conf import settings
from django.db import connection
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from .models import Profile, Role


class ProfilesTableMixin:
    """`profiles` belongs to Supabase, so Django's test database doesn't have
    it. Create it for the duration of the test class."""

    @classmethod
    def setUpClass(cls):
        with connection.schema_editor() as editor:
            editor.create_model(Profile)
        super().setUpClass()

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        with connection.schema_editor() as editor:
            editor.delete_model(Profile)


def make_profile(role=Role.CUSTOMER, name='Test User'):
    return Profile.objects.create(id=uuid.uuid4(), full_name=name, role=role, created_at=timezone.now())


class SupabaseJWTAuthenticationTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.private_key = ec.generate_private_key(ec.SECP256R1())
        signing_key = mock.Mock(key=self.private_key.public_key())
        patcher = mock.patch('accounts.authentication._jwks_client.get_signing_key_from_jwt',
                             return_value=signing_key)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.client = APIClient()

    def token(self, sub, **overrides):
        claims = {
            'sub': str(sub),
            'aud': 'authenticated',
            'iss': settings.SUPABASE_JWT_ISSUER,
            'exp': int(time.time()) + 3600,
            **overrides,
        }
        return jwt.encode(claims, self.private_key, algorithm='ES256')

    def get_me(self, token):
        return self.client.get('/api/accounts/me/', HTTP_AUTHORIZATION=f'Bearer {token}')

    def test_valid_token_returns_profile_with_role_from_profiles(self):
        profile = make_profile(role=Role.GROUND_OWNER)
        # A role in user_metadata must be ignored: users can edit it themselves.
        response = self.get_me(self.token(profile.id, user_metadata={'role': 'admin'}))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['role'], Role.GROUND_OWNER)

    def test_rejects_expired_token(self):
        profile = make_profile()
        response = self.get_me(self.token(profile.id, exp=int(time.time()) - 10))
        self.assertEqual(response.status_code, 401)

    def test_rejects_wrong_audience(self):
        profile = make_profile()
        response = self.get_me(self.token(profile.id, aud='anon'))
        self.assertEqual(response.status_code, 401)

    def test_rejects_token_signed_by_another_key(self):
        profile = make_profile()
        other_key = ec.generate_private_key(ec.SECP256R1())
        forged = jwt.encode(
            {'sub': str(profile.id), 'aud': 'authenticated', 'iss': settings.SUPABASE_JWT_ISSUER,
             'exp': int(time.time()) + 3600},
            other_key, algorithm='ES256')
        self.assertEqual(self.get_me(forged).status_code, 401)

    def test_rejects_user_without_profile(self):
        self.assertEqual(self.get_me(self.token(uuid.uuid4())).status_code, 401)

    def test_requires_token(self):
        self.assertEqual(self.client.get('/api/accounts/me/').status_code, 401)


class MeApiTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.profile = make_profile(name='Samip')
        self.client = APIClient()
        self.client.force_authenticate(user=self.profile)

    def test_get_includes_default_preferences(self):
        body = self.client.get('/api/accounts/me/').json()
        self.assertEqual(body['full_name'], 'Samip')
        self.assertEqual(body['preferences'],
                         {'theme': 'system', 'language': 'en', 'notifications_enabled': True})

    def test_patch_updates_profile_and_preferences(self):
        response = self.client.patch('/api/accounts/me/', {
            'first_name': '  Samip ',
            'last_name': 'Chaudhary',
            'date_of_birth': '2002-05-17',
            'gender': 'male',
            'mobile_number': '974 434 0506',
            'address': ' Naya Baneshwor ',
            'city': 'Kathmandu',
            'preferences': {'theme': 'dark'},
        }, format='json')
        self.assertEqual(response.status_code, 200, response.json())
        self.profile.refresh_from_db()
        self.assertEqual((self.profile.first_name, self.profile.last_name), ('Samip', 'Chaudhary'))
        self.assertEqual(self.profile.full_name, 'Samip Chaudhary')  # kept in step automatically
        self.assertEqual(str(self.profile.date_of_birth), '2002-05-17')
        self.assertEqual(self.profile.gender, 'male')
        self.assertEqual(self.profile.mobile_number, '9744340506')
        self.assertEqual((self.profile.address, self.profile.city), ('Naya Baneshwor', 'Kathmandu'))
        prefs = self.client.get('/api/accounts/me/').json()['preferences']
        self.assertEqual(prefs, {'theme': 'dark', 'language': 'en', 'notifications_enabled': True})

    def test_mobile_number_must_be_exactly_10_digits(self):
        for mobile in ['  ', '974434050', '97443405061', '+9779744340506', '97443405o6']:
            response = self.client.patch('/api/accounts/me/', {'mobile_number': mobile}, format='json')
            self.assertEqual(response.status_code, 400, mobile)
            self.assertEqual(set(response.json()), {'mobile_number'})

    def test_avatar_must_be_in_own_folder(self):
        own = f'{settings.SUPABASE_URL}/storage/v1/object/public/avatars/{self.profile.id}/avatar-1.jpg'
        response = self.client.patch('/api/accounts/me/', {'avatar_url': own}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['avatar_url'], own)

        someone_else = f'{settings.SUPABASE_URL}/storage/v1/object/public/avatars/{uuid.uuid4()}/a.jpg'
        for bad in [someone_else, 'https://evil.example.com/a.jpg', own.replace('avatar-1.jpg', '../x/a.jpg')]:
            response = self.client.patch('/api/accounts/me/', {'avatar_url': bad}, format='json')
            self.assertEqual(response.status_code, 400, bad)

        response = self.client.patch('/api/accounts/me/', {'avatar_url': ''}, format='json')
        self.assertEqual(response.json()['avatar_url'], '')

    def test_blank_gender_is_stored_as_not_set(self):
        self.client.patch('/api/accounts/me/', {'gender': ''}, format='json')
        self.profile.refresh_from_db()
        self.assertIsNone(self.profile.gender)

    def test_cannot_change_role_email_or_full_name_directly(self):
        self.client.patch('/api/accounts/me/', {'role': 'admin', 'email': 'x@y.com', 'full_name': 'Hacker'},
                          format='json')
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.role, Role.CUSTOMER)
        self.assertEqual(self.profile.email, '')
        self.assertEqual(self.profile.full_name, 'Samip')

    def test_rejects_bad_details(self):
        response = self.client.patch('/api/accounts/me/', {
            'first_name': '  ', 'mobile_number': 'abc', 'date_of_birth': '2999-01-01', 'gender': 'robot',
        }, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertEqual(set(response.json()), {'first_name', 'mobile_number', 'date_of_birth', 'gender'})

    def test_rejects_unknown_theme(self):
        response = self.client.patch('/api/accounts/me/', {'preferences': {'theme': 'pink'}}, format='json')
        self.assertEqual(response.status_code, 400)
