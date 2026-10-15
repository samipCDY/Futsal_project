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
