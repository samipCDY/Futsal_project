from datetime import timedelta

from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.exceptions import APIException

from grounds.models import Ground, slot_has_started

from .models import Booking

MAX_DAYS_AHEAD = 30


class SlotAlreadyBooked(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = 'Sorry, someone just booked this slot. Please pick another time.'
    default_code = 'slot_already_booked'


class BookingSerializer(serializers.ModelSerializer):
    ground = serializers.PrimaryKeyRelatedField(queryset=Ground.objects.filter(is_active=True))
    ground_name = serializers.CharField(source='ground.name', read_only=True)
    end_time = serializers.TimeField(read_only=True)

    class Meta:
        model = Booking
        fields = [
            'id', 'booking_ref', 'ground', 'ground_name', 'date', 'start_time', 'end_time',
            'price', 'payment_method', 'status', 'created_at',
        ]
        read_only_fields = ['booking_ref', 'price', 'status', 'created_at']
        # Double bookings are caught by the database constraint in create(),
        # which also covers two requests racing for the same slot.
        validators = []

    def validate(self, attrs):
        ground, day, start = attrs['ground'], attrs['date'], attrs['start_time']
        if start not in ground.slot_starts():
            raise serializers.ValidationError(
                {'start_time': "Pick a 1-hour slot within the ground's opening hours."})
        if slot_has_started(day, start):
            raise serializers.ValidationError({'start_time': 'This slot has already started.'})
        if day > timezone.localdate() + timedelta(days=MAX_DAYS_AHEAD):
            raise serializers.ValidationError(
                {'date': f'You can book up to {MAX_DAYS_AHEAD} days ahead.'})
        return attrs

    def to_representation(self, booking):
        data = super().to_representation(booking)
        # Once a confirmed slot's hour is over, the game has been played.
        if booking.status == Booking.Status.CONFIRMED and slot_has_started(booking.date, booking.end_time):
            data['status'] = Booking.Status.COMPLETED
        return data

    def create(self, validated_data):
        validated_data['customer'] = self.context['request'].user
        validated_data['price'] = validated_data['ground'].price_per_hour
        try:
            with transaction.atomic():
                return super().create(validated_data)
        except IntegrityError:
            raise SlotAlreadyBooked()
