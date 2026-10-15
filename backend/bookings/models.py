import secrets
import string
from datetime import datetime, timedelta

from django.db import models
from django.db.models import Q

from accounts.models import Profile
from grounds.models import Ground


def generate_booking_ref():
    alphabet = string.ascii_uppercase + string.digits
    return 'FF-' + ''.join(secrets.choice(alphabet) for _ in range(8))


class Booking(models.Model):
    """One customer's booking of one 1-hour slot at a ground."""

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'  # reserved for online payments later
        CONFIRMED = 'confirmed', 'Confirmed'
        CANCELLED = 'cancelled', 'Cancelled'
        COMPLETED = 'completed', 'Completed'

    class PaymentMethod(models.TextChoices):
        CASH = 'cash', 'Cash at ground'
        ESEWA = 'esewa', 'eSewa'
        KHALTI = 'khalti', 'Khalti'

    booking_ref = models.CharField(max_length=12, unique=True, default=generate_booking_ref, editable=False)
    ground = models.ForeignKey(Ground, on_delete=models.PROTECT, related_name='bookings')
    # See Ground.owner for why there's no database-level foreign key.
    customer = models.ForeignKey(Profile, on_delete=models.DO_NOTHING, db_constraint=False, related_name='bookings')
    date = models.DateField()
    start_time = models.TimeField(help_text='Always on the hour; the slot lasts one hour.')
    price = models.DecimalField(max_digits=8, decimal_places=2, help_text="The ground's hourly price when booked.")
    payment_method = models.CharField(max_length=10, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.CONFIRMED)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date', '-start_time']
        constraints = [
            # The database itself refuses a second live booking of a slot, so
            # two people tapping "Book" at the same moment can't both win.
            models.UniqueConstraint(
                fields=['ground', 'date', 'start_time'],
                condition=~Q(status='cancelled'),
                name='one_active_booking_per_slot',
            ),
        ]

    def __str__(self):
        return f'{self.booking_ref} · {self.ground} · {self.date} {self.start_time:%H:%M}'

    @property
    def end_time(self):
        return (datetime.combine(self.date, self.start_time) + timedelta(hours=1)).time()
