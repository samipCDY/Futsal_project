from datetime import timedelta

from django.db.models import Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import mixins, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import Role
from accounts.permissions import IsCustomer, IsGroundOwner
from grounds.models import Ground, slot_has_started

from .models import Booking
from .serializers import BookingSerializer


class BookingViewSet(mixins.CreateModelMixin,
                     mixins.ListModelMixin,
                     mixins.RetrieveModelMixin,
                     viewsets.GenericViewSet):
    """Customers see and book their own slots; owners see bookings at their
    grounds; admins see everything."""

    serializer_class = BookingSerializer

    def get_permissions(self):
        if self.action == 'create':
            return [IsAuthenticated(), IsCustomer()]
        return super().get_permissions()

    def get_queryset(self):
        user = self.request.user
        bookings = Booking.objects.select_related('ground', 'customer')
        if user.role == Role.GROUND_OWNER:
            bookings = bookings.filter(ground__owner=user)
        elif user.role != Role.ADMIN:
            bookings = bookings.filter(customer=user)

        # Optional filters: ?date=YYYY-MM-DD and ?ground=<id>
        params = self.request.query_params
        if 'date' in params:
            day = parse_date(params['date'])
            if day is None:
                raise ValidationError({'date': 'Pass a date as YYYY-MM-DD.'})
            bookings = bookings.filter(date=day)
        if params.get('ground', '').isdigit():
            bookings = bookings.filter(ground_id=params['ground'])
        return bookings

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        booking = self.get_object()
        if booking.status not in (Booking.Status.PENDING, Booking.Status.CONFIRMED):
            raise ValidationError({'detail': 'Only upcoming bookings can be cancelled.'})
        if slot_has_started(booking.date, booking.start_time):
            raise ValidationError({'detail': 'This slot has already started.'})
        booking.status = Booking.Status.CANCELLED
        booking.save(update_fields=['status'])
        return Response(self.get_serializer(booking).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsGroundOwner])
def owner_summary(request):
    """Numbers for the owner's Dashboard. Weeks run Sunday to Saturday."""
    owner = request.user
    today = timezone.localdate()
    week_start = today - timedelta(days=(today.weekday() + 1) % 7)
    week_end = week_start + timedelta(days=6)
    live = Booking.objects.filter(ground__owner=owner).exclude(status=Booking.Status.CANCELLED)
    this_week = live.filter(date__range=(week_start, week_end))

    upcoming = []
    for booking in live.filter(date__gte=today).select_related('ground', 'customer').order_by('date', 'start_time'):
        if not slot_has_started(booking.date, booking.end_time):
            upcoming.append(booking)
        if len(upcoming) == 5:
            break

    grounds = Ground.objects.filter(owner=owner)
    return Response({
        'today_bookings': live.filter(date=today).count(),
        'week_bookings': this_week.count(),
        'week_earnings': f"{this_week.aggregate(total=Sum('price'))['total'] or 0:.2f}",
        'week_start': week_start.isoformat(),
        'active_grounds': grounds.visible().count(),
        'total_grounds': grounds.count(),
        'pending_grounds': grounds.filter(status=Ground.Status.PENDING).count(),
        'rejected_grounds': grounds.filter(status=Ground.Status.REJECTED).count(),
        'upcoming': BookingSerializer(upcoming, many=True, context={'request': request}).data,
    })
