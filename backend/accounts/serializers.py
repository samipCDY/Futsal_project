import re
from datetime import date

from django.conf import settings
from rest_framework import serializers

from .models import Preferences, Profile

MAX_AGE_YEARS = 100


class PreferencesSerializer(serializers.ModelSerializer):
    class Meta:
        model = Preferences
        fields = ['theme', 'language', 'notifications_enabled']


class MeSerializer(serializers.ModelSerializer):
    """The signed-in user's own profile. Email and role can't be changed
    here: email belongs to Supabase login, and role is set by an admin.
    full_name follows first_name + last_name automatically."""

    preferences = PreferencesSerializer(required=False)

    class Meta:
        model = Profile
        fields = [
            'id', 'email', 'first_name', 'last_name', 'full_name', 'date_of_birth', 'gender',
            'mobile_number', 'address', 'city', 'avatar_url', 'role', 'preferences',
        ]
        read_only_fields = ['id', 'email', 'full_name', 'role']

    def validate_first_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Please enter your first name.')
        if len(value) > 50:
            raise serializers.ValidationError('First name is too long.')
        return value

    def validate_last_name(self, value):
        value = value.strip()
        if len(value) > 50:
            raise serializers.ValidationError('Last name is too long.')
        return value

    def validate_date_of_birth(self, value):
        if value is None:
            return value
        today = date.today()
        if value >= today:
            raise serializers.ValidationError('Date of birth must be in the past.')
        if value.year < today.year - MAX_AGE_YEARS:
            raise serializers.ValidationError('Please check your date of birth.')
        return value

    def validate_gender(self, value):
        return value or None  # "" means "prefer not to say"

    def validate_mobile_number(self, value):
        value = value.replace(' ', '').replace('-', '')
        if not value:
            raise serializers.ValidationError('Please enter your mobile number.')
        if not re.fullmatch(r'\d{10}', value):
            raise serializers.ValidationError('Mobile number must be exactly 10 digits.')
        return value

    def validate_address(self, value):
        value = value.strip()
        if len(value) > 200:
            raise serializers.ValidationError('Address is too long.')
        return value

    def validate_city(self, value):
        value = value.strip()
        if len(value) > 60:
            raise serializers.ValidationError('City is too long.')
        return value

    def validate_avatar_url(self, value):
        """Only a photo the user uploaded to their own folder in the avatars
        bucket (or "" to remove the photo) — never an arbitrary link."""
        if not value:
            return ''
        own_folder = f'{settings.SUPABASE_URL}/storage/v1/object/public/avatars/{self.instance.id}/'
        if not value.startswith(own_folder) or '..' in value:
            raise serializers.ValidationError('Please upload the photo from the app.')
        return value

    def update(self, profile, validated_data):
        preferences_data = validated_data.pop('preferences', None)

        changed = list(validated_data)
        for field, value in validated_data.items():
            setattr(profile, field, value)
        if 'first_name' in changed or 'last_name' in changed:
            profile.full_name = f'{profile.first_name} {profile.last_name}'.strip()
            changed.append('full_name')
        if changed:
            profile.save(update_fields=changed)

        if preferences_data:
            preferences = profile.preferences
            for field, value in preferences_data.items():
                setattr(preferences, field, value)
            preferences.save()
        return profile
