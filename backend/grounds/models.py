from datetime import datetime, time

from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from accounts.models import Profile, Role


def slot_has_started(day, start):
    """Whether a slot on `day` at `start` (Nepal time) is already underway."""
    return datetime.combine(day, start) <= timezone.localtime().replace(tzinfo=None)


class Ground(models.Model):
    """A futsal ground listed by a ground owner, booked in 1-hour slots that
    start on the hour between `opens_at` and `closes_at`."""

    # Profiles live in Supabase, so no database-level foreign key: Supabase
    # must stay free to delete its users without Django blocking it.
    owner = models.ForeignKey(
        Profile,
        on_delete=models.DO_NOTHING,
        db_constraint=False,
        related_name='grounds',
        limit_choices_to={'role': Role.GROUND_OWNER},
    )
    name = models.CharField(max_length=150)
    area = models.CharField(max_length=100, help_text='Neighbourhood shown on cards, e.g. "Baneshwor".')
    address = models.CharField(max_length=255, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    price_per_hour = models.DecimalField(max_digits=8, decimal_places=2)
    image_url = models.URLField(blank=True)
    badge_label = models.CharField(max_length=60, blank=True, help_text='Short perk, e.g. "Free bibs + water".')
    opens_at = models.TimeField(default=time(6))
    closes_at = models.TimeField(default=time(22))
    is_active = models.BooleanField(default=True, help_text='Untick to hide the ground from customers.')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

    def clean(self):
        if self.closes_at <= self.opens_at:
            raise ValidationError({'closes_at': 'Closing time must be after opening time.'})

    def slot_starts(self):
        """Start times of every bookable 1-hour slot in a day."""
        first = self.opens_at.hour + (1 if self.opens_at.minute or self.opens_at.second else 0)
        return [time(hour) for hour in range(first, self.closes_at.hour)]


class Favourite(models.Model):
    """A ground a customer has saved with the heart button."""

    customer = models.ForeignKey(Profile, on_delete=models.DO_NOTHING, db_constraint=False, related_name='favourites')
    ground = models.ForeignKey(Ground, on_delete=models.CASCADE, related_name='favourited_by')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [models.UniqueConstraint(fields=['customer', 'ground'], name='favourite_once')]

    def __str__(self):
        return f'{self.customer} ♥ {self.ground}'
