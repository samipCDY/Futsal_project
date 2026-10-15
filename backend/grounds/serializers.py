import re

from django.conf import settings
from rest_framework import serializers

from . import notify
from .models import Ground

# An admin checks these again when the owner changes them.
REVIEWED_FIELDS = ('name', 'area', 'address', 'latitude', 'longitude', 'ownership_document')


class GroundSerializer(serializers.ModelSerializer):
    # Filled in by GroundViewSet.get_queryset for the signed-in user.
    is_favourite = serializers.BooleanField(read_only=True, default=False)

    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'area', 'address', 'latitude', 'longitude', 'morning_price', 'day_price',
            'evening_price', 'image_url', 'badge_label', 'opens_at', 'closes_at', 'is_favourite',
        ]


class OwnerGroundSerializer(serializers.ModelSerializer):
    """A ground as its owner manages it. The owner is always the signed-in
    user, and only an admin can approve it."""

    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'area', 'address', 'latitude', 'longitude', 'morning_price', 'day_price',
            'evening_price', 'image_url', 'badge_label', 'opens_at', 'closes_at', 'is_active',
            'ownership_document', 'status', 'review_note', 'created_at',
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
