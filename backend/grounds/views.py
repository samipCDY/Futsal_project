from datetime import datetime, timedelta

from django.db import transaction
from django.db.models import Avg, Count, Exists, OuterRef, Q
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.permissions import IsAdminRole, IsGroundOwner
from bookings.models import Booking, release_unpaid_slots
from notifications.models import Notification, notify

from .models import Event, Favourite, Ground, Maintenance, Review, slot_has_started
from .serializers import (AdminGroundSerializer, EventSerializer, GroundSerializer, MaintenanceSerializer,
                          OwnerEventSerializer, OwnerGroundSerializer, ReviewSerializer)


def has_played_at(customer, ground):
    """Whether `customer` has had a game at `ground` (a booking that wasn't
    cancelled and whose slot has started), so they may review it."""
    today = timezone.localdate()
    games = (Booking.objects.filter(customer=customer, ground=ground, date__lte=today)
             .exclude(status=Booking.Status.CANCELLED)
             .exclude(status=Booking.Status.PENDING, payment_status=Booking.PaymentStatus.UNPAID)
             .values_list('date', 'start_time'))
    return any(slot_has_started(day, start) for day, start in games)


class GroundViewSet(viewsets.ReadOnlyModelViewSet):
    """Approved grounds customers can browse and book. Owners manage theirs
    through OwnerGroundViewSet."""

    serializer_class = GroundSerializer

    def get_queryset(self):
        mine = Favourite.objects.filter(ground=OuterRef('pk'), customer=self.request.user)
        return (Ground.objects.visible()
                .annotate(is_favourite=Exists(mine), rating_average=Avg('reviews__rating'),
                          review_count=Count('reviews', distinct=True))
                .prefetch_related('maintenance_periods'))

    @action(detail=True, methods=['get', 'post', 'delete'])
    def reviews(self, request, pk=None):
        """GET: the ground's reviews (newest first), the star breakdown, the
        signed-in user's own review and whether they may write one.
        POST `{rating, comment}`: write or update your review; only after
        playing there. DELETE: remove your review."""
        ground = self.get_object()
        mine = Review.objects.filter(ground=ground, customer=request.user).first()

        if request.method == 'DELETE':
            if mine:
                mine.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)

        if request.method == 'POST':
            if not has_played_at(request.user, ground):
                raise ValidationError({'detail': 'You can review a ground after you have played there.'})
            serializer = ReviewSerializer(mine, data=request.data)
            serializer.is_valid(raise_exception=True)
            is_new = mine is None
            review = serializer.save(ground=ground, customer=request.user)
            if is_new:
                stars = '★' * review.rating
                notify(ground.owner_id, Notification.Kind.REVIEW, f'New {review.rating}★ review for {ground.name}',
                       f'{request.user.full_name or "A customer"} rated it {stars}'
                       f'{": " + review.comment[:200] if review.comment else "."}')
            return Response(ReviewSerializer(review).data,
                            status=status.HTTP_201_CREATED if is_new else status.HTTP_200_OK)

        reviews = Review.objects.filter(ground=ground).select_related('customer')
        counts = dict(reviews.order_by().values_list('rating').annotate(total=Count('id')))
        return Response({
            'rating': ground.rating_average and round(ground.rating_average, 1),
            'review_count': ground.review_count,
            'stars': {str(stars): counts.get(stars, 0) for stars in range(5, 0, -1)},
            'my_review': ReviewSerializer(mine).data if mine else None,
            'can_review': mine is not None or has_played_at(request.user, ground),
            'reviews': ReviewSerializer(reviews[:50], many=True).data,
        })

    @action(detail=False)
    def favourites(self, request):
        """The signed-in user's saved grounds, most recently saved first."""
        ids = list(Favourite.objects.filter(customer=request.user).values_list('ground_id', flat=True))
        grounds = {ground.id: ground for ground in self.get_queryset().filter(id__in=ids)}
        return Response(self.get_serializer([grounds[i] for i in ids if i in grounds], many=True).data)

    @action(detail=True, methods=['post', 'delete'])
    def favourite(self, request, pk=None):
        """POST to save this ground, DELETE to un-save it."""
        ground = self.get_object()
        if request.method == 'POST':
            Favourite.objects.get_or_create(customer=request.user, ground=ground)
        else:
            Favourite.objects.filter(customer=request.user, ground=ground).delete()
        return Response({'is_favourite': request.method == 'POST'})

    @action(detail=True)
    def slots(self, request, pk=None):
        """Every 1-hour slot on `?date=YYYY-MM-DD` and whether it can be booked."""
        ground = self.get_object()
        day = parse_date(request.query_params.get('date') or '')
        if day is None:
            raise ValidationError({'date': 'Pass a date as YYYY-MM-DD.'})

        closure = ground.closure_on(day)
        release_unpaid_slots()
        booked = set(
            ground.bookings.filter(date=day)
            .exclude(status=Booking.Status.CANCELLED)
            .values_list('start_time', flat=True)
        )
        slots = []
        for start in ground.slot_starts():
            end = (datetime.combine(day, start) + timedelta(hours=1)).time()
            slots.append({
                'start_time': start.strftime('%H:%M'),
                'end_time': end.strftime('%H:%M'),
                'price': f'{ground.price_at(start):.2f}',
                'available': not closure and start not in booked and not slot_has_started(day, start),
            })
        return Response({
            'date': day.isoformat(),
            'closed_reason': closure.reason if closure else None,
            'slots': slots,
        })


class OwnerGroundViewSet(mixins.CreateModelMixin,
                         mixins.ListModelMixin,
                         mixins.RetrieveModelMixin,
                         mixins.UpdateModelMixin,
                         viewsets.GenericViewSet):
    """A ground owner's own grounds. No delete: past bookings point at the
    ground, so owners hide it with is_active instead."""

    serializer_class = OwnerGroundSerializer
    permission_classes = [IsAuthenticated, IsGroundOwner]

    def get_queryset(self):
        return (Ground.objects.filter(owner=self.request.user).order_by('-created_at')
                .prefetch_related('maintenance_periods'))

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @action(detail=True, methods=['post'])
    def maintenance(self, request, pk=None):
        """Closes the ground from `starts_on` to `ends_on` (inclusive) with a
        `reason` customers see. Everyone already booked on those days is
        cancelled with a full refund and told why."""
        ground = self.get_object()
        serializer = MaintenanceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            period = serializer.save(ground=ground)
            affected = (ground.bookings
                        .filter(date__range=(period.starts_on, period.ends_on),
                                status__in=[Booking.Status.PENDING, Booking.Status.CONFIRMED])
                        .select_related('ground', 'customer'))
            cancelled = 0
            for booking in affected:
                if slot_has_started(booking.date, booking.start_time):
                    continue
                booking.cancel(Booking.CancelledBy.OWNER, f'Closed for maintenance: {period.reason}',
                               kind=Notification.Kind.MAINTENANCE, title=f'{ground.name} is under maintenance')
                cancelled += 1
        return Response({**serializer.data, 'cancelled_bookings': cancelled}, status=status.HTTP_201_CREATED)


class OwnerMaintenanceViewSet(mixins.DestroyModelMixin, viewsets.GenericViewSet):
    """Lets an owner end a closure early (or call it off). Bookings that were
    cancelled for it stay cancelled."""

    permission_classes = [IsAuthenticated, IsGroundOwner]

    def get_queryset(self):
        return Maintenance.objects.filter(ground__owner=self.request.user)


class EventViewSet(viewsets.ReadOnlyModelViewSet):
    """Published events at listed grounds, for everyone: coming ones first
    (soonest first), then ones that ended in the last month. `?ground=<id>`
    for one ground's events."""

    serializer_class = EventSerializer
    pagination_class = None

    def get_queryset(self):
        cutoff = timezone.now() - timedelta(days=30)
        events = Event.objects.filter(
            Q(starts_at__gte=cutoff) | Q(ends_at__gte=cutoff),  # skip long-finished ones early
            is_published=True,
            ground__in=Ground.objects.visible(),
        ).select_related('ground')
        ground = self.request.query_params.get('ground', '')
        if ground.isdigit():
            events = events.filter(ground_id=ground)
        return events

    def list(self, request, *args, **kwargs):
        events = list(self.get_queryset())
        recent = timezone.now() - timedelta(days=30)
        coming = sorted((e for e in events if not e.is_expired), key=lambda e: e.starts_at)
        ended = sorted((e for e in events if e.is_expired and e.expires_at >= recent),
                       key=lambda e: e.expires_at, reverse=True)
        return Response(self.get_serializer(coming + ended, many=True).data)


class OwnerEventViewSet(viewsets.ModelViewSet):
    """An owner's own events, drafts included. Publish by saving
    `is_published: true`; unpublish with false."""

    serializer_class = OwnerEventSerializer
    permission_classes = [IsAuthenticated, IsGroundOwner]

    def get_queryset(self):
        return Event.objects.filter(owner=self.request.user).select_related('ground').order_by('-starts_at')

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class AdminGroundViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Grounds for an admin to approve or reject. `?status=pending` (the
    default), `approved` or `rejected`, oldest first so nobody waits long.
    `?search=` instead looks through every ground, e.g. to find one a
    complaint is about, by its name, area, address or the owner's details."""

    serializer_class = AdminGroundSerializer
    permission_classes = [IsAuthenticated, IsAdminRole]

    def get_queryset(self):
        grounds = Ground.objects.select_related('owner').order_by('created_at')
        if self.action != 'list':
            return grounds
        search = self.request.query_params.get('search', '').strip()
        if search:
            return grounds.filter(
                Q(name__icontains=search) | Q(area__icontains=search) | Q(address__icontains=search)
                | Q(owner__full_name__icontains=search) | Q(owner__email__icontains=search)
                | Q(owner__mobile_number__icontains=search)
            )
        status = self.request.query_params.get('status', Ground.Status.PENDING)
        if status not in Ground.Status.values:
            raise ValidationError({'status': 'Use pending, approved or rejected.'})
        return grounds.filter(status=status)

    def get_serializer_context(self):
        # Signing the document link is a call to Supabase, so only on one ground.
        return {**super().get_serializer_context(), 'with_document': self.action != 'list'}

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        ground = self.get_object()
        ground.review(Ground.Status.APPROVED)
        return Response(self.get_serializer(ground).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        note = str(request.data.get('review_note', '')).strip()
        if not note:
            raise ValidationError({'review_note': 'Tell the owner why, so they can fix it.'})
        ground = self.get_object()
        ground.review(Ground.Status.REJECTED, note[:255])
        return Response(self.get_serializer(ground).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminRole])
def admin_summary(request):
    """Counts for the admin's approval dashboard."""
    counts = dict(Ground.objects.order_by().values_list('status').annotate(total=Count('id')))
    return Response({status: counts.get(status, 0) for status in Ground.Status.values})
