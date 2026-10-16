from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import Profile, Role
from accounts.permissions import IsAdminRole, IsGroundOwner
from bookings.models import Booking
from grounds.models import Ground

from .models import Notification, notify_many

LATEST = 50


@api_view(['GET'])
def notification_list(request):
    """The signed-in user's latest notifications and how many are unread."""
    mine = Notification.objects.filter(recipient=request.user)
    latest = [
        {'id': n.id, 'kind': n.kind, 'title': n.title, 'body': n.body, 'is_read': n.is_read,
         'created_at': n.created_at}
        for n in mine[:LATEST]
    ]
    return Response({'unread': mine.filter(is_read=False).count(), 'results': latest})


@api_view(['POST'])
def mark_all_read(request):
    Notification.objects.filter(recipient=request.user, is_read=False).update(is_read=True)
    return Response({'unread': 0})


def _message(request):
    """The title and text of an announcement, checked."""
    title = str(request.data.get('title', '')).strip()
    message = str(request.data.get('message', '')).strip()
    errors = {}
    if not title:
        errors['title'] = 'Please write a title.'
    elif len(title) > 100:
        errors['title'] = 'Please keep the title under 100 characters.'
    if not message:
        errors['message'] = 'Please write the message.'
    elif len(message) > 1000:
        errors['message'] = 'Please keep the message under 1000 characters.'
    if errors:
        raise ValidationError(errors)
    return title, message


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsGroundOwner])
def owner_announcement(request):
    """An owner messages their customers: `audience` "upcoming" (people with
    a booking still to play) or "all" (everyone who ever booked), at one
    `ground` or, if left out, all of the owner's grounds."""
    title, message = _message(request)
    grounds = Ground.objects.filter(owner=request.user)
    ground_id = request.data.get('ground')
    if ground_id not in (None, ''):
        grounds = grounds.filter(pk=ground_id)
        if not grounds.exists():
            raise ValidationError({'ground': 'Pick one of your own grounds.'})
    audience = request.data.get('audience', 'upcoming')
    bookings = Booking.objects.filter(ground__in=grounds)
    if audience == 'upcoming':
        bookings = bookings.filter(date__gte=timezone.localdate(),
                                   status__in=[Booking.Status.CONFIRMED, Booking.Status.PENDING])
    elif audience != 'all':
        raise ValidationError({'audience': 'Use upcoming or all.'})
    names = list(grounds.values_list('name', flat=True))
    sender = names[0] if len(names) == 1 else request.user.full_name or 'Your futsal ground'
    sent = notify_many(bookings.values_list('customer_id', flat=True), Notification.Kind.ANNOUNCEMENT,
                       f'{sender}: {title}', message)
    return Response({'sent': sent})


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsAdminRole])
def admin_announcement(request):
    """The admin messages `audience` "customers", "owners" or "everyone"."""
    title, message = _message(request)
    roles = {'customers': [Role.CUSTOMER], 'owners': [Role.GROUND_OWNER],
             'everyone': [Role.CUSTOMER, Role.GROUND_OWNER]}.get(request.data.get('audience'))
    if roles is None:
        raise ValidationError({'audience': 'Use customers, owners or everyone.'})
    sent = notify_many(Profile.objects.filter(role__in=roles).values_list('id', flat=True),
                       Notification.Kind.ANNOUNCEMENT, f'Futsal Finder: {title}', message)
    return Response({'sent': sent})
