# Pro-Link

**Pro-Link** is a Flutter-based professional management application developed
for **Université Constantine 2 – Abdelhamid Mehri**, Department of Fundamental
Computing and its Applications (IFA), as part of the **2025-2026 Mobile
Development Project** course (Dr. SEGHIRI Akram). It bridges the gap between
the university and the corporate world by streamlining the entire internship
lifecycle.

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
- Session token stored in memory for the life of the process (course scope)

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
- **Digital Work-ID** with photo, student ID, department and status badge
- Weekly schedule viewer
- Training catalog with predictive search
- Evaluation history with per-criterion breakdowns and running average

## Tech stack — strictly course-scope

Everything in the app maps back to something explicitly taught in the
*Mobile Applications Development* course (Dart, Flutter, State Management,
REST API & PHP modules).

**App (Flutter)**
| Tool | Course reference |
| --- | --- |
| `StatelessWidget` / `StatefulWidget`, `setState`, `initState`, `build` | Flutter – part 1 |
| `Scaffold`, `AppBar`, `Container`, `Row`, `Column`, `SizedBox`, `Center`, `Text`, `Icon`, `Image.network`, `TextField`, `ElevatedButton`, `TextEditingController`, `ListView.builder`, `TabBar` / `DefaultTabController` | Flutter – part 1 & 2 |
| `Navigator.pushNamed` / `Navigator.pushReplacementNamed` / `Navigator.pushNamedAndRemoveUntil` / `Navigator.pop`, named routes via `MaterialApp.routes` | Flutter – part 2 (Navigation & Routing) |
| [`provider`](https://pub.dev/packages/provider) – `ChangeNotifier`, `ChangeNotifierProvider`, `Consumer` | Flutter – State Management part 1 |
| [`http`](https://pub.dev/packages/http) + `jsonDecode` + `factory fromJson`, `Future`/`async`/`await`, `FutureBuilder`, `CircularProgressIndicator` | Flutter – REST API |

**Backend (PHP)**
- A set of `.php` scripts under `server/api/` — one endpoint per action
  (`auth_login.php`, `auth_register.php`, `interns.php`, `evaluations.php`,
  `upload.php`, …), exactly the `read.php` / `write.php` style from the
  *Flutter – REST API* slides.
- **Neon Postgres** is reached through PDO (`pdo_pgsql`). We swapped the
  course's local MySQL / WAMP setup for Neon so the DB can be cloud-hosted 
  but kept the single-file-per-endpoint PHP layout.
- `password_hash()` / `password_verify()` for credentials; random 64-char
  hex tokens for sessions (no JWT library).

## Architecture

```
.
├── lib/                      # Flutter app
│   ├── core/                 # Constants, theme, utils
│   ├── models/               # Plain JSON-serialisable domain models
│   ├── services/
│   │   ├── api_client.dart   # http wrapper (in-memory session token)
│   │   ├── auth_service.dart # ChangeNotifier; login / logout / current user
│   │   ├── firestore_service.dart (legacy name; wraps the REST endpoints)
│   │   └── storage_service.dart   (wraps /api/upload/)
│   ├── screens/              # auth/, admin/, mentor/, intern/
│   ├── widgets/              # Reusable UI components
│   └── main.dart             # MaterialApp + routes map + RootGate
└── server/                   # PHP backend
    ├── migrate.php           # One-off schema migration runner
    ├── migrations/           # SQL migrations (CREATE TABLE IF NOT EXISTS)
    ├── router.php            # Front controller for `php -S`
    ├── lib/                  # Shared PDO / helpers
    ├── api/                  # One PHP file per endpoint
    └── uploads/              # Local disk storage served at /files/<name>
```

## Getting started

### 1. Install Flutter
Follow the [official Flutter install guide](https://docs.flutter.dev/get-started/install),
then verify:

```bash
flutter --version
flutter doctor
```

### 2. Install PHP
```bash
# Ubuntu / Debian
sudo apt install php-cli php-pgsql
# macOS
brew install php
```
PHP 8.1+ is required, with the `pdo_pgsql` extension enabled (`php -m | grep pgsql`).

### 3. Provision a Neon database
1. Sign up at [neon.tech](https://neon.tech) and create a project.
2. From the project dashboard, copy the connection string:
   ```text
   postgresql://<user>:<password>@<host>/<db>?sslmode=require
   ```
3. Set it as `DATABASE_URL`.

   On Linux / macOS:
   ```bash
   export DATABASE_URL='postgresql://<user>:<password>@<host>/<db>?sslmode=require'
   ```

   On Windows PowerShell:
   ```powershell
   $env:DATABASE_URL = "postgresql://neondb_owner:npg_RTdlsGe3hz8W@ep-muddy-wave-am1bw3qg-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
   ```

4. If you are using Neon from Windows/PHP and get an error about the endpoint ID
   or SNI, also set `PGOPTIONS` using the first part of your Neon host.

   Example host:
   ```text
   ep-muddy-wave-am1bw3qg-pooler.c-5.us-east-1.aws.neon.tech
   ```

   Endpoint ID:
   ```text
   ep-muddy-wave-am1bw3qg-pooler
   ```

   Windows PowerShell:
   ```powershell
   $env:PGOPTIONS = "endpoint=ep-muddy-wave-am1bw3qg-pooler"
   ```

### 4. Run the backend

On Windows PowerShell:
```powershell
cd server
$env:DATABASE_URL = "postgresql://<user>:<password>@<host>/<db>?sslmode=require&channel_binding=require"
$env:PGOPTIONS = "endpoint=<neon-endpoint-id>"   # optionnel, utile si Neon l'exige
php migrate.php                          # one-off: create the tables
php -S <IP_LOCALE>:8081 router.php       # start the API on your PC's local IPv4 and port 8081
```

Important: run all commands above in the same PowerShell window so PHP keeps
the `DATABASE_URL` / `PGOPTIONS` variables.

The backend listens on `http://<IP_LOCALE>:8081`. `router.php` dispatches:
- `/api/<group>/<action?>/<id?>` to the matching PHP file under `server/api/`.
- `/files/<name>` to uploaded files in `server/uploads/`.

Quick way to get your local IPv4:
```powershell
ipconfig | Select-String "IPv4"
```

### 5. Run the Flutter app
```powershell
cd ..
flutter pub get

# Point the app at the backend.
# - LD Player emulator: <IP_LOCALE>:8081/api (your local IPv4)
# - Android emulator (AOSP): 10.0.2.2:8081/api
# - iOS simulator / desktop: use http://localhost:8081/api
# - Physical device: your machine's LAN IP, e.g. http://<IP_LOCALE>:8081/api
#   (the same 'share WiFi with phone' pattern shown in slide 11 of the
#    Flutter – REST API deck).
flutter run --dart-define=API_BASE_URL=http://<IP_LOCALE>:8081/api
```

If you don't pass `--dart-define=API_BASE_URL=...`, the app falls back to
the value configured in `lib/services/api_client.dart`.

### 6. Seed an admin account
On a fresh DB no admins exist yet. The simplest path:
1. Register an intern through the app (it auto-creates a user row).
2. Promote the row to admin and clear the intern profile:
   ```sql
   UPDATE users SET role = 'admin' WHERE email = '<your-email>';
   DELETE FROM interns WHERE user_id =
     (SELECT id FROM users WHERE email = '<your-email>');
   ```
3. Log out and log back in — the app routes you to the admin dashboard, where
   you can create more mentors / admins from the User Management screen.

### 7. (Optional) Demo seed for end-to-end testing
For a populated environment with 3 mentors, 10 interns across different
fields, mentor assignments, and one week of past attendance, paste
[`server/seeds/demo_seed.sql`](server/seeds/demo_seed.sql) into Neon's
SQL editor (or run it with `psql`). All seeded accounts use the password
`123456`. See [`server/seeds/README.md`](server/seeds/README.md) for
details.

## Legal

- [Privacy Policy](docs/legal/PRIVACY_POLICY.md)
- [Terms of Service](docs/legal/TERMS_OF_SERVICE.md)

These templates describe how Pro-Link handles user data and the rules
of acceptable use; replace the placeholder contact addresses before
publishing the app to a public store.

## REST API surface

See [`server/README.md`](server/README.md) for the full endpoint reference.
Every endpoint returns JSON (`json_encode($return)`, as in the course slides)
and requires `Authorization: Bearer <token>` except `/auth/login` and
`/auth/register`.

## Database schema

8 tables, defined in
[`server/migrations/001_initial.sql`](server/migrations/001_initial.sql):

- `users` (UUID PK, email UNIQUE, password_hash, role, session_token)
- `departments`
- `interns` (FK → users, status, mentor assignment, dates)
- `evaluations` (criteria stored as `JSONB` for flexible grading)
- `attendance` (UNIQUE on `(intern_id, attendance_date)` for upserts)
- `schedules`, `training_files`, `notifications`

## Security notes
- Passwords are hashed with `password_hash(..., PASSWORD_BCRYPT)`.
- Session tokens are 64-char hex strings stored in `users.session_token`.
  They're rotated on every login and cleared on logout.
- The `DATABASE_URL` should never be committed to source control. The repo's
  `.gitignore` excludes `.env` files; treat your Neon credentials as secret.
