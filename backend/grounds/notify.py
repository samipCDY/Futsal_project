"""Emails about ground approval. Sent after the database change is saved,
and a failed email never undoes or blocks the change."""

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction

from accounts.models import User


def _send_later(subject, message, recipients):
    recipients = [email for email in recipients if email]
    if recipients:
        transaction.on_commit(lambda: send_mail(subject, message, None, recipients, fail_silently=True))


def ground_submitted(ground, resubmitted=False):
    """Tell the admins a ground is waiting for them to check it."""
    owner = ground.owner
    what = 'was changed and needs checking again' if resubmitted else 'is waiting for approval'
    _send_later(
        f'Ground to approve: {ground.name}',
        f'"{ground.name}" ({ground.area}) {what}.\n\n'
        f'Owner: {owner.full_name or "-"}\n'
        f'Email: {owner.email or "-"}\n'
        f'Phone: {owner.mobile_number or "-"}\n\n'
        f'Check the lalpurja photo and approve or reject it here:\n'
        f'{settings.BACKEND_URL}/admin/grounds/ground/{ground.pk}/change/\n',
        settings.ADMIN_NOTIFY_EMAILS
        or User.objects.filter(is_active=True, is_staff=True).values_list('email', flat=True),
    )


def ground_reviewed(ground):
    """Tell the owner whether their ground was approved."""
    if ground.status == ground.Status.APPROVED:
        subject = f'{ground.name} is approved'
        body = (f'Good news! "{ground.name}" has been approved and customers can now find and book it '
                f'in Futsal Finder.\n')
    else:
        subject = f'{ground.name} was not approved'
        body = (f'"{ground.name}" was not approved.\n\nReason: {ground.review_note}\n\n'
                f'Please fix this in the app (My Grounds → Edit) and save. It will be checked again.\n')
    _send_later(subject, body, [ground.owner.email])
