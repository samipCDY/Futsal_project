from rest_framework import serializers

from .models import Ground


class GroundSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'area', 'address', 'latitude', 'longitude',
            'price_per_hour', 'image_url', 'badge_label', 'opens_at', 'closes_at',
        ]
