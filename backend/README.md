# Backend

Django + Django REST Framework, serving the Flutter app in `../frontend`
over a JSON API. SQLite by default (zero setup); switch to PostgreSQL later
by setting `DATABASE_ENGINE=postgres` in `.env` (see `.env.example`).

## Setup

```
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 8000
```

By default OTP emails are printed to this console instead of actually being
sent (no email account needed to develop). To send real emails, copy
`.env.example` to `.env`, set `EMAIL_BACKEND=smtp`, and fill in real SMTP
credentials (e.g. a Gmail account with an App Password).

### Testing from the Flutter app

- **Chrome / desktop**: works immediately, same machine.
- **Physical Android device over USB**: run `adb reverse tcp:8000 tcp:8000`
  once per debugging session — this forwards the phone's own
  `localhost:8000` to this PC's Django server over the same USB connection
  `flutter run` already uses.

## Apps

- `accounts` — email OTP verification is live (`/api/accounts/otp/send/`,
  `/api/accounts/otp/verify/`). User auth/roles/profiles come next.
- `grounds` — ground listings, availability, images, pricing (not started)
- `bookings` — slot booking, booking status, payments (not started)
- `reviews` — ratings shown on ground cards in the app (not started)
