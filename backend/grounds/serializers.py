import re
from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework import serializers

from . import notify
from .models import Event, Ground, Maintenance
from .storage import signed_document_url

# An admin checks these again when the owner changes them.
REVIEWED_FIELDS = ('name', 'area', 'address', 'latitude', 'longitude', 'ownership_document')


class MaintenanceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Maintenance
        fields = ['id', 'starts_on', 'ends_on', 'reason']

    def validate_reason(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Tell customers why, e.g. "Replacing the turf".')
        return value

    def validate(self, attrs):
        today = timezone.localdate()
        if attrs['starts_on'] < today:
            raise serializers.ValidationError({'starts_on': "Maintenance can't start in the past."})
        if attrs['ends_on'] < attrs['starts_on']:
            raise serializers.ValidationError({'ends_on': 'The last day must be on or after the first day.'})
        if attrs['ends_on'] > today + timedelta(days=365):
            raise serializers.ValidationError({'ends_on': 'Please pick dates within the next year.'})
        return attrs


class _UpcomingMaintenance(serializers.Field):
    """The ground's current and future closures."""

    def __init__(self, **kwargs):
        super().__init__(source='*', read_only=True, **kwargs)

    def to_representation(self, ground):
        today = timezone.localdate()
        periods = [m for m in ground.maintenance_periods.all() if m.ends_on >= today]
        return MaintenanceSerializer(periods, many=True).data


class GroundSerializer(serializers.ModelSerializer):
    # Filled in by GroundViewSet.get_queryset for the signed-in user.
    is_favourite = serializers.BooleanField(read_only=True, default=False)
    maintenance = _UpcomingMaintenance()

    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'area', 'address', 'latitude', 'longitude', 'morning_price', 'day_price',
            'evening_price', 'image_url', 'badge_label', 'opens_at', 'closes_at', 'is_favourite',
            'maintenance',
        ]


class OwnerGroundSerializer(serializers.ModelSerializer):
    """A ground as its owner manages it. The owner is always the signed-in
    user, and only an admin can approve it."""

    maintenance = _UpcomingMaintenance()

    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'area', 'address', 'latitude', 'longitude', 'morning_price', 'day_price',
            'evening_price', 'image_url', 'badge_label', 'opens_at', 'closes_at', 'is_active',
            'ownership_document', 'status', 'review_note', 'created_at', 'maintenance',
        ]
        read_only_fields = ['id', 'status', 'review_note', 'created_at']

    def _required_text(self, value, label):
        value = value.strip()
        if not value:
            raise serializers.ValidationError(f'Please enter the {label}.')
        return value

    def validate_name(self, value):
        return self._required_text(value, "ground's name")

    def validate_area(self, value):
        return self._required_text(value, 'area')

    def validate_address(self, value):
        return value.strip()

    def validate_badge_label(self, value):
        return value.strip()

    def _price(self, value):
        if value <= 0:
            raise serializers.ValidationError('Price must be more than 0.')
        if value > 100000:
            raise serializers.ValidationError('Please check the price.')
        return value

    validate_morning_price = validate_day_price = validate_evening_price = _price

    def validate_latitude(self, value):
        if not -90 <= value <= 90:
            raise serializers.ValidationError('Please pick the location on the map.')
        return value

    def validate_longitude(self, value):
        if not -180 <= value <= 180:
            raise serializers.ValidationError('Please pick the location on the map.')
        return value

    def validate_image_url(self, value):
        """Only a photo the owner uploaded to their own folder (or "")."""
        if not value:
            return ''
        owner_id = self.context['request'].user.pk
        own_folder = f'{settings.SUPABASE_URL}/storage/v1/object/public/ground-photos/{owner_id}/'
        if not value.startswith(own_folder) or '..' in value:
            raise serializers.ValidationError('Please upload the photo from the app.')
        return value

    def validate_ownership_document(self, value):
        """A file the owner uploaded to their own folder of the private
        ground-documents bucket, e.g. "<owner id>/photo-123.jpg"."""
        owner_id = self.context['request'].user.pk
        if not re.fullmatch(rf'{owner_id}/[\w-]+\.(jpg|jpeg|png|webp)', value):
            raise serializers.ValidationError('Please upload the lalpurja photo from the app.')
        return value

    def validate(self, attrs):
        opens_at = attrs.get('opens_at', getattr(self.instance, 'opens_at', None))
        closes_at = attrs.get('closes_at', getattr(self.instance, 'closes_at', None))
        if opens_at and closes_at and closes_at <= opens_at:
            raise serializers.ValidationError({'closes_at': 'Closing time must be after opening time.'})
        if self.instance is None and not attrs.get('ownership_document'):
            raise serializers.ValidationError(
                {'ownership_document': 'Please add a photo of the lalpurja so we can check the ground is yours.'})
        return attrs

    def create(self, validated_data):
        ground = super().create(validated_data)
        notify.ground_submitted(ground)
        return ground

    def update(self, ground, validated_data):
        """Changing what the admin checked sends the ground back for approval,
        and so does saving a rejected ground (the owner fixed it)."""
        changed = any(field in validated_data and validated_data[field] != getattr(ground, field)
                      for field in REVIEWED_FIELDS)
        fixed = ground.status == Ground.Status.REJECTED and bool(set(validated_data) - {'is_active'})
        resubmit = (changed and ground.status == Ground.Status.APPROVED) or fixed
        if resubmit:
            validated_data.update(status=Ground.Status.PENDING, review_note='', reviewed_at=None)
        ground = super().update(ground, validated_data)
        if resubmit:
            notify.ground_submitted(ground, resubmitted=True)
        return ground


class AdminGroundSerializer(serializers.ModelSerializer):
    """A ground as an admin reviews it: everything, plus who owns it and a
    short-lived link to the lalpurja photo (detail view only)."""

    owner_name = serializers.CharField(source='owner.full_name', read_only=True)
    owner_phone = serializers.CharField(source='owner.mobile_number', read_only=True)
    owner_email = serializers.CharField(source='owner.email', read_only=True)
    owner_address = serializers.SerializerMethodField()
    document_url = serializers.SerializerMethodField()

    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'area', 'address', 'latitude', 'longitude', 'morning_price', 'day_price',
            'evening_price', 'image_url', 'badge_label', 'opens_at', 'closes_at', 'is_active',
            'status', 'review_note', 'reviewed_at', 'created_at',
            'owner_name', 'owner_phone', 'owner_email', 'owner_address', 'document_url',
        ]
        read_only_fields = fields

    def get_owner_address(self, ground):
        return ', '.join(part for part in (ground.owner.address, ground.owner.city) if part)

    def get_document_url(self, ground):
        if not self.context.get('with_document'):
            return None
        return signed_document_url(ground.ownership_document)


class EventSerializer(serializers.ModelSerializer):
    """An event as everyone sees it, plus whether it's the viewer's own."""

    ground_name = serializers.CharField(source='ground.name', read_only=True)
    ground_area = serializers.CharField(source='ground.area', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = [
            'id', 'ground', 'ground_name', 'ground_area', 'title', 'description', 'starts_at', 'ends_at',
            'image_url', 'is_published', 'is_expired', 'is_mine', 'created_at',
        ]
        read_only_fields = fields

    def get_is_mine(self, event):
        return event.owner_id == self.context['request'].user.pk


class OwnerEventSerializer(EventSerializer):
    """An owner's own event: they can write everything except who owns it."""

    class Meta(EventSerializer.Meta):
        read_only_fields = ['id', 'ground_name', 'ground_area', 'is_expired', 'is_mine', 'created_at']

    def validate_ground(self, ground):
        if ground.owner_id != self.context['request'].user.pk:
            raise serializers.ValidationError('Pick one of your own grounds.')
        return ground

    def validate_title(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Please enter the event's name.")
        return value

    def validate_description(self, value):
        value = value.strip()
        if len(value) > 2000:
            raise serializers.ValidationError('Please keep the description under 2000 characters.')
        return value

    def validate_image_url(self, value):
        """Only a poster the owner uploaded to their own folder (or "")."""
        if not value:
            return ''
        owner_id = self.context['request'].user.pk
        own_folder = f'{settings.SUPABASE_URL}/storage/v1/object/public/ground-photos/{owner_id}/'
        if not value.startswith(own_folder) or '..' in value:
            raise serializers.ValidationError('Please upload the poster from the app.')
        return value

    def validate(self, attrs):
        starts_at = attrs.get('starts_at', getattr(self.instance, 'starts_at', None))
        ends_at = attrs.get('ends_at', getattr(self.instance, 'ends_at', None))
        if 'starts_at' in attrs and starts_at <= timezone.now():
            raise serializers.ValidationError({'starts_at': 'Pick a date and time in the future.'})
        if ends_at and starts_at and ends_at <= starts_at:
            raise serializers.ValidationError({'ends_at': 'The end must be after the start.'})
        return attrs

    def save(self, **kwargs):
        first_publish = bool(self.validated_data.get('is_published')) and not (
            self.instance and self.instance.published_at)
        if first_publish:
            kwargs['published_at'] = timezone.now()
        event = super().save(**kwargs)
        if first_publish:
            notify.event_published(event)
        return event
