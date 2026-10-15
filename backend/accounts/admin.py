from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.utils.html import format_html

from .models import Preferences, Profile, User


class PreferencesInline(admin.StackedInline):
    model = Preferences
    can_delete = False


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    """App users from Supabase. Editing `role` here is how someone becomes a
    ground owner or admin. New profiles are created by Supabase on sign-up."""

    inlines = [PreferencesInline]

    list_display = ('full_name', 'email', 'mobile_number', 'city', 'role', 'created_at')
    list_filter = ('role', 'gender', 'city')
    search_fields = ('full_name', 'email', 'mobile_number', 'city')
    fieldsets = (
        (None, {'fields': ('id', 'email', 'role', 'created_at')}),
        ('Personal details', {'fields': (
            'photo', ('first_name', 'last_name'), 'full_name', 'date_of_birth', 'gender',
            'mobile_number', 'address', 'city',
        )}),
    )
    readonly_fields = ('id', 'email', 'full_name', 'created_at', 'photo')

    @admin.display(description='Photo')
    def photo(self, obj):
        if not obj.avatar_url:
            return 'No photo'
        return format_html('<img src="{}" style="height:96px;width:96px;border-radius:50%;object-fit:cover">',
                           obj.avatar_url)

    def save_model(self, request, obj, form, change):
        obj.full_name = f'{obj.first_name} {obj.last_name}'.strip()
        obj.gender = obj.gender or None  # the database only accepts the three choices or empty
        super().save_model(request, obj, form, change)

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    """Admin panel logins only. App customers and owners are under Profiles."""

    ordering = ('email',)
    list_display = ('email', 'full_name', 'is_superuser', 'is_active', 'date_joined')
    list_filter = ('is_superuser', 'is_active')
    search_fields = ('email', 'full_name')
    fieldsets = (
        (None, {'fields': ('email', 'password', 'full_name')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'password1', 'password2', 'is_staff', 'is_superuser'),
        }),
    )
