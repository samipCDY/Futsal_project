from django.contrib import admin
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from bookings.views import BookingViewSet, owner_summary
from grounds.views import GroundViewSet, OwnerGroundViewSet

router = DefaultRouter()
router.register('grounds', GroundViewSet, basename='ground')
router.register('bookings', BookingViewSet, basename='booking')
router.register('owner/grounds', OwnerGroundViewSet, basename='owner-ground')

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/accounts/', include('accounts.urls')),
    path('api/owner/summary/', owner_summary, name='owner-summary'),
    path('api/', include(router.urls)),
]
