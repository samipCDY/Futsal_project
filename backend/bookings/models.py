import secrets
import string
from datetime import datetime, timedelta
from decimal import Decimal

from django.db import IntegrityError, models, transaction
from django.db.models import Q
from django.utils import timezone

from accounts.models import Profile
from grounds.models import Ground
from notifications.models import Notification, notify

# Cancellation and refund rules (also shown in the app under Profile ->
# Rules & regulations). A customer who cancels within FREE_CANCEL_HOURS of
# booking gets everything back; later, LATE_REFUND_PERCENT, and the owner
# keeps the rest. When the owner cancels (or closes the ground for
# maintenance) the customer always gets everything back.
FREE_CANCEL_HOURS = 2
LATE_REFUND_PERCENT = 50

# An eSewa/Khalti booking holds its slot this long while the customer pays;
# after that it's released for others (see release_unpaid_slots).
PAYMENT_WINDOW = timedelta(minutes=15)
UNPAID_REASON = 'Payment was not completed in time.'


def generate_booking_ref():
    alphabet = string.ascii_uppercase + string.digits
    return 'FF-' + ''.join(secrets.choice(alphabet) for _ in range(8))


def _rupees(amount):
    return f'Rs {amount:,.0f}'


def _clock(value):
    """6:00 PM"""
    return value.strftime('%I:%M %p').lstrip('0')


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

    class CancelledBy(models.TextChoices):
        CUSTOMER = 'customer', 'Customer'
        OWNER = 'owner', 'Ground owner'

    class PaymentStatus(models.TextChoices):
        UNPAID = 'unpaid', 'Not paid yet'  # cash bookings stay here; they pay at the ground
        PAID = 'paid', 'Paid online'

    class RefundStatus(models.TextChoices):
        NONE = '', 'No refund to send'
        PENDING = 'pending', 'Refund to send'
        DONE = 'done', 'Refund sent'

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
    cancelled_by = models.CharField(max_length=10, choices=CancelledBy.choices, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancel_reason = models.CharField(max_length=255, blank=True)
    refund_amount = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True,
                                        help_text='What the customer gets back; the owner keeps the rest.')
    payment_status = models.CharField(max_length=6, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID)
    payment_token = models.CharField(max_length=64, blank=True,
                                     help_text="This payment attempt's eSewa transaction_uuid or Khalti pidx.")
    payment_txn_id = models.CharField(max_length=64, blank=True, help_text="eSewa's or Khalti's transaction id.")
    paid_at = models.DateTimeField(null=True, blank=True)
    refund_status = models.CharField(max_length=7, choices=RefundStatus.choices, blank=True, default='',
                                     help_text='Online refunds are sent back by an admin.')
    refunded_at = models.DateTimeField(null=True, blank=True)

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

    @property
    def is_online(self):
        return self.payment_method != self.PaymentMethod.CASH

    @property
    def is_paid(self):
        return self.payment_status == self.PaymentStatus.PAID

    @property
    def payment_due_by(self):
        """When an unpaid online booking gives its slot back."""
        if not self.is_online or self.is_paid or self.status != self.Status.PENDING:
            return None
        return self.created_at + PAYMENT_WINDOW

    @property
    def free_cancel_until(self):
        return self.created_at + timedelta(hours=FREE_CANCEL_HOURS)

    def customer_refund(self, at=None):
        """What the customer gets back if they cancel at `at` (default now)."""
        if (at or timezone.now()) <= self.free_cancel_until:
            return self.price
        return (Decimal(self.price) * LATE_REFUND_PERCENT / 100).quantize(Decimal('0.01'))

    @property
    def owner_keeps(self):
        """What the owner earns from this booking. A cancelled booking earns
        only the part of an online payment that wasn't refunded."""
        if self.status != self.Status.CANCELLED:
            return self.price
        if not self.is_paid or self.refund_amount is None:
            return Decimal(0)
        return self.price - self.refund_amount

    def _slot_label(self):
        return f'{self.ground.name}, {self.date:%a} {self.date.day} {self.date:%b} at {_clock(self.start_time)}'

    def cancel(self, by, reason='', kind=Notification.Kind.CANCELLATION, title=None):
        """Cancels the booking. Only online payments are refunded (see the
        rules at the top); a cash booking hasn't been paid yet. Both the
        customer and the ground's owner are told. `title` replaces the
        customer's notification title, e.g. for maintenance."""
        if not self.is_paid:
            self.refund_amount = Decimal(0)  # nothing was paid, so nothing to give back
        else:
            self.refund_amount = self.price if by == self.CancelledBy.OWNER else self.customer_refund()
        self.refund_status = self.RefundStatus.PENDING if self.refund_amount else self.RefundStatus.NONE
        self.status = self.Status.CANCELLED
        self.cancelled_by = by
        self.cancelled_at = timezone.now()
        self.cancel_reason = reason.strip()[:255]
        self.save(update_fields=['status', 'cancelled_by', 'cancelled_at', 'cancel_reason', 'refund_amount',
                                 'refund_status'])

        slot = self._slot_label()
        if self.is_paid:
            share = 'full amount' if self.refund_amount == self.price else f'{LATE_REFUND_PERCENT}%'
            refund = (f'Refund: {_rupees(self.refund_amount)} ({share}), sent back to your '
                      f'{self.get_payment_method_display()} account.')
        else:
            refund = 'Nothing was paid, so there is nothing to refund.'

        if by == self.CancelledBy.OWNER:
            notify(self.customer_id, kind, title or 'Your booking was cancelled by the ground',
                   f'{slot}. {self.cancel_reason or "The ground had to cancel."} Your booking is cancelled. {refund}')
        elif self.is_online and not self.is_paid:
            # An abandoned online payment: only the customer needs to know.
            notify(self.customer_id, Notification.Kind.CANCELLATION, 'Booking cancelled', f'{slot}. {refund}')
        else:
            notify(self.customer_id, Notification.Kind.CANCELLATION, 'Booking cancelled', f'{slot}. {refund}')
            kept = f' You keep {_rupees(self.owner_keeps)}.' if self.is_paid else ''
            notify(self.ground.owner_id, Notification.Kind.CANCELLATION, 'A customer cancelled',
                   f'{self.customer.full_name or "A customer"} cancelled {slot}. {refund}{kept}')

    def notify_booked(self):
        slot = self._slot_label()
        free_until = _clock(timezone.localtime(self.free_cancel_until))
        paid = (f'paid with {self.get_payment_method_display()}' if self.is_paid else 'pay at the ground')
        notify(self.customer_id, Notification.Kind.BOOKING, 'Booking confirmed',
               f'{slot} · {_rupees(self.price)}, {paid}. Free cancellation until {free_until}, '
               f'after that {LATE_REFUND_PERCENT}% refund.')
        notify(self.ground.owner_id, Notification.Kind.BOOKING, 'New booking',
               f'{self.customer.full_name or "A customer"} booked {slot} · {_rupees(self.price)} ({paid}).')

    def mark_paid(self, txn_id):
        """Records a payment eSewa/Khalti confirmed. A booking whose hold ran
        out gets its slot back if nobody took it meanwhile; otherwise the
        customer is refunded in full."""
        self.payment_status = self.PaymentStatus.PAID
        self.payment_txn_id = txn_id[:64]
        self.paid_at = timezone.now()
        fields = ['payment_status', 'payment_txn_id', 'paid_at']
        if self.status == self.Status.PENDING:
            self.status = self.Status.CONFIRMED
            self.save(update_fields=fields + ['status'])
            self.notify_booked()
            return
        if self.status == self.Status.CANCELLED and self.cancel_reason == UNPAID_REASON:
            try:
                with transaction.atomic():
                    Booking.objects.filter(pk=self.pk).update(
                        status=self.Status.CONFIRMED, cancelled_by='', cancelled_at=None, cancel_reason='',
                        refund_amount=None, **{field: getattr(self, field) for field in fields})
            except IntegrityError:
                # Someone else booked the slot after the hold ran out.
                self.refund_amount = self.price
                self.refund_status = self.RefundStatus.PENDING
                self.save(update_fields=fields + ['refund_amount', 'refund_status'])
                notify(self.customer_id, Notification.Kind.CANCELLATION, 'Payment received too late',
                       f'{self._slot_label()} was taken while the payment was pending. Your '
                       f'{_rupees(self.price)} will be sent back to your {self.get_payment_method_display()} '
                       f'account.')
                return
            self.refresh_from_db()
            self.notify_booked()
            return
        if self.status == self.Status.CANCELLED:
            # Cancelled before the payment went through: give all of it back.
            self.refund_amount = self.price
            self.refund_status = self.RefundStatus.PENDING
            self.save(update_fields=fields + ['refund_amount', 'refund_status'])
            notify(self.customer_id, Notification.Kind.CANCELLATION, 'Payment for a cancelled booking',
                   f'{self._slot_label()} was already cancelled. Your {_rupees(self.price)} will be sent back to '
                   f'your {self.get_payment_method_display()} account.')
            return
        self.save(update_fields=fields)

    def mark_refunded(self):
        self.refund_status = self.RefundStatus.DONE
        self.refunded_at = timezone.now()
        self.save(update_fields=['refund_status', 'refunded_at'])
        notify(self.customer_id, Notification.Kind.CANCELLATION, 'Refund sent',
               f'{_rupees(self.refund_amount)} for {self._slot_label()} was sent back to your '
               f'{self.get_payment_method_display()} account.')


def release_unpaid_slots():
    """Gives back the slots of online bookings whose payment window ran out."""
    Booking.objects.filter(
        status=Booking.Status.PENDING,
        payment_status=Booking.PaymentStatus.UNPAID,
        created_at__lt=timezone.now() - PAYMENT_WINDOW,
    ).exclude(payment_method=Booking.PaymentMethod.CASH).update(
        status=Booking.Status.CANCELLED,
        cancelled_by=Booking.CancelledBy.CUSTOMER,
        cancelled_at=timezone.now(),
        cancel_reason=UNPAID_REASON,
        refund_amount=Decimal(0),
    )
