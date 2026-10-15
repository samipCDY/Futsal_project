# Backend

Django + Django REST Framework, serving the Flutter app in `../frontend`
over a JSON API.

- **Login** is handled by Supabase Auth. The app sends the user's Supabase
  access token as `Authorization: Bearer <token>`; Django verifies it against
  Supabase's public keys (`accounts/authentication.py`).
- **Database** is the Supabase Postgres database. Django's tables live in a
  separate `django` schema so Supabase's public API can't read them; app
  users and their roles are read from Supabase's `public.profiles`.

## Setup

```
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env      (then fill in DATABASE_PASSWORD)
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 8000
```

Admin panel: http://localhost:8000/admin/ — add grounds there, and change a
user's role (Profiles) to make them a ground owner or admin.

Run the tests with `python manage.py test`.

### Testing from the Flutter app

- **Chrome / desktop**: works immediately, same machine.
- **Physical Android device over USB**: run `adb reverse tcp:8000 tcp:8000`
  once per debugging session.

## API

All endpoints need a Supabase access token.

| Method | Path | Who | What |
|---|---|---|---|
| GET | `/api/accounts/me/` | anyone | the signed-in user's profile |
| GET | `/api/grounds/` | anyone | active grounds |
| GET | `/api/grounds/<id>/` | anyone | one ground |
| GET | `/api/grounds/<id>/slots/?date=YYYY-MM-DD` | anyone | 1-hour slots and whether each is free |
| GET | `/api/bookings/` | anyone | customer: own · owner: at their grounds · admin: all |
| POST | `/api/bookings/` | customer | book `{ground, date, start_time}` (409 if just taken) |
| POST | `/api/bookings/<id>/cancel/` | as above | cancel an upcoming booking |

## Apps

- `accounts` — Supabase token login, `Profile` (Supabase users), role permissions
- `grounds` — ground listings, opening hours, slot availability
- `bookings` — 1-hour slot bookings; the database blocks double bookings
- `reviews` — ratings shown on ground cards (not started)
