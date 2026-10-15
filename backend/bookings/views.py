from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import Role
from accounts.permissions import IsCustomer
from grounds.models import slot_has_started

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
        bookings = Booking.objects.select_related('ground')
        if user.role == Role.ADMIN:
            return bookings
        if user.role == Role.GROUND_OWNER:
            return bookings.filter(ground__owner=user)
        return bookings.filter(customer=user)

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
