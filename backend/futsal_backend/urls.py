from django.contrib import admin
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from bookings.views import BookingViewSet
from grounds.views import GroundViewSet

router = DefaultRouter()
router.register('grounds', GroundViewSet, basename='ground')
router.register('bookings', BookingViewSet, basename='booking')

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/accounts/', include('accounts.urls')),
    path('api/', include(router.urls)),
]
