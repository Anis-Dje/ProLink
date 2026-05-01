# Pro-Link E2E Test Plan — intern register → admin approve/assign → mentor evaluate

## What is being verified
End-to-end correctness of the **course-only rewrite** (PRs #6/#7/#8) against the live Neon database. Specifically, the three critical paths that failed silently before the PR #8 fixes:
- intern self-registration persists to both `users` and `interns` (Neon pooler compat)
- admin approve flips status from `pending` to `active` (schema backfill)
- mentor evaluation saves (foreign keys + created_at backfill)

## Environment
- Flutter web release build served at `http://localhost:8000`
- PHP backend `php -S 0.0.0.0:8080 router.php` against live Neon pooler via `DATABASE_URL`
- `--dart-define=API_BASE_URL=http://localhost:8080/api`
- Seeded accounts (already in DB):
  - admin: `admin.test@prolink.local` / `AdminPass1!`
  - mentor: `mentor.test@prolink.local` / `MentorPass1!`
- New intern will be created live during the test

## Primary flow (1 recording, sequential)

### Test 1 — It should register a new intern and route to the pending-approval screen
1. On login screen, click **"Créer un compte"**.
2. Fill the form: email `test.intern.<timestamp>@prolink.local`, password `InternPass1!`, full name `Test Intern`, phone `0500000100`, student ID `STU-<ts>`, specialization `Génie Logiciel`.
3. Click **"Créer un compte"** (submit).
4. **PASS CRITERIA**: Screen transitions to the `/pending` route (title contains "En attente" / approval messaging). No error SnackBar. A row appears in `users` (role=intern) and `interns` (status=pending) in Neon.
5. **FAIL INDICATOR**: Silent stay on register, "Erreur lors de l'inscription" SnackBar, or the screen shows a dashboard (means status jumped past pending).

### Test 2 — It should let admin approve the pending intern (status pending → active)
1. Log out (via any visible logout control; if not reachable, navigate directly to `/login` by reloading page after clearing token — reloads because token lives in memory only).
2. Log in with `admin.test@prolink.local` / `AdminPass1!`.
3. **PASS CRITERIA**: Routes to `/admin/dashboard`; header shows "Administrateur" badge (gold).
4. Open drawer → "Gestion des Stagiaires" (or tap the Total Stagiaires stats card).
5. Switch to the **"En attente"** tab. The newly-registered intern appears with a green ✓ check action.
6. Click the green check; confirm the dialog.
7. **PASS CRITERIA**: SnackBar "Stagiaire approuvé". After the tab reload, the intern moves OUT of "En attente" and appears under the "Actifs" tab with status badge showing `active`.
8. **FAIL INDICATOR**: Intern still shown in "En attente" after refresh, or SnackBar "Erreur", or HTTP 500 in browser devtools (would indicate `status` CHECK-constraint still restricts to old values — this is exactly what PR #8 backfill fixed).

### Test 3 — It should let admin assign the intern to a mentor
1. From `/admin/dashboard` drawer or quick action, open **"Affecter un Stagiaire"**.
2. Select the newly-approved intern in the first list.
3. Select **"Mentor Test"** in the mentor list.
4. Pick **Informatique** as department.
5. Click **"Affecter"**.
6. **PASS CRITERIA**: SnackBar "Affectation réussie". A `UPDATE interns SET mentor_id = ..., department = ...` persists (verifiable via `GET /interns/?mentorId=<mentor_id>` returning the intern).
7. **FAIL INDICATOR**: SnackBar "Erreur lors de l'affectation", or mentor dashboard in next test shows 0 assigned interns.

### Test 4 — It should let mentor create an evaluation for their intern
1. Log out. Log in with `mentor.test@prolink.local` / `MentorPass1!`.
2. **PASS CRITERIA**: Routes to `/mentor/dashboard`; header shows "Encadreur" badge (cyan).
3. Stats card "Mes Stagiaires" shows **1** (not 0).
4. Click quick action **"Évaluer"**.
5. On the evaluate screen, the dropdown/card should pre-select "Test Intern" (from step 3).
6. Enter title `Évaluation semaine 1`.
7. Accept defaults for the 6 criteria sliders (each 15/20 → overall ≈ 15).
8. Add comment `Test comment from e2e`.
9. Click **"Enregistrer"**.
10. **PASS CRITERIA**: SnackBar "Évaluation enregistrée". Form resets. A row is persisted in `evaluations` with intern_id = test intern, mentor_id = mentor test, overall_score ≈ 15.
11. **FAIL INDICATOR**: SnackBar "Erreur: …" — would indicate missing `created_at`/`evaluation_date` columns (PR #8 backfill).

## Verification after flow
Run a DB read-out via PHP one-liner and confirm:
- `SELECT status FROM interns WHERE full_name='Test Intern'` → `active`
- `SELECT mentor_id FROM interns WHERE full_name='Test Intern'` → mentor test UUID
- `SELECT COUNT(*) FROM evaluations WHERE intern_id=<test intern id>` → `1`

## Adversarial reasoning (would a broken impl look identical?)
- If the pooler compat fix were missing, **Test 1** would leave no rows in `users`/`interns` even though the UI shows success (token is handed out before the DB transaction settles). The `/pending` screen would then break on its next `/interns/by-user/<id>` lookup, or `/auth/me` would 401. So this test genuinely distinguishes broken from fixed.
- If the `status` CHECK backfill were missing, **Test 2** would yield a Postgres CHECK violation (500) — the approve call writes `status='active'` which wasn't valid in the old enum.
- If the `evaluations.created_at` column were missing, **Test 4** would yield a `column "created_at" does not exist` 500 error at save time.
- If the `interns.registrationDate` JSON mapping were broken (PR #7 fix), the admin "Date d'inscription" cell would show today's date via DateTime.now fallback — we'll verify it shows a realistic registration timestamp instead.

## Out of scope / not tested
- Profile photo upload on web: skipped because register_screen.dart uses `dart:io File` which is not supported on Flutter web. The underlying `/upload` endpoint was smoke-tested separately in the PR #8 description.
- Android-emulator-only flows (deep links, platform channels).
- Password reset (returns `UnimplementedError` by design).
