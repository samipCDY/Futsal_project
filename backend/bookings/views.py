from datetime import timedelta

from django.db.models import Sum
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import APIException, NotFound, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import Role
from accounts.permissions import IsAdminRole, IsCustomer, IsGroundOwner
from grounds.models import Ground, slot_has_started

from . import payments
from .models import Booking, release_unpaid_slots
from .serializers import BookingSerializer


class BookingViewSet(mixins.CreateModelMixin,
                     mixins.ListModelMixin,
                     mixins.RetrieveModelMixin,
                     viewsets.GenericViewSet):
    """Customers see and book their own slots; owners see bookings at their
    grounds; admins see everything."""

    serializer_class = BookingSerializer

    def get_permissions(self):
        if self.action in ('create', 'pay', 'verify_payment'):
            return [IsAuthenticated(), IsCustomer()]
        return super().get_permissions()

    def get_queryset(self):
        release_unpaid_slots()
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

    def create(self, request, *args, **kwargs):
        """Books a slot. For eSewa/Khalti the answer also has `payment`: what
        the app needs to open the payment page. The slot is held for 15
        minutes and confirmed once verify-payment succeeds."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        booking = serializer.save()
        data = self.get_serializer(booking).data
        if booking.is_online:
            try:
                data['payment'] = payments.start(booking)
            except payments.PaymentError as error:
                booking.delete()  # never reached the gateway: free the slot straight away
                raise PaymentUnavailable(str(error))
        return Response(data, status=status.HTTP_201_CREATED)

    def _own_online_booking(self):
        booking = self.get_object()
        if not booking.is_online:
            raise ValidationError({'detail': 'This booking is paid in cash at the ground.'})
        return booking

    @action(detail=True, methods=['post'])
    def pay(self, request, pk=None):
        """A new payment attempt for a booking still waiting for payment."""
        booking = self._own_online_booking()
        if booking.is_paid:
            raise ValidationError({'detail': 'This booking is already paid.'})
        if booking.status != Booking.Status.PENDING:
            raise ValidationError({'detail': 'The time to pay has run out. Please book again.'})
        try:
            return Response({'payment': payments.start(booking)})
        except payments.PaymentError as error:
            raise PaymentUnavailable(str(error))

    @action(detail=True, methods=['post'], url_path='verify-payment')
    def verify_payment(self, request, pk=None):
        """Asks eSewa/Khalti whether the booking is paid, and confirms it."""
        booking = self._own_online_booking()
        if not booking.is_paid:
            try:
                txn_id = payments.check(booking)
            except payments.PaymentError as error:
                raise PaymentUnavailable(str(error))
            if txn_id is None:
                raise ValidationError({'detail': 'The payment was not completed.'})
            booking.mark_paid(txn_id)
        return Response(self.get_serializer(booking).data)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Customers get a full refund within the free-cancellation window and
        part of it after (see bookings/models.py). When the owner or an admin
        cancels, the customer always gets everything back; they may send a
        `reason` the customer will see."""
        booking = self.get_object()
        if booking.status not in (Booking.Status.PENDING, Booking.Status.CONFIRMED):
            raise ValidationError({'detail': 'Only upcoming bookings can be cancelled.'})
        if slot_has_started(booking.date, booking.start_time):
            raise ValidationError({'detail': 'This slot has already started.'})
        by_customer = request.user.role == Role.CUSTOMER
        booking.cancel(
            Booking.CancelledBy.CUSTOMER if by_customer else Booking.CancelledBy.OWNER,
            '' if by_customer else str(request.data.get('reason', '')),
        )
        return Response(self.get_serializer(booking).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsGroundOwner])
def owner_summary(request):
    """Numbers for the owner's Dashboard. Weeks run Sunday to Saturday."""
    owner = request.user
    today = timezone.localdate()
    week_start = today - timedelta(days=(today.weekday() + 1) % 7)
    week_end = week_start + timedelta(days=6)
    mine = Booking.objects.filter(ground__owner=owner)
    live = mine.exclude(status=Booking.Status.CANCELLED)
    this_week = live.filter(date__range=(week_start, week_end))
    # Late cancellations still earn the owner the part that isn't refunded.
    kept = sum(b.owner_keeps for b in mine.filter(status=Booking.Status.CANCELLED,
                                                   date__range=(week_start, week_end)))

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
        'week_earnings': f"{(this_week.aggregate(total=Sum('price'))['total'] or 0) + kept:.2f}",
        'week_start': week_start.isoformat(),
        'active_grounds': grounds.visible().count(),
        'total_grounds': grounds.count(),
        'pending_grounds': grounds.filter(status=Ground.Status.PENDING).count(),
        'rejected_grounds': grounds.filter(status=Ground.Status.REJECTED).count(),
        'upcoming': BookingSerializer(upcoming, many=True, context={'request': request}).data,
    })


class PaymentUnavailable(APIException):
    status_code = status.HTTP_502_BAD_GATEWAY
    default_detail = "Couldn't reach the payment service. Please try again."
    default_code = 'payment_unavailable'


@api_view(['GET'])
def payment_methods(request):
    """Which ways to pay the app should offer."""
    return Response(payments.available_methods())


class AdminRefundViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Online refunds for an admin to send back through eSewa/Khalti, then
    mark as sent. `?status=pending` (default) or `done`."""

    serializer_class = BookingSerializer
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get_queryset(self):
        wanted = self.request.query_params.get('status', Booking.RefundStatus.PENDING)
        if wanted not in (Booking.RefundStatus.PENDING, Booking.RefundStatus.DONE):
            raise ValidationError({'status': 'Use pending or done.'})
        return (Booking.objects.filter(refund_status=wanted).select_related('ground', 'customer')
                .order_by('cancelled_at'))

    @action(detail=True, methods=['post'])
    def done(self, request, pk=None):
        booking = Booking.objects.filter(pk=pk, refund_status=Booking.RefundStatus.PENDING).first()
        if booking is None:
            raise NotFound('No refund waiting for this booking.')
        booking.mark_refunded()
        return Response(self.get_serializer(booking).data)
