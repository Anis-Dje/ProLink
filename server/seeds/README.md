# Seed scripts

SQL scripts to populate Pro-Link with throwaway demo data. Run them
**after** the schema migrations in `server/migrations/` have been
applied.

## `demo_seed.sql`

Creates 3 mentors, 10 interns across different fields, mentor
assignments, and one week of past attendance records — enough for a
full end-to-end walkthrough.

All seeded accounts use the password `123456`. Email patterns:

- Admin / mentor / intern test users from previous sessions remain
  unchanged.
- New mentors: `mentor1@gmail.com`, `mentor2@gmail.com`, `mentor3@gmail.com`
- New interns: `intern1@gmail.com` through `intern10@gmail.com`

### How to run

**Option A — Neon SQL editor (recommended for first-time use):**

1. Open your Neon project in the browser → SQL editor.
2. Paste the entire contents of `demo_seed.sql` into the editor.
3. Run.

**Option B — psql (if you have it installed):**

```bash
psql "$DATABASE_URL" -f server/seeds/demo_seed.sql
```

### Re-running

The script is idempotent. Every `INSERT` uses
`ON CONFLICT (...) DO UPDATE` (or `DO NOTHING`), so re-running will
not duplicate users or break the unique constraints. Existing rows
are updated to match the seed values.

### Sanity checks

After seeding, the bottom of `demo_seed.sql` lists three queries you
can run to confirm the data landed correctly:

- Account count by role.
- Mentor assignment per intern.
- Per-intern day-count of "present" attendance over the past week.
