# Pro-Link Privacy Policy

_Last updated: 2 May 2026_

This Privacy Policy explains how the Pro-Link mobile application
("Pro-Link", "the app", "we") collects, uses, and protects information
about you when you use the app. Pro-Link is a university–corporate
internship management tool used by interns, mentors, and university
administrators. Reading this policy carefully is important; by creating
an account or using Pro-Link you agree to the practices described
below.

If you have questions, contact us at the address listed in
[Section 11](#11-contact).

## 1. Who is responsible for your data

Pro-Link is operated by the Pro-Link team ("we", "us") on behalf of
the partner university and the host company that have approved your
internship. The university and the host company are the joint
controllers of the data you submit through the app.

## 2. What data we collect

We only collect data that is necessary to operate the app's core
features. We do **not** sell your data, and we do **not** use it for
advertising.

### 2.1 Information you provide directly

- **Account information** — email address, full name, phone number,
  password (stored as a salted bcrypt hash; we never see your
  plaintext password).
- **Profile information** — your role (intern, mentor, admin), and
  optionally a profile picture (uploaded as a file or as a URL you
  choose).
- **Intern record** — your student ID, university name, specialization,
  department, internship start and end dates, and the mentor assigned
  to you. This information is provided either by you during
  registration or by an administrator on your behalf.
- **Documents you upload** — training files, course materials, and
  schedules that you submit through the upload features (interns,
  mentors, and admins each have separate upload flows).

### 2.2 Information generated through use

- **Attendance records** — date, status (present, absent, late, or
  justified), and the mentor who recorded the entry. Records are
  produced either by a mentor manually or automatically by scanning
  your Work-ID QR code.
- **Evaluation records** — criteria scores, an overall score (0–20),
  written comment, and the mentor who issued the evaluation.
- **In-app notifications** — title, message, and read/unread state.
- **Session tokens** — a 64-character hexadecimal token issued at
  login so the server can recognise you on subsequent requests.
  Tokens are revoked on logout.

### 2.3 Information collected automatically

- **Device permissions** — Pro-Link asks for camera permission when a
  mentor opens the QR scanner. Camera frames are processed locally on
  the device for QR detection and are **not** transmitted or stored.
- **Local storage on your device** — the session token (above) and a
  cached copy of your basic profile so you stay logged in between app
  launches.

We do **not** collect: your location, your contacts, your photos
beyond the profile picture you explicitly choose, your microphone,
or any analytics / advertising identifiers.

## 3. How we use your data

We use the data described above only for the following purposes:

| Purpose | Data used |
| --- | --- |
| Authenticating you and keeping you logged in | Email, password hash, session token |
| Letting administrators approve or reject internship requests | Intern record |
| Letting mentors evaluate and track attendance for their assigned interns | Attendance, evaluations |
| Letting interns view their schedule, training files, and evaluations | Schedules, training files, evaluations |
| Generating a digital Work-ID with a QR code that mentors can scan | Profile information, intern record |
| Sending in-app notifications related to your account (e.g. "new evaluation received") | Notification records |

## 4. Where your data is stored

Your data is stored in a PostgreSQL database hosted by Neon
([https://neon.tech](https://neon.tech)) in the AWS `us-east-1` region.
Backups are managed by Neon's standard retention policy. Files you
upload (profile pictures and documents) are stored on the application
server's local filesystem and are accessible only via authenticated
API endpoints.

The university and the host company are the data custodians; the
hosting providers (Neon, AWS) act as data processors under their
respective Data Processing Agreements.

## 5. Who can see your data

Access inside the app follows your role:

- **Interns** can see their own profile, evaluations, attendance,
  schedules, and training files. They cannot see other interns'
  records.
- **Mentors** can see the records of the interns explicitly assigned
  to them, including attendance and evaluations. They cannot see
  interns assigned to other mentors.
- **Administrators** can see all user records and intern profiles in
  order to manage approvals, mentor assignments, and account state.

We do **not** share your data with any third party for marketing,
analytics, or advertising. We may disclose data only when required to
comply with a binding legal obligation (e.g. a court order).

## 6. How long we keep your data

| Category | Retention |
| --- | --- |
| Active account data | For the duration of your internship + 12 months for academic record-keeping |
| Attendance, evaluations | Same as above |
| Session tokens | Until logout, with automatic expiry on the server after 30 days of inactivity |
| Uploaded files | Until you delete the corresponding record, or the account is closed |
| Backups | Up to 7 days, per the hosting provider's policy |

After the retention period, records are permanently deleted or
anonymised (i.e. detached from any identifying field).

## 7. Your rights

You have the following rights regarding your personal data:

- **Access** — request a copy of the data we hold about you.
- **Correction** — request that inaccurate data be corrected.
- **Deletion** — request that your account and associated data be
  deleted, subject to legitimate retention obligations (e.g. an
  ongoing internship cannot be deleted before it ends without your
  university's approval).
- **Objection / Restriction** — object to or restrict certain uses of
  your data.
- **Portability** — receive your data in a structured,
  machine-readable format.

To exercise any of these rights, contact us at the address in
[Section 11](#11-contact). We will respond within 30 days.

## 8. Security

We protect your data with the following measures:

- Passwords are hashed with bcrypt (`PASSWORD_BCRYPT`, work factor
  10). Plaintext passwords are never stored or logged.
- All client–server traffic must use HTTPS in production deployments.
- Database connections use TLS with the Neon-recommended `sslmode=require`
  setting and channel binding.
- Session tokens are random 64-character hex strings, stored only as
  the issuing user's `session_token` column and used as a bearer token.
- Role-based access control is enforced server-side on every API call.

No system is 100% secure. If you suspect that your account has been
compromised, change your password immediately and contact us.

## 9. Children's privacy

Pro-Link is intended for university students and adult professionals.
We do not knowingly collect personal data from anyone under the age
of 16. If you believe a child under 16 has created an account, please
contact us so we can delete it.

## 10. Changes to this policy

We may update this policy from time to time. When we do, we will
update the "Last updated" date at the top. Material changes will be
announced via an in-app notification.

## 11. Contact

For privacy questions, data access requests, or to report a security
issue, contact:

> **Pro-Link Team**
> Email: privacy@pro-link.example
> (Replace with the operator's actual contact address before publishing.)
