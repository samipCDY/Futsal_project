from datetime import timedelta

from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.exceptions import APIException

from accounts.models import Role
from grounds.models import Ground, slot_has_started

from . import payments
from .models import Booking, release_unpaid_slots

MAX_DAYS_AHEAD = 30


class SlotAlreadyBooked(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = 'Sorry, someone just booked this slot. Please pick another time.'
    default_code = 'slot_already_booked'


class BookingSerializer(serializers.ModelSerializer):
    ground = serializers.PrimaryKeyRelatedField(queryset=Ground.objects.visible())
    ground_name = serializers.CharField(source='ground.name', read_only=True)
    end_time = serializers.TimeField(read_only=True)
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()
    free_cancel_until = serializers.DateTimeField(read_only=True)
    payment_due_by = serializers.DateTimeField(read_only=True)
    refund_if_cancelled_now = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = [
            'id', 'booking_ref', 'ground', 'ground_name', 'date', 'start_time', 'end_time',
            'price', 'payment_method', 'status', 'created_at', 'customer_name', 'customer_phone',
            'free_cancel_until', 'refund_if_cancelled_now', 'cancelled_by', 'cancelled_at', 'cancel_reason',
            'refund_amount', 'payment_status', 'payment_due_by', 'payment_txn_id', 'refund_status',
        ]
        read_only_fields = ['booking_ref', 'price', 'status', 'created_at', 'cancelled_by', 'cancelled_at',
                            'cancel_reason', 'refund_amount', 'payment_status', 'payment_txn_id',
                            'refund_status']
        # Double bookings are caught by the database constraint in create(),
        # which also covers two requests racing for the same slot.
        validators = []

    def validate_payment_method(self, value):
        if not payments.available_methods().get(value):
            raise serializers.ValidationError("This payment method isn't available yet. Please pick another.")
        return value

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
        closure = ground.closure_on(day)
        if closure:
            raise serializers.ValidationError(
                {'date': f'{ground.name} is closed for maintenance that day: {closure.reason}'})
        return attrs

    def _can_see_customer(self, booking):
        """Who booked is shared only with the ground's owner and admins."""
        user = self.context['request'].user
        return user.role == Role.ADMIN or (user.role == Role.GROUND_OWNER and booking.ground.owner_id == user.pk)

    def get_customer_name(self, booking):
        return booking.customer.full_name if self._can_see_customer(booking) else None

    def get_customer_phone(self, booking):
        return booking.customer.mobile_number if self._can_see_customer(booking) else None

    def get_refund_if_cancelled_now(self, booking):
        """What cancelling right now would give back, for the cancel button.
        Only online payments are refunded; owners and admins refund in full."""
        if booking.status not in (Booking.Status.PENDING, Booking.Status.CONFIRMED):
            return None
        if not booking.is_paid:
            return '0.00'
        if self.context['request'].user.role == Role.CUSTOMER:
            return f'{booking.customer_refund():.2f}'
        return f'{booking.price:.2f}'

    def to_representation(self, booking):
        data = super().to_representation(booking)
        # Once a confirmed slot's hour is over, the game has been played.
        if booking.status == Booking.Status.CONFIRMED and slot_has_started(booking.date, booking.end_time):
            data['status'] = Booking.Status.COMPLETED
        return data

    def create(self, validated_data):
        validated_data['customer'] = self.context['request'].user
        validated_data['price'] = validated_data['ground'].price_at(validated_data['start_time'])
        online = validated_data.get('payment_method', Booking.PaymentMethod.CASH) != Booking.PaymentMethod.CASH
        if online:
            # Holds the slot while the customer pays; confirmed once paid.
            validated_data['status'] = Booking.Status.PENDING
        release_unpaid_slots()
        try:
            with transaction.atomic():
                booking = super().create(validated_data)
        except IntegrityError:
            raise SlotAlreadyBooked()
        if not online:
            booking.notify_booked()
        return booking
