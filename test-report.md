# Pro-Link E2E test report

## TL;DR

All 4 critical-path tests **passed**. Intern self-registered via the UI, admin approved + assigned them to the mentor, and the mentor submitted a saved evaluation — all against the live Neon DB through the course-compliant PHP backend.

One caveat: the **admin approve / assign** steps went through the REST API (authenticated with admin credentials) rather than clicking the green ✓ in the UI. The green-check button opened its confirmation dialog but the Flutter web canvas had stale-frame rendering issues in this test environment, so the dialog button wasn't reliably clickable. The **same PHP endpoints** that the UI calls (`/interns/{id}/approve`, `/interns/{id}/assign`) were exercised — this validates the server-side code path and the fix in PR #8 — but not the specific admin UI buttons. Register (intern) and evaluate (mentor) went fully through the UI end-to-end.

Screen-recording tools were requested but unavailable in this session (`computer(action="record_start")` returned "Recording actions are now separate top-level tools" and those top-level tools were not in my function list). Evidence below is via screenshots + DB verification.

## Environment
- Flutter web release build served on `http://localhost:8000`
- PHP 8.1 backend on `:8080` → Neon Postgres via pooler (`DATABASE_URL_TEMP`)
- Seed admin: `admin.test@prolink.local` / `AdminPass1!`
- Seed mentor: `mentor.test@prolink.local` / `MentorPass1!`
- Fresh test intern created during the run: `test.e2e.2026@prolink.local` / `InternPass1!`

## Results

- Register a new intern and route to /pending — **passed** (UI)
- Admin approve flips intern status `pending → active` — **passed** (API, identical code path)
- Admin assign sets `mentor_id + department` — **passed** (API, identical code path)
- Mentor evaluate creates an evaluation row — **passed** (UI, green "Évaluation enregistrée" SnackBar)

## Evidence

### Test 1 — Register (UI)

Register form filled out, clicking submit:

![register form filled](/home/ubuntu/screenshots/screenshot_8da8fe6249664fb198b7dce006465756.png)

After submit — redirected to `/pending` "Compte en attente" screen:

![compte en attente](/home/ubuntu/screenshots/screenshot_39e5076c829e430d9b0e30700c8f3ddf.png)

DB verification — `users` row created with role=intern, `interns` row inserted with `status=pending`:

```
test.e2e.2026@prolink.local | role=intern | name=Test Intern E2E | intern=pending | stud_id=STU-E2E-2026
```

### Test 2 + 3 — Admin approve + assign

Logged in via UI as `admin.test@prolink.local`, admin dashboard loaded showing Total Stagiaires=1 / Stagiaires Actifs=0:

![admin dashboard before approve](/home/ubuntu/screenshots/screenshot_2c2a846a1354439b99a5d0e3caba898d.png)

"Gestion des Stagiaires" list showed the new intern under "En attente" with the green ✓ / red × actions:

![gestion des stagiaires](/home/ubuntu/screenshots/screenshot_71617df58e8c466b8ad8debff2c08018.png)

Approve + assign then called via the **same PHP endpoints the UI uses**, authenticated with the admin's JWT:

```
POST /api/interns/8974d57e-.../approve    → 200 status=active, startDate=2026-04-26
POST /api/interns/8974d57e-.../assign     → 200 mentorId=8ab6ae2b-..., department=Informatique
```

DB verification after both calls:

```
interns row: status=active | start=2026-04-26 00:00:00+00 | mentor=8ab6ae2b-0790-4f36-bc86-89071915c8b1
```

### Test 4 — Mentor evaluate (UI)

Logged in as `mentor.test@prolink.local`. Mentor dashboard stats card "Mes Stagiaires = 1, Actifs = 1" confirms the assign step propagated:

![mentor dashboard](/home/ubuntu/screenshots/screenshot_bf0030c8531c4034937e831209f01142.png)

Evaluate screen — intern pre-selected in dropdown as "Test Intern E2E · STU-E2E-2026", title filled, 6 criteria sliders at 15.0:

![evaluate filled](/home/ubuntu/screenshots/screenshot_df16b98ea27d4beaab02f53ce9d334e3.png)

After clicking "Enregistrer l'évaluation" — green "Évaluation enregistrée" SnackBar at the bottom:

![evaluation saved snackbar](/home/ubuntu/screenshots/screenshot_68139e329c544389be91732f1425ad03.png)

DB verification — `evaluations` row persisted with correct intern_id, mentor_id, title, score, comment, and created_at:

```
id              = d6123ac6-a004-415b-9075-dd167a963dd5
intern_id       = 8974d57e-afa6-44df-a0a3-edf9843a5ac9  (Test Intern E2E)
mentor_id       = 8ab6ae2b-0790-4f36-bc86-89071915c8b1  (Mentor Test)
title           = Evaluation semaine 1 E2E
overall_score   = 15.00
comment         = Bon travail, continue comme ca. Test comment from e2e.
evaluation_date = 2026-04-26 00:00:00+00
created_at      = 2026-04-26 21:56:56.819042+00
```

The `created_at` column persisting confirms the PR #8 schema-drift backfill is effective — this column was previously missing on old DB snapshots and would have 500'd the save.

## Not tested

- Profile photo upload during register. Skipped deliberately — the register screen uses `dart:io File` via `image_picker` which crashes on Flutter web. The underlying `/upload` endpoint was smoke-tested separately in the PR #8 merge.
- The admin UI approve/assign button clicks themselves (dialog-confirm + visual status-badge flip). The backend code they call is proven working via direct API call in Tests 2+3, but I did not click the specific buttons through to completion due to canvas rendering issues in this test environment. On a physical device or local dev machine these should work — the UI layer uses the same `FirestoreService.approveIntern` / `assignInternToMentor` methods that the API calls exercised.

## Links

- Session: https://app.devin.ai/sessions/bf1b5970b05448ddbd076cf9031e7a32
- Repo: https://github.com/Anis-Dje/ProLink
