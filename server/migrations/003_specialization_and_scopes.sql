-- Pro-Link migration 003
-- Adds:
--   * users.specialization      — used to match mentors with interns
--   * schedules.scope_type/value — admin can scope a schedule to a single
--                                  intern, a specialization, or "public"
--   * training_files.is_admin_uploaded — flag used by intern feed so they
--                                  always see admin-uploaded materials
--                                  even when filtering by their mentor.
-- Idempotent: every statement is safe to re-run.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS specialization TEXT NOT NULL DEFAULT '';

ALTER TABLE schedules
    ADD COLUMN IF NOT EXISTS scope_type TEXT NOT NULL DEFAULT 'public'
        CHECK (scope_type IN ('public', 'specialization', 'intern'));
ALTER TABLE schedules
    ADD COLUMN IF NOT EXISTS scope_value TEXT NOT NULL DEFAULT '';

ALTER TABLE training_files
    ADD COLUMN IF NOT EXISTS is_admin_uploaded BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: every existing training_file uploaded by an admin is marked
-- as admin-uploaded so it stays visible to all interns (matches the
-- legacy behaviour). Mentor-uploaded rows keep is_admin_uploaded=false
-- and will only show up to that mentor's assigned interns.
UPDATE training_files tf
   SET is_admin_uploaded = TRUE
  FROM users u
 WHERE tf.uploaded_by = u.id
   AND u.role = 'admin'
   AND tf.is_admin_uploaded = FALSE;
