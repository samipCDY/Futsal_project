from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.db import models


class Role(models.TextChoices):
    CUSTOMER = 'customer', 'Customer'
    GROUND_OWNER = 'ground_owner', 'Ground Owner'
    ADMIN = 'admin', 'Admin'


class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Users must have an email address')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', Role.ADMIN)
        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """Login for the Django admin panel only (`createsuperuser`). App users
    sign in through Supabase and are represented by `Profile` instead."""

    Role = Role

    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=150, blank=True)
    mobile_number = models.CharField(max_length=20, blank=True)
    role = models.CharField(max_length=20, choices=Role.choices)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    objects = UserManager()

    class Meta:
        verbose_name = 'admin login'

    def __str__(self):
        return self.email


class Profile(models.Model):
    """An app user, read straight from Supabase's `public.profiles` table
    (created by the trigger in supabase/migrations). Django never creates or
    migrates this table — Supabase owns it.

    `SupabaseJWTAuthentication` sets `request.user` to one of these, so the
    two flags below let DRF treat it like a logged-in user.
    """

    is_authenticated = True
    is_anonymous = False

    class Gender(models.TextChoices):
        MALE = 'male', 'Male'
        FEMALE = 'female', 'Female'
        OTHER = 'other', 'Other'

    id = models.UUIDField(primary_key=True)
    email = models.TextField(blank=True)
    first_name = models.TextField(blank=True)
    last_name = models.TextField(blank=True)
    full_name = models.TextField(blank=True, help_text='Kept as "first last" for screens that show one name.')
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.TextField(choices=Gender.choices, null=True, blank=True)
    mobile_number = models.TextField(blank=True)
    address = models.TextField(blank=True)
    city = models.TextField(blank=True)
    avatar_url = models.TextField(blank=True, help_text='Public URL of the profile photo in the "avatars" bucket.')
    role = models.TextField(choices=Role.choices, default=Role.CUSTOMER)
    created_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'profiles'
        verbose_name = 'app user (customer / owner)'

    def __str__(self):
        return self.full_name or str(self.id)


class Preferences(models.Model):
    """Settings each user picks on the app's Profile page."""

    class Theme(models.TextChoices):
        SYSTEM = 'system', 'Same as phone'
        LIGHT = 'light', 'Light'
        DARK = 'dark', 'Dark'

    class Language(models.TextChoices):
        ENGLISH = 'en', 'English'
        NEPALI = 'ne', 'नेपाली'

    # See Ground.owner for why there's no database-level foreign key.
    profile = models.OneToOneField(
        Profile, on_delete=models.DO_NOTHING, db_constraint=False, primary_key=True, related_name='preferences')
    theme = models.CharField(max_length=6, choices=Theme.choices, default=Theme.SYSTEM)
    language = models.CharField(max_length=2, choices=Language.choices, default=Language.ENGLISH)
    notifications_enabled = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = 'preferences'

    def __str__(self):
        return f'Preferences of {self.profile_id}'
