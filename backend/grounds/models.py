from datetime import datetime, time

from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from accounts.models import Profile, Role

from . import notify

# Each ground has three hourly rates. A slot's rate is set by its start time.
DAY_STARTS = time(10)  # morning rate before this
EVENING_STARTS = time(16)  # evening (peak) rate from this


def slot_has_started(day, start):
    """Whether a slot on `day` at `start` (Nepal time) is already underway."""
    return datetime.combine(day, start) <= timezone.localtime().replace(tzinfo=None)


class GroundQuerySet(models.QuerySet):
    def visible(self):
        """Grounds customers can find and book: approved and not hidden."""
        return self.filter(is_active=True, status=Ground.Status.APPROVED)


class Ground(models.Model):
    """A futsal ground listed by a ground owner, booked in 1-hour slots that
    start on the hour between `opens_at` and `closes_at`. New grounds wait for
    an admin to check the ownership document before customers see them."""

    class Status(models.TextChoices):
        PENDING = 'pending', 'Waiting for approval'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'

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
    morning_price = models.DecimalField(max_digits=8, decimal_places=2, help_text='Per hour, before 10 AM.')
    day_price = models.DecimalField(max_digits=8, decimal_places=2, help_text='Per hour, 10 AM – 4 PM.')
    evening_price = models.DecimalField(max_digits=8, decimal_places=2,
                                        help_text='Per hour, from 4 PM (peak time).')
    image_url = models.URLField(blank=True)
    badge_label = models.CharField(max_length=60, blank=True, help_text='Short perk, e.g. "Free bibs + water".')
    opens_at = models.TimeField(default=time(6))
    closes_at = models.TimeField(default=time(22))
    is_active = models.BooleanField(default=True, help_text='Untick to hide the ground from customers.')
    ownership_document = models.CharField(
        max_length=255, blank=True,
        help_text='Photo of the lalpurja (land ownership) or lease paper, in the private '
                  '"ground-documents" storage bucket.',
    )
    status = models.CharField(max_length=8, choices=Status.choices, default=Status.PENDING)
    review_note = models.CharField(max_length=255, blank=True,
                                   help_text='Why it was rejected. The owner sees this in the app.')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = GroundQuerySet.as_manager()

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

    def clean(self):
        if self.closes_at <= self.opens_at:
            raise ValidationError({'closes_at': 'Closing time must be after opening time.'})
        if self.status == self.Status.REJECTED and not self.review_note.strip():
            raise ValidationError({'review_note': 'Tell the owner why, so they can fix it.'})

    def slot_starts(self):
        """Start times of every bookable 1-hour slot in a day."""
        first = self.opens_at.hour + (1 if self.opens_at.minute or self.opens_at.second else 0)
        return [time(hour) for hour in range(first, self.closes_at.hour)]

    def review(self, status, note=''):
        """An admin's decision on the ground. The owner is told by email."""
        self.status = status
        self.review_note = note.strip() if status == self.Status.REJECTED else ''
        self.reviewed_at = timezone.now()
        self.save(update_fields=['status', 'review_note', 'reviewed_at'])
        notify.ground_reviewed(self)

    def price_at(self, start):
        """The hourly rate for a slot starting at `start`."""
        if start < DAY_STARTS:
            return self.morning_price
        if start >= EVENING_STARTS:
            return self.evening_price
        return self.day_price


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
