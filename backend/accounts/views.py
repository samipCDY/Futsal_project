from django.conf import settings
from django.contrib.auth import authenticate
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.core.validators import validate_email
from django.contrib.auth.password_validation import validate_password
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import EmailOTP, User, generate_code

SELF_SERVICE_ROLES = {User.Role.CUSTOMER, User.Role.GROUND_OWNER}


def _has_fresh_verified_otp(email):
    """A verified OTP only counts for register/reset if it's still within its
    original expiry window — otherwise a verification from days/weeks ago
    would stay usable forever, since `is_verified` alone never resets."""
    return EmailOTP.objects.filter(
        email=email, is_verified=True, expires_at__gt=timezone.now()
    ).exists()


@api_view(['POST'])
def send_otp(request):
    email = (request.data.get('email') or '').strip().lower()
    if not email:
        return Response({'detail': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        validate_email(email)
    except ValidationError:
        return Response({'detail': 'Please enter a valid email address.'}, status=status.HTTP_400_BAD_REQUEST)

    otp = EmailOTP.objects.create(email=email, code=generate_code())

    send_mail(
        subject='Your Futsal Finder verification code',
        message=(
            f'Your verification code is {otp.code}. '
            f'It expires in {settings.OTP_EXPIRY_MINUTES} minutes.'
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[email],
    )

    return Response({'detail': 'Verification code sent.'}, status=status.HTTP_200_OK)


@api_view(['POST'])
def verify_otp(request):
    email = (request.data.get('email') or '').strip().lower()
    code = (request.data.get('code') or '').strip()

    if not email or not code:
        return Response({'detail': 'Email and code are required.'}, status=status.HTTP_400_BAD_REQUEST)

    otp = EmailOTP.objects.filter(email=email, is_verified=False).order_by('-created_at').first()

    if otp is None:
        return Response(
            {'detail': 'No verification code found for this email.'}, status=status.HTTP_400_BAD_REQUEST
        )

    if otp.is_expired():
        return Response({'detail': 'Code expired. Please request a new one.'}, status=status.HTTP_400_BAD_REQUEST)

    if otp.attempts >= settings.OTP_MAX_ATTEMPTS:
        return Response(
            {'detail': 'Too many attempts. Please request a new code.'}, status=status.HTTP_400_BAD_REQUEST
        )

    if otp.code != code:
        otp.attempts += 1
        otp.save(update_fields=['attempts'])
        return Response({'detail': 'Incorrect code.'}, status=status.HTTP_400_BAD_REQUEST)

    otp.is_verified = True
    otp.save(update_fields=['is_verified'])
    return Response({'detail': 'Email verified.'}, status=status.HTTP_200_OK)


def _user_payload(user):
    return {
        'email': user.email,
        'full_name': user.full_name,
        'mobile_number': user.mobile_number,
        'role': user.role,
    }


@api_view(['POST'])
def register(request):
    email = (request.data.get('email') or '').strip().lower()
    password = request.data.get('password') or ''
    full_name = (request.data.get('full_name') or '').strip()
    mobile_number = (request.data.get('mobile_number') or '').strip()
    role = request.data.get('role') or ''

    if not email or not password or not full_name or not mobile_number:
        return Response({'detail': 'All fields are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if role not in SELF_SERVICE_ROLES:
        return Response({'detail': 'Invalid user type.'}, status=status.HTTP_400_BAD_REQUEST)

    if not _has_fresh_verified_otp(email):
        return Response(
            {'detail': 'Please verify your email with the code sent to you first.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if User.objects.filter(email=email).exists():
        return Response(
            {'detail': 'An account with this email already exists. Please log in instead.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        validate_password(password)
    except ValidationError as e:
        return Response({'detail': ' '.join(e.messages)}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.create_user(
        email=email,
        password=password,
        full_name=full_name,
        mobile_number=mobile_number,
        role=role,
    )

    return Response(_user_payload(user), status=status.HTTP_201_CREATED)


@api_view(['POST'])
def login(request):
    email = (request.data.get('email') or '').strip().lower()
    password = request.data.get('password') or ''

    if not email or not password:
        return Response({'detail': 'Email and password are required.'}, status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(request, username=email, password=password)
    if user is None:
        return Response({'detail': 'Incorrect email or password.'}, status=status.HTTP_400_BAD_REQUEST)

    return Response(_user_payload(user), status=status.HTTP_200_OK)


@api_view(['POST'])
def reset_password(request):
    email = (request.data.get('email') or '').strip().lower()
    new_password = request.data.get('new_password') or ''

    if not email or not new_password:
        return Response({'detail': 'Email and new password are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if not _has_fresh_verified_otp(email):
        return Response(
            {'detail': 'Please verify your email with the code sent to you first.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({'detail': 'No account found with this email.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        validate_password(new_password, user=user)
    except ValidationError as e:
        return Response({'detail': ' '.join(e.messages)}, status=status.HTTP_400_BAD_REQUEST)

    user.set_password(new_password)
    user.save(update_fields=['password'])

    return Response({'detail': 'Password reset successful.'}, status=status.HTTP_200_OK)
