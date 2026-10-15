import json
from urllib.error import URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from django.conf import settings

DOCUMENTS_BUCKET = 'ground-documents'


def signed_document_url(path, expires_in=600):
    """A link to a private ownership document that works for `expires_in`
    seconds, or None if it can't be made (no secret key, or Supabase down)."""
    key = settings.SUPABASE_SECRET_KEY
    if not key or not path:
        return None
    headers = {'apikey': key, 'Content-Type': 'application/json'}
    if not key.startswith('sb_'):  # the older JWT-style service_role key
        headers['Authorization'] = f'Bearer {key}'
    request = Request(
        f'{settings.SUPABASE_URL}/storage/v1/object/sign/{DOCUMENTS_BUCKET}/{quote(path)}',
        data=json.dumps({'expiresIn': expires_in}).encode(),
        headers=headers,
        method='POST',
    )
    try:
        with urlopen(request, timeout=10) as response:
            signed = json.load(response)['signedURL']
    except (URLError, ValueError, KeyError, TimeoutError):
        return None
    return f'{settings.SUPABASE_URL}/storage/v1{signed}'
