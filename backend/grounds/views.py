from datetime import datetime, timedelta

from django.utils.dateparse import parse_date
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from bookings.models import Booking

from .models import Ground, slot_has_started
from .serializers import GroundSerializer


class GroundViewSet(viewsets.ReadOnlyModelViewSet):
    """Grounds customers can browse. Owners manage theirs in the admin panel
    for now."""

    queryset = Ground.objects.filter(is_active=True)
    serializer_class = GroundSerializer

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
