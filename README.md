# Futsal Finder

Find and book futsal grounds in Nepal. One Flutter app serves three kinds of
users: **customers**, **ground owners** and an **admin**. A Django API sits
behind it, and Supabase provides login, the Postgres database and photo
storage.

## What it does

**Customers**
- See their real location on Home (e.g. "Bharatpur, Chitwan") and the grounds
  nearest them.
- Search, **filter** (price, distance, rating, open now, saved) and **sort**
  (nearest, top rated, price, name).
- Browse a **map** where every ground is a drop-shaped pin: green when open,
  orange when closed for maintenance. Tap a pin for a Google Maps–style card
  with photos, rating, open/closed status, rates, hours, directions and reviews.
- Swipe through each ground's **photo gallery** and open photos full screen.
- Book a 1-hour slot and pay with **eSewa**, **Khalti** or cash at the ground.
- **Reschedule** an upcoming booking to another free hour at the same ground
  (online-paid bookings can move to a time with the same price).
- Cancel with a refund (see [Refund rules](#refund-rules)).
- **Rate and review** a ground (1–5 stars) after playing there.
- Get notifications for bookings, cancellations, maintenance, events and notices.
- See tournaments and events posted by ground owners, and **call to register**
  from the event page.
- Read the rules and regulations from the Profile page.

**Ground owners**
- Add grounds with up to **10 photos** (pick a cover), three hourly rates, a
  location picked on the map and a **lalpurja** (land ownership) photo for
  verification. Each new ground waits for admin approval, then shows on the
  customer map.
- View and cancel bookings. Close a ground for maintenance with a reason;
  everyone booked on those days is cancelled and told why.
- Create, edit, publish and delete events, with a phone number customers
  call to register. An event shows "Expired" once it has passed.
- Get notified about new reviews.
- Send notices to their customers.
- Use a dashboard with today's stats and an **earnings chart**: daily, weekly,
  monthly and yearly.

**Admin**
- Approve new grounds after checking the lalpurja, owner details and map.
- Search grounds and take one down for a violation, with a reason.
- Remove reviews that break the rules (Django admin panel).
- Send notices to customers, owners or everyone.
- Track refunds owed for online payments and mark them as sent.

## Support

Phone **9744340506** · Email **csamip53@gmail.com** (also on the app's
Profile → Contact us screen).

## Refund rules

| Situation | Refund |
|---|---|
| Customer cancels within 2 hours of booking | 100% |
| Customer cancels later, before the game | 50% (the owner keeps 50%) |
| Owner cancels, or closes the ground for maintenance | 100% |
| Cash booking cancelled | Nothing to refund (nothing was paid) |

An online booking holds its slot for 15 minutes while the customer pays.
After that the slot is released. Online refunds are sent back by the admin.

## Tech stack

| Part | Built with |
|---|---|
| App | Flutter (Android, iOS, web), `provider`, `fl_chart`, `webview_flutter` |
| Maps | OpenStreetMap via `flutter_map` (free, no key; tiles cached on the phone), `geolocator`, `geocoding` for place names |
| API | Django 5, Django REST Framework |
| Login & database | Supabase Auth and Postgres (Django uses its own `django` schema) |
| Files | Supabase Storage: `avatars`, `ground-photos`, private `ground-documents` |
| Payments | eSewa ePay v2, Khalti KPG-2 |
| Email | Brevo SMTP (falls back to printing to the console) |

## Project layout

```
backend/            Django API
  accounts/         Supabase token login, profiles and roles
  grounds/          grounds, rates, approval, maintenance, events
  bookings/         bookings, payments, refunds, owner earnings
  notifications/    in-app notifications and notices
frontend/           Flutter app
  lib/core/         shared models, services, theme, widgets
  lib/customer/     customer screens
  lib/owner/        ground owner screens
  lib/admin/        admin screens
supabase/
  migrations/       SQL for profiles, storage buckets and their policies
```

## Getting started

### 1. Backend

Needs Python 3.11 or newer.

```powershell
cd backend
python -m venv venv
.\venv\Scripts\pip install -r requirements.txt
copy .env.example .env
```

Fill in `backend/.env`. At minimum you need `DATABASE_PASSWORD`; each setting
is explained in `.env.example`. **Never commit `.env`.**

```powershell
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py runserver 8000
```

Use the venv's Python (`.\venv\Scripts\python.exe`). Plain `python` won't
find Django.

### 2. Supabase

Run the files in `supabase/migrations/` in order, in the Supabase SQL Editor
or with the Supabase CLI. They create the `profiles` table, the sign-up
trigger and the storage buckets.

To make someone an admin or ground owner, set their `role` in
`public.profiles` to `admin` or `ground_owner`.

### 3. App

Needs the Flutter SDK.

```powershell
cd frontend
flutter pub get
flutter run
```

On an Android phone connected over USB, let it reach the backend on your PC:

```powershell
adb reverse tcp:8000 tcp:8000
```

Run this again whenever you restart `flutter run` or replug the phone. To use
a deployed backend instead:

```powershell
flutter run --dart-define=API_BASE_URL=https://your-server.com/api
```

## Live server

The app talks to the live API at `https://futsal-finder-api.onrender.com/api`
(set in `frontend/lib/core/config/api_config.dart`), so it works on any
network without the USB cable. The database is Supabase, already in the cloud.

To set up the server once:

1. Sign up at [render.com](https://render.com) with GitHub.
2. **New → Blueprint**, pick this repo. Render reads `render.yaml`.
3. Fill in the secret values it asks for, copied from `backend/.env`.
4. Wait for the deploy, then open `https://<your-service>.onrender.com/api/health/`.
   It should say `{"status": "ok"}`.

The free plan sleeps after 15 minutes without use; the first request after
that takes up to a minute. A free uptime pinger (e.g. cron-job.org) hitting
`/api/health/` every 10 minutes keeps it awake.

To use the backend on your PC instead (phone on USB):

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
```

## Testing payments

Both gateways run in **test mode** by default, so no real money moves.

| Gateway | Test login |
|---|---|
| eSewa | ID `9806800001`, password `Nepal@123`, OTP `123456` |
| Khalti | Mobile `9800000000`, MPIN `1111`, OTP `987654` |

Khalti needs `KHALTI_SECRET_KEY` in `.env`. Get a sandbox key from
[test-admin.khalti.com](https://test-admin.khalti.com).

## Running tests

```powershell
cd backend
.\venv\Scripts\python.exe manage.py test

cd ..\frontend
flutter analyze
flutter test
```

Backend tests use SQLite, so they don't touch the Supabase database.

## Still to do

- Switch eSewa and Khalti to live merchant accounts.
- Pay out owners' earnings.
- Use a paid or self-hosted map tile server once there are many users
  (OpenStreetMap's free server is for light use).
