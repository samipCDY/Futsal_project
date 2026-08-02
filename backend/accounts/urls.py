from django.urls import path

from . import views

urlpatterns = [
    path('otp/send/', views.send_otp, name='send-otp'),
    path('otp/verify/', views.verify_otp, name='verify-otp'),
    path('register/', views.register, name='register'),
    path('login/', views.login, name='login'),
    path('reset-password/', views.reset_password, name='reset-password'),
]
