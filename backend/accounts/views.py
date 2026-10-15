from rest_framework.decorators import api_view
from rest_framework.response import Response


@api_view(['GET'])
def me(request):
    """The signed-in user's profile — handy for checking the token works."""
    profile = request.user
    return Response({
        'id': str(profile.id),
        'full_name': profile.full_name,
        'mobile_number': profile.mobile_number,
        'role': profile.role,
    })
