from django.contrib import admin
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from bookings.views import AdminRefundViewSet, BookingViewSet, owner_summary, payment_methods
from grounds.views import (AdminGroundViewSet, EventViewSet, GroundViewSet, OwnerEventViewSet, OwnerGroundViewSet,
                           OwnerMaintenanceViewSet, admin_summary)
from notifications.views import admin_announcement, mark_all_read, notification_list, owner_announcement

router = DefaultRouter()
router.register('grounds', GroundViewSet, basename='ground')
router.register('bookings', BookingViewSet, basename='booking')
router.register('owner/grounds', OwnerGroundViewSet, basename='owner-ground')
router.register('admin/grounds', AdminGroundViewSet, basename='admin-ground')
router.register('owner/maintenance', OwnerMaintenanceViewSet, basename='owner-maintenance')
router.register('owner/events', OwnerEventViewSet, basename='owner-event')
router.register('events', EventViewSet, basename='event')
router.register('admin/refunds', AdminRefundViewSet, basename='admin-refund')

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/accounts/', include('accounts.urls')),
    path('api/owner/summary/', owner_summary, name='owner-summary'),
    path('api/admin/summary/', admin_summary, name='admin-summary'),
    path('api/notifications/', notification_list, name='notifications'),
    path('api/payments/methods/', payment_methods, name='payment-methods'),
    path('api/notifications/read/', mark_all_read, name='notifications-read'),
    path('api/owner/announcements/', owner_announcement, name='owner-announcement'),
    path('api/admin/announcements/', admin_announcement, name='admin-announcement'),
    path('api/', include(router.urls)),
]
