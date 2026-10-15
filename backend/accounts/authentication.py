import jwt
from django.conf import settings
from rest_framework import authentication, exceptions

from .models import Profile

# Fetches Supabase's public signing keys once and caches them, so verifying a
# token normally needs no network call. Only public keys are involved — the
# backend holds no Supabase secret.
_jwks_client = jwt.PyJWKClient(settings.SUPABASE_JWKS_URL, cache_keys=True)


class SupabaseJWTAuthentication(authentication.BaseAuthentication):
    """Accepts `Authorization: Bearer <Supabase access token>` from the app.

    The token proves who the user is; their role comes from `profiles`, never
    from the token's user_metadata (which users can edit themselves).
    """

    def authenticate(self, request):
        header = authentication.get_authorization_header(request).split()
        if not header or header[0].lower() != b'bearer':
            return None
        if len(header) != 2:
            raise exceptions.AuthenticationFailed('Invalid Authorization header.')

        token = header[1].decode()
        try:
            signing_key = _jwks_client.get_signing_key_from_jwt(token).key
            claims = jwt.decode(
                token,
                signing_key,
                algorithms=['ES256', 'RS256'],
                audience='authenticated',
                issuer=settings.SUPABASE_JWT_ISSUER,
            )
        except jwt.PyJWTError:
            raise exceptions.AuthenticationFailed('Invalid or expired token.')

        profile = Profile.objects.filter(pk=claims['sub']).first()
        if profile is None:
            raise exceptions.AuthenticationFailed('No profile found for this account.')
        return profile, claims

    def authenticate_header(self, request):
        return 'Bearer'
