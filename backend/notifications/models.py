from django.db import models

from accounts.models import Profile


class Notification(models.Model):
    """A message shown under the bell in the app, e.g. "Booking confirmed"."""

    class Kind(models.TextChoices):
        BOOKING = 'booking', 'Booking'
        CANCELLATION = 'cancellation', 'Cancellation and refund'
        MAINTENANCE = 'maintenance', 'Ground maintenance'
        EVENT = 'event', 'Event'
        GROUND = 'ground', 'Ground approval'
        ANNOUNCEMENT = 'announcement', 'Message from a ground or the admin'

    # See Ground.owner for why there's no database-level foreign key.
    recipient = models.ForeignKey(Profile, on_delete=models.DO_NOTHING, db_constraint=False,
                                  related_name='notifications')
    kind = models.CharField(max_length=12, choices=Kind.choices)
    title = models.CharField(max_length=150)
    body = models.TextField(blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at', '-id']

    def __str__(self):
        return f'{self.recipient} · {self.title}'


def notify_many(recipient_ids, kind, title, body=''):
    """The same message to many people at once. Returns how many."""
    recipient_ids = set(recipient_ids)
    Notification.objects.bulk_create(
        Notification(recipient_id=recipient_id, kind=kind, title=title, body=body) for recipient_id in recipient_ids)
    return len(recipient_ids)


def notify(recipient, kind, title, body=''):
    """Puts a message under `recipient`'s bell. Takes a Profile or its id."""
    recipient_id = getattr(recipient, 'pk', recipient)
    return Notification.objects.create(recipient_id=recipient_id, kind=kind, title=title, body=body)
