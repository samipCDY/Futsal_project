from django.contrib import admin

from .models import Booking


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ('booking_ref', 'ground', 'customer', 'date', 'start_time', 'price', 'payment_method', 'status')
    list_filter = ('status', 'payment_method', 'date')
    search_fields = ('booking_ref', 'ground__name')
    raw_id_fields = ('ground', 'customer')
    readonly_fields = ('booking_ref', 'created_at')
