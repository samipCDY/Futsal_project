from datetime import datetime, timedelta

from django.db.models import Count, Exists, OuterRef, Q
from django.utils.dateparse import parse_date
from rest_framework import mixins, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.permissions import IsAdminRole, IsGroundOwner
from bookings.models import Booking

from .models import Favourite, Ground, slot_has_started
from .serializers import AdminGroundSerializer, GroundSerializer, OwnerGroundSerializer


class GroundViewSet(viewsets.ReadOnlyModelViewSet):
    """Approved grounds customers can browse and book. Owners manage theirs
    through OwnerGroundViewSet."""

    serializer_class = GroundSerializer

    def get_queryset(self):
        mine = Favourite.objects.filter(ground=OuterRef('pk'), customer=self.request.user)
        return Ground.objects.visible().annotate(is_favourite=Exists(mine))

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
                'available': start not in booked and not slot_has_started(day, start),
            })
        return Response({'date': day.isoformat(), 'slots': slots})


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
        return Ground.objects.filter(owner=self.request.user).order_by('-created_at')

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
