# Backend

Django + Django REST Framework, serving the Flutter app in `../frontend`
over a JSON API. Setup steps are in the main [README](../README.md).

- **Login** is handled by Supabase Auth. The app sends the user's Supabase
  access token as `Authorization: Bearer <token>`; Django verifies it against
  Supabase's public keys (`accounts/authentication.py`).
- **Database** is the Supabase Postgres database. Django's tables live in a
  separate `django` schema so Supabase's public API can't read them; app
  users and their roles are read from Supabase's `public.profiles`.
- **Time zone** is Asia/Kathmandu.

Django admin panel: http://localhost:8000/admin/

## API

All endpoints need a Supabase access token.

| Method | Path | Who | What |
|---|---|---|---|
| GET | `/api/accounts/me/` | anyone | the signed-in user's profile |
| GET | `/api/grounds/` | anyone | approved, active grounds, with photos, rating and review count |
| GET | `/api/grounds/<id>/slots/?date=YYYY-MM-DD` | anyone | 1-hour slots with price and availability |
| GET | `/api/grounds/favourites/` | customer | favourite grounds |
| POST, DELETE | `/api/grounds/<id>/favourite/` | customer | add or remove a favourite |
| GET, POST, DELETE | `/api/grounds/<id>/reviews/` | customer | reviews and star breakdown; write/update or delete your own (only after playing there) |
| GET | `/api/events/` | anyone | published events, with the phone number to register |
| GET | `/api/payments/methods/` | anyone | which payment methods are on |
| GET, POST | `/api/bookings/` | customer: own · owner: their grounds · admin: all | list, or book `{ground, date, start_time, payment_method}` |
| POST | `/api/bookings/<id>/pay/` | customer | restart an online payment |
| POST | `/api/bookings/<id>/verify-payment/` | customer | confirm the payment with eSewa/Khalti |
| POST | `/api/bookings/<id>/cancel/` | customer or owner | cancel, with refund |
| GET | `/api/notifications/` | anyone | latest 50 and the unread count |
| POST | `/api/notifications/read/` | anyone | mark all as read |
| CRUD | `/api/owner/grounds/` | owner | own grounds |
| POST | `/api/owner/grounds/<id>/maintenance/` | owner | close for maintenance |
| DELETE | `/api/owner/maintenance/<id>/` | owner | reopen |
| CRUD | `/api/owner/events/` | owner | own events |
| GET | `/api/owner/summary/` | owner | dashboard numbers |
| GET | `/api/owner/earnings/?period=day\|week\|month\|year` | owner | earnings chart bars |
| POST | `/api/owner/announcements/` | owner | notice to their customers |
| GET | `/api/admin/grounds/?status=&search=` | admin | grounds to review |
| POST | `/api/admin/grounds/<id>/approve/` | admin | approve |
| POST | `/api/admin/grounds/<id>/reject/` | admin | reject with a reason |
| GET | `/api/admin/summary/` | admin | approval counts |
| GET | `/api/admin/refunds/` | admin | online refunds to send |
| POST | `/api/admin/refunds/<id>/done/` | admin | mark a refund as sent |
| POST | `/api/admin/announcements/` | admin | notice to customers, owners or everyone |

## Apps

- `accounts`: Supabase token login, `Profile` (Supabase users), role permissions
- `grounds`: grounds, rates, photo galleries, approval with lalpurja, maintenance, events, reviews
- `bookings`: 1-hour slot bookings (the database blocks double bookings), eSewa/Khalti payments, refunds, earnings
- `notifications`: in-app notifications and notices

Run the tests with `.\venv\Scripts\python.exe manage.py test`.
