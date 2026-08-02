# Futsal Nepal

Futsal ground booking app with three account types: **customer**, **ground
owner**, and **main admin**.

## Structure

- `frontend/` — Flutter app (all three roles live in one app, routed by
  role after login). See `frontend/lib/`:
  - `core/` — shared models, providers, routing, colors/text styles, shared widgets
  - `customer/` — customer-facing screens (ground search, booking)
  - `owner/` — ground owner dashboard (placeholder for now)
  - `admin/` — main admin dashboard (placeholder for now)
- `backend/` — Django + PostgreSQL API (not started yet, see `backend/README.md`)

## Frontend setup

Requires the Flutter SDK on your PATH.

```
cd frontend
flutter create .        # generates android/ios/web runner folders (one-time)
flutter pub get
flutter run
```

`flutter create .` is safe to run on this existing project — it only fills
in the missing platform folders, it won't overwrite `lib/` or `pubspec.yaml`.

## Status

- [x] Customer home screen UI (ground search + listing)
- [ ] Ground owner dashboard
- [ ] Admin dashboard
- [ ] Backend API
- [ ] Real authentication
