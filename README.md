# Pro-Link

**Pro-Link** is a Flutter-based professional management application developed
for **Université Constantine 2 – Abdelhamid Mehri**, Department of Fundamental
Computing and its Applications (IFA), as part of the **2025-2026 Mobile
Development Project**. It bridges the gap between the university and the
corporate world by streamlining the entire internship lifecycle.

## Overview

Pro-Link unifies three user roles under a single credential system:

| Role | Who | What they do |
| --- | --- | --- |
| **Admin** | HR / University Coordinators | Approve interns, assign mentors & departments, publish schedules / policies, manage users |
| **Mentor** | Professional supervisors / Teachers | Evaluate interns, take weekly attendance, upload training material |
| **Intern** | Students | View digital Work-ID, schedules, training files, evaluations |

## Features

### Authentication
- Unified login screen for all three roles
- Self-service registration for interns (admin approval required)
- Mentor / Admin accounts created from the admin console
- JWT-based sessions persisted on-device via `flutter_secure_storage`

### Admin
- Pending intern approval queue (approve / reject with reason)
- Assign interns to mentors and departments
- Upload office schedules (PDF / image) with weekly labels
- Upload policy handbooks
- Enable / disable any account

### Mentor
- Dashboard with assigned-intern summary
- Rate interns on six criteria (0-20) with auto-computed overall score
- Weekly attendance matrix (present / absent / late / justified)
- Upload training resources with searchable tags

### Intern
- **Digital Work-ID** with photo, student ID, department, status badge and QR code
- Weekly schedule viewer
- Training catalog with predictive search
- Evaluation history with per-criterion breakdowns and running average

## Architecture

```
.
├── lib/                     # Flutter app
│   ├── core/                # Constants, theme, utils
│   ├── models/              # Plain JSON-serialisable domain models
│   ├── services/            # ApiClient, AuthService, FirestoreService, StorageService
│   ├── screens/             # auth/, admin/, mentor/, intern/
│   ├── widgets/             # Reusable UI components
│   └── main.dart            # Entry point + router
└── server/                  # Dart shelf REST backend (Neon Postgres)
    ├── bin/server.dart      # Entrypoint
    ├── lib/                 # Config, db pool, auth, middleware, handlers
    └── migrations/          # Idempotent SQL migrations
```

## Tech stack

**App**
- Flutter 3+ (Dart 3+)
- [`provider`](https://pub.dev/packages/provider) + a `ChangeNotifier`-based
  `AuthService` for state and `go_router` redirects
- [`go_router`](https://pub.dev/packages/go_router) with role-aware redirects
- `http` + `flutter_secure_storage` for the REST client and JWT persistence

**Backend**
- Dart [`shelf`](https://pub.dev/packages/shelf) +
  [`shelf_router`](https://pub.dev/packages/shelf_router)
- [`postgres`](https://pub.dev/packages/postgres) talking to **Neon**
- `bcrypt` for password hashing, `dart_jsonwebtoken` for JWTs
- `shelf_multipart` + local-disk file storage served at `/files/*`

## Getting started

### 1. Install Flutter
Follow the [official Flutter install guide](https://docs.flutter.dev/get-started/install),
then verify:

```bash
flutter --version
flutter doctor
```

### 2. Provision a Neon database
1. Sign up at [neon.tech](https://neon.tech) and create a project.
2. From the project dashboard, copy the connection string. It looks like:
   ```
   postgresql://<user>:<password>@<host>/<db>?sslmode=require
   ```
3. Export it as `DATABASE_URL`:
   ```bash
   export DATABASE_URL='postgresql://<user>:<password>@<host>/<db>?sslmode=require'
   ```

### 3. Run the backend
```bash
cd server
dart pub get
# Optionally override port / public URL / JWT secret:
#   export PORT=8080
#   export PUBLIC_BASE_URL=http://localhost:8080
#   export JWT_SECRET='change-me-in-production'
dart run bin/server.dart
```

On first boot the server applies SQL migrations from `server/migrations/` and
creates the 8 tables (`users`, `departments`, `interns`, `evaluations`,
`attendance`, `schedules`, `training_files`, `notifications`). It then listens
on `http://0.0.0.0:8080` (or `$PORT`).

### 4. Run the Flutter app
```bash
cd ..
flutter pub get

# Point the app at the backend.
# - Android emulator: 10.0.2.2 maps to the host machine.
# - iOS simulator / desktop: use http://localhost:8080/api
# - Physical device: use your machine's LAN IP, e.g. http://192.168.1.42:8080/api
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

If you don't pass `--dart-define=API_BASE_URL=...`, the app falls back to
`http://10.0.2.2:8080/api` (the Android emulator default).

### 5. Seed an admin account
On a fresh DB no admins exist yet. The simplest path:
1. Register an intern through the app (it auto-creates the user row).
2. Promote the row to admin and clear the intern profile:
   ```sql
   UPDATE users SET role = 'admin' WHERE email = '<your-email>';
   DELETE FROM interns WHERE user_id = (SELECT id FROM users WHERE email = '<your-email>');
   ```
3. Log out and log back in — the app routes you to the admin dashboard, where
   you can create more mentors / admins from the User Management screen.

## REST API surface

All routes live under `/api`. Authentication is via `Authorization: Bearer <jwt>`.

| Method | Path | Notes |
| --- | --- | --- |
| `POST` | `/auth/register` | Self-service intern signup. Returns `{token, user}`. |
| `POST` | `/auth/login` | Email + password. Returns `{token, user}`. |
| `GET`  | `/auth/me` | Returns the current authenticated user. |
| `GET`  | `/users/` | List users. Optional `?role=admin\|mentor\|intern`. |
| `POST` | `/users/` | Admin: create a mentor or admin. |
| `GET\|PATCH` | `/users/<id>` | Read / partial update a user. |
| `POST` | `/users/<id>/active` | Admin: enable / disable an account. |
| `GET`  | `/interns/` | Filters: `?status=`, `?mentorId=`, `?q=`. |
| `GET`  | `/interns/<id>`, `/interns/by-user/<userId>` | Single intern. |
| `POST` | `/interns/<id>/approve` | Admin: optional `{startDate, endDate}`. |
| `POST` | `/interns/<id>/reject` | Admin: `{reason}`. |
| `POST` | `/interns/<id>/assign` | Admin: `{mentorId, department}`. |
| `PATCH`| `/interns/<id>` | Partial update. |
| `GET\|POST` | `/departments/` | Admin-managed list. |
| `GET\|POST` | `/evaluations/` | Mentor evaluations of interns. |
| `GET\|POST` | `/attendance/` | Upserts on `(intern_id, date)`. |
| `GET\|POST\|DELETE` | `/schedules/` | Admin uploads. |
| `GET\|POST\|DELETE` | `/training-files/` | Mentor uploads. |
| `GET\|PATCH\|DELETE` | `/notifications/...` | Per-user notifications. |
| `POST` | `/upload/` | `multipart/form-data` file upload. Returns `{url}`. |

Uploaded files are served as static content under `/files/<uuid>.<ext>`.

## Database schema

8 tables, defined in
[`server/migrations/001_initial.sql`](server/migrations/001_initial.sql):

- `users` (UUID PK, email UNIQUE, password_hash, role)
- `departments`
- `interns` (FK → users, status, mentor assignment, dates)
- `evaluations` (criteria stored as `JSONB` for flexible grading)
- `attendance` (UNIQUE on `(intern_id, date)` for upserts)
- `schedules`, `training_files`, `notifications`

## Security notes
- Passwords are hashed with bcrypt before being stored in `users.password_hash`.
- JWTs expire after 7 days. Set a strong `JWT_SECRET` in production.
- The `DATABASE_URL` should never be committed to source control. The repo's
  `.gitignore` excludes `.env` files; treat your Neon credentials as secret.
