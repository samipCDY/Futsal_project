from django.apps import AppConfig
from django.db.backends.signals import connection_created


def use_django_schema(sender, connection, **kwargs):
    """On Supabase Postgres, keep Django's tables in their own `django`
    schema. Supabase's public API exposes everything in `public` to anyone
    with the app's key, so Django's tables (admin logins, sessions, bookings)
    must not live there. `public` stays on the path so `profiles` resolves."""
    if connection.vendor != 'postgresql':
        return
    with connection.cursor() as cursor:
        cursor.execute('CREATE SCHEMA IF NOT EXISTS django')
        cursor.execute('SET search_path TO django, public')


class AccountsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'accounts'

    def ready(self):
        connection_created.connect(use_django_schema)
