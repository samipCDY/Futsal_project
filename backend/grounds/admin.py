from django.contrib import admin, messages
from django.utils import timezone
from django.utils.html import format_html

from . import notify
from .models import Event, Favourite, Ground, Maintenance
from .storage import signed_document_url


@admin.register(Ground)
class GroundAdmin(admin.ModelAdmin):
    """New grounds arrive "Waiting for approval". Open one, check the lalpurja
    photo matches the owner, then set Status to Approved, or to Rejected with
    a note telling the owner what to fix."""

    list_display = ('name', 'area', 'owner', 'status_badge', 'is_active', 'created_at')
    list_filter = ('status', 'is_active', 'area')
    search_fields = ('name', 'area', 'address', 'owner__full_name', 'owner__email')
    autocomplete_fields = ('owner',)
    readonly_fields = ('owner_details', 'map_link', 'lalpurja', 'reviewed_at', 'created_at')
    actions = ('approve',)
    fieldsets = (
        ('Approval', {'fields': ('owner_details', 'map_link', 'lalpurja', 'status', 'review_note', 'reviewed_at')}),
        ('Ground', {'fields': (
            'owner', 'name', 'area', 'address', ('latitude', 'longitude'), 'image_url', 'badge_label',
            ('opens_at', 'closes_at'), 'is_active', 'created_at',
        )}),
        ('Hourly rates (Rs)', {'fields': (('morning_price', 'day_price', 'evening_price'),)}),
        ('Document file', {'fields': ('ownership_document',), 'classes': ('collapse',)}),
    )

    @admin.display(description='Status', ordering='status')
    def status_badge(self, ground):
        colours = {Ground.Status.PENDING: '#b7791f', Ground.Status.APPROVED: '#2f855a',
                   Ground.Status.REJECTED: '#c53030'}
        return format_html('<b style="color:{}">{}</b>', colours[ground.status], ground.get_status_display())

    @admin.display(description='Owner')
    def owner_details(self, ground):
        """Who to compare with the name on the lalpurja."""
        owner = ground.owner
        return format_html('<b>{}</b><br>Phone: {}<br>Email: {}<br>Address: {}',
                           owner.full_name or '-', owner.mobile_number or '-', owner.email or '-',
                           ', '.join(part for part in (owner.address, owner.city) if part) or '-')

    @admin.display(description='Location')
    def map_link(self, ground):
        return format_html('<a href="https://www.google.com/maps?q={},{}" target="_blank">Open in Google Maps</a>'
                           '<br>{}', ground.latitude, ground.longitude, ground.address or ground.area)

    @admin.display(description='Lalpurja / ownership document')
    def lalpurja(self, ground):
        if not ground.ownership_document:
            return 'No document uploaded.'
        url = signed_document_url(ground.ownership_document)
        if url is None:
            return ("Can't show the photo. Put the Supabase secret key in backend/.env as "
                    "SUPABASE_SECRET_KEY and restart the server.")
        return format_html(
            '<a href="{0}" target="_blank"><img src="{0}" style="max-height:420px;max-width:100%;'
            'border:1px solid #ccc;border-radius:6px"></a><br>Click to open full size (link works for 10 minutes).',
            url,
        )

    def save_model(self, request, ground, form, change):
        reviewed = change and 'status' in form.changed_data and ground.status != Ground.Status.PENDING
        if reviewed:
            ground.reviewed_at = timezone.now()
        if ground.status != Ground.Status.REJECTED:
            ground.review_note = ''
        super().save_model(request, ground, form, change)
        if reviewed:
            notify.ground_reviewed(ground)

    @admin.action(description='Approve selected grounds')
    def approve(self, request, queryset):
        grounds = list(queryset.exclude(status=Ground.Status.APPROVED).select_related('owner'))
        for ground in grounds:
            ground.review(Ground.Status.APPROVED)
        self.message_user(request, f'{len(grounds)} ground(s) approved.', messages.SUCCESS)


@admin.register(Favourite)
class FavouriteAdmin(admin.ModelAdmin):
    list_display = ('customer', 'ground', 'created_at')
    raw_id_fields = ('customer', 'ground')


@admin.register(Maintenance)
class MaintenanceAdmin(admin.ModelAdmin):
    list_display = ('ground', 'starts_on', 'ends_on', 'reason')
    list_filter = ('starts_on',)
    raw_id_fields = ('ground',)


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ('title', 'ground', 'starts_at', 'is_published')
    list_filter = ('is_published',)
    search_fields = ('title', 'ground__name')
    raw_id_fields = ('owner', 'ground')
