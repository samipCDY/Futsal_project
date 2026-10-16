"""Online payment with eSewa (ePay v2) and Khalti (ePayment / KPG-2).

The app opens the gateway's page, and when the customer comes back it asks
this API to verify. Verification always asks eSewa/Khalti directly from the
server, so a customer can't fake a successful payment from the phone.
"""

import base64
import hashlib
import hmac
import json
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings


class PaymentError(Exception):
    """The gateway couldn't be reached or refused the request."""


def available_methods():
    """Payment methods the app can offer right now."""
    return {
        'cash': True,
        'esewa': bool(settings.ESEWA_SECRET_KEY),
        'khalti': bool(settings.KHALTI_SECRET_KEY),
    }


def _amount(booking):
    """eSewa wants rupees as text; the same text must be signed and sent."""
    return f'{booking.price:.0f}' if booking.price == booking.price.to_integral() else f'{booking.price:.2f}'


def _esewa_signature(message):
    digest = hmac.new(settings.ESEWA_SECRET_KEY.encode(), message.encode(), hashlib.sha256).digest()
    return base64.b64encode(digest).decode()


def _call(request, timeout=20):
    try:
        with urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except HTTPError as error:
        try:
            return json.load(error)  # Khalti answers 400 with a JSON body for expired/cancelled
        except ValueError:
            raise PaymentError(f'Payment service error ({error.code}). Please try again.')
    except (URLError, TimeoutError, ValueError):
        raise PaymentError("Couldn't reach the payment service. Please try again.")


def start(booking):
    """Begins a new payment attempt and returns what the app needs to open
    the gateway's page. Saves the attempt's id on the booking."""
    return_url = settings.PAYMENT_RETURN_URL
    if booking.payment_method == booking.PaymentMethod.ESEWA:
        booking.payment_token = f'{booking.booking_ref}-{int(time.time())}'
        booking.save(update_fields=['payment_token'])
        total = _amount(booking)
        fields = {
            'amount': total,
            'tax_amount': '0',
            'total_amount': total,
            'transaction_uuid': booking.payment_token,
            'product_code': settings.ESEWA_PRODUCT_CODE,
            'product_service_charge': '0',
            'product_delivery_charge': '0',
            'success_url': f'{return_url}esewa/success/',
            'failure_url': f'{return_url}esewa/failure/',
            'signed_field_names': 'total_amount,transaction_uuid,product_code',
        }
        fields['signature'] = _esewa_signature(
            f'total_amount={total},transaction_uuid={booking.payment_token},'
            f'product_code={settings.ESEWA_PRODUCT_CODE}')
        return {'gateway': 'esewa', 'form_url': settings.ESEWA_FORM_URL, 'fields': fields,
                'return_url_prefix': return_url}

    if booking.payment_method == booking.PaymentMethod.KHALTI:
        customer = booking.customer
        body = {
            'return_url': f'{return_url}khalti/',
            'website_url': settings.PAYMENT_WEBSITE_URL,
            'amount': int(booking.price * 100),  # paisa
            'purchase_order_id': booking.booking_ref,
            'purchase_order_name': f'{booking.ground.name} {booking.date} {booking.start_time:%H:%M}',
            'customer_info': {k: v for k, v in (('name', customer.full_name), ('email', customer.email),
                                                ('phone', customer.mobile_number)) if v},
        }
        data = _call(Request(
            f'{settings.KHALTI_BASE_URL}epayment/initiate/',
            data=json.dumps(body).encode(),
            headers={'Authorization': f'Key {settings.KHALTI_SECRET_KEY}', 'Content-Type': 'application/json'},
            method='POST',
        ))
        if 'pidx' not in data:
            raise PaymentError(_khalti_error(data))
        booking.payment_token = data['pidx']
        booking.save(update_fields=['payment_token'])
        return {'gateway': 'khalti', 'payment_url': data['payment_url'], 'return_url_prefix': return_url}

    raise PaymentError('This booking is paid in cash at the ground.')


def _khalti_error(data):
    if isinstance(data, dict):
        for value in data.values():
            if isinstance(value, list) and value:
                return str(value[0])
            if isinstance(value, str):
                return value
    return 'Khalti refused the payment request.'


def check(booking):
    """Asks the gateway about the booking's latest attempt. Returns the
    gateway's transaction id if it's fully paid, otherwise None."""
    if not booking.payment_token:
        return None
    if booking.payment_method == booking.PaymentMethod.ESEWA:
        query = urlencode({'product_code': settings.ESEWA_PRODUCT_CODE, 'total_amount': _amount(booking),
                           'transaction_uuid': booking.payment_token})
        data = _call(Request(f'{settings.ESEWA_STATUS_URL}?{query}'))
        if data.get('status') == 'COMPLETE' and data.get('transaction_uuid') == booking.payment_token:
            return data.get('ref_id') or booking.payment_token
        return None

    if booking.payment_method == booking.PaymentMethod.KHALTI:
        data = _call(Request(
            f'{settings.KHALTI_BASE_URL}epayment/lookup/',
            data=json.dumps({'pidx': booking.payment_token}).encode(),
            headers={'Authorization': f'Key {settings.KHALTI_SECRET_KEY}', 'Content-Type': 'application/json'},
            method='POST',
        ))
        # Only "Completed" is a success, and only for the full price.
        if data.get('status') == 'Completed' and data.get('total_amount') == int(booking.price * 100):
            return data.get('transaction_id') or booking.payment_token
        return None
    return None
