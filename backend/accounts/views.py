from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import Preferences
from .serializers import MeSerializer


@api_view(['GET', 'PATCH'])
def me(request):
    """The signed-in user's profile and app preferences. PATCH any of
    full_name, mobile_number, or preferences.{theme, language,
    notifications_enabled} to change them."""
    profile = request.user
    Preferences.objects.get_or_create(profile=profile)

    if request.method == 'PATCH':
        serializer = MeSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
    return Response(MeSerializer(profile).data)
