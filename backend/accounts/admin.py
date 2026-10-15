from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

from .models import Profile, User


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    """App users from Supabase. Editing `role` here is how someone becomes a
    ground owner or admin. New profiles are created by Supabase on sign-up."""

    list_display = ('full_name', 'email', 'mobile_number', 'role', 'created_at')
    list_filter = ('role',)
    search_fields = ('full_name', 'email', 'mobile_number')
    fields = ('id', 'email', 'full_name', 'mobile_number', 'role', 'created_at')
    readonly_fields = ('id', 'email', 'created_at')

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
