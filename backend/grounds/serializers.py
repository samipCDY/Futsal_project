from rest_framework import serializers

from .models import Ground


class GroundSerializer(serializers.ModelSerializer):
    # Filled in by GroundViewSet.get_queryset for the signed-in user.
    is_favourite = serializers.BooleanField(read_only=True, default=False)

    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'area', 'address', 'latitude', 'longitude',
            'price_per_hour', 'image_url', 'badge_label', 'opens_at', 'closes_at', 'is_favourite',
        ]
