from datetime import datetime, timedelta

from django.db.models import Exists, OuterRef
from django.utils.dateparse import parse_date
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from bookings.models import Booking

from .models import Favourite, Ground, slot_has_started
from .serializers import GroundSerializer


class GroundViewSet(viewsets.ReadOnlyModelViewSet):
    """Grounds customers can browse. Owners manage theirs in the admin panel
    for now."""

    serializer_class = GroundSerializer

    def get_queryset(self):
        mine = Favourite.objects.filter(ground=OuterRef('pk'), customer=self.request.user)
        return Ground.objects.filter(is_active=True).annotate(is_favourite=Exists(mine))

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
                'available': start not in booked and not slot_has_started(day, start),
            })
        return Response({'date': day.isoformat(), 'slots': slots})
