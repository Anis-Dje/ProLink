# Pro-Link PHP Backend

This is the PHP REST API for the Pro-Link Flutter app. It follows the pattern
taught in the *Mobile Applications Development* course at Constantine 2
University (Dr. SEGHIRI Akram) — one `.php` file per endpoint, simple
`http.get` / `http.post` consumers on the Flutter side, JSON responses via
`json_encode()`.

We connect to **Neon Postgres** via PDO (`pdo_pgsql`) because we kept the
cloud database, but the endpoint style (`read.php` / `write.php` / etc.) is
directly from the course.

## Requirements

- PHP 8.1+ with the `pdo_pgsql` extension:
  - Ubuntu/Debian: `sudo apt install php-cli php-pgsql`
  - macOS (Homebrew): `brew install php`
  - Windows (WAMP/XAMPP): enable `php_pdo_pgsql` in `php.ini`
- A Neon Postgres connection string in the `DATABASE_URL` environment
  variable, e.g.
  `postgresql://user:pass@host.neon.tech/db?sslmode=require`.

## Run locally

```bash
cd server
export DATABASE_URL='postgresql://neondb_owner:***@ep-....neon.tech/neondb?sslmode=require'
php migrate.php                           # one-time: create the tables
php -S 0.0.0.0:8080 router.php            # start the API
```

The Flutter app connects to:
- Android emulator  → `http://10.0.2.2:8080`
- iOS simulator    → `http://localhost:8080`
- Physical device  → `http://<your-lan-ip>:8080` (same WiFi),
  per the course example (slide 11 of *Flutter – REST API*).

You can override the URL at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.4:8080/api
```

## Endpoints

| Method | Path | Purpose | Role |
| --- | --- | --- | --- |
| POST | `/api/auth/register` | Intern self-signup | public |
| POST | `/api/auth/login` | Exchange email+password for a session token | public |
| GET | `/api/auth/me` | Current user | any |
| POST | `/api/auth/logout` | Invalidate token | any |
| GET | `/api/users/` | List users (`?role=`) | any |
| POST | `/api/users/` | Create mentor/admin | admin |
| GET | `/api/users/<id>` | User detail | any |
| PATCH | `/api/users/<id>` | Update profile | self / admin |
| GET | `/api/interns/` | List interns (filters: `status`, `mentorId`, `department`, `q`) | any |
| GET | `/api/interns/by-user/<userId>` | Intern row for a given user | any |
| POST | `/api/interns/approve/<id>` | Approve application | admin |
| POST | `/api/interns/reject/<id>` | Reject application | admin |
| POST | `/api/interns/assign/<id>` | Set mentor / department | admin |
| GET | `/api/evaluations/` | List (filters: `internId`, `mentorId`) | any |
| POST | `/api/evaluations/` | Create evaluation | mentor / admin |
| GET | `/api/attendance/` | List (filters: `internId`, `mentorId`, `from`, `to`) | any |
| POST | `/api/attendance/` | Record one day | mentor / admin |
| GET | `/api/schedules/` | List office schedules / timetables | any |
| POST | `/api/schedules/` | Publish a schedule | admin |
| GET | `/api/training-files/` | List training resources (`?q=`) | any |
| POST | `/api/training-files/` | Publish resource | mentor / admin |
| GET | `/api/notifications/` | Current user's notifications | any |
| POST | `/api/upload/` | `multipart/form-data`, field `file` | any |

Uploaded files are stored in `server/uploads/` and served at `/files/<name>`.

## Auth

Sessions are random 64-char hex tokens stored in `users.session_token`. The
client puts the token in `Authorization: Bearer <token>`. No JWT / refresh
tokens (out of course scope). Passwords are hashed with `password_hash()`
(bcrypt) — standard PHP.

## Schema

See `migrations/001_initial.sql`. `migrate.php` applies every migration in
alphabetical order and is idempotent (`CREATE TABLE IF NOT EXISTS`).
