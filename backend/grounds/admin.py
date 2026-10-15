from django.contrib import admin

from .models import Ground


@admin.register(Ground)
class GroundAdmin(admin.ModelAdmin):
    list_display = ('name', 'area', 'owner', 'price_per_hour', 'opens_at', 'closes_at', 'is_active')
    list_filter = ('is_active', 'area')
    search_fields = ('name', 'area', 'address')
    autocomplete_fields = ('owner',)
