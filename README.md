# Futsal Finder

Find and book futsal grounds in Nepal. One Flutter app serves three kinds of
users: **customers**, **ground owners** and an **admin**. A Django API sits
behind it, and Supabase provides login, the Postgres database and photo
storage.

## What it does

**Customers**
- Search grounds near them and see morning, day and evening rates.
- Book a 1-hour slot and pay with **eSewa**, **Khalti** or cash at the ground.
- Cancel with a refund (see [Refund rules](#refund-rules)).
- Get notifications for bookings, cancellations, maintenance, events and notices.
- See tournaments and events posted by ground owners.
- Read the rules and regulations from the Profile page.

**Ground owners**
- Add grounds with photos, three hourly rates and a **lalpurja** (land
  ownership) photo for verification. Each new ground waits for admin approval.
- View and cancel bookings. Close a ground for maintenance with a reason;
  everyone booked on those days is cancelled and told why.
- Create, edit, publish and delete events. An event shows "Expired" once it
  has passed.
- Send notices to their customers.
- Use a dashboard with today's stats and an **earnings chart**: daily, weekly,
  monthly and yearly.

**Admin**
- Approve new grounds after checking the lalpurja, owner details and map.
- Search grounds and take one down for a violation, with a reason.
- Send notices to customers, owners or everyone.
- Track refunds owed for online payments and mark them as sent.

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

- Deploy the backend.
- Switch eSewa and Khalti to live merchant accounts.
- Pay out owners' earnings.
- Fill in the support phone and email in
  `frontend/lib/core/config/contact_info.dart`.
