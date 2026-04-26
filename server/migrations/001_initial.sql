-- Pro-Link schema. Applied once at server startup by migrate.php.
-- Neon Postgres (vanilla PostgreSQL >= 14).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL CHECK (role IN ('admin', 'mentor', 'intern')),
    profile_photo_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    session_token TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS interns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL,
    university TEXT NOT NULL DEFAULT '',
    specialization TEXT NOT NULL DEFAULT '',
    department TEXT NOT NULL DEFAULT '',
    mentor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    -- Values must match AppConstants.status* in the Flutter client:
    -- pending | active | rejected | completed.
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'active', 'rejected', 'completed')),
    rejection_reason TEXT,
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS evaluations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intern_id UUID NOT NULL REFERENCES interns(id) ON DELETE CASCADE,
    mentor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    criteria JSONB NOT NULL DEFAULT '{}'::jsonb,
    overall_score NUMERIC(5,2) NOT NULL DEFAULT 0,
    comment TEXT NOT NULL DEFAULT '',
    evaluation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intern_id UUID NOT NULL REFERENCES interns(id) ON DELETE CASCADE,
    mentor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    status TEXT NOT NULL
        CHECK (status IN ('present', 'absent', 'late', 'justified')),
    notes TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (intern_id, attendance_date)
);

CREATE TABLE IF NOT EXISTS schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    file_url TEXT NOT NULL,
    uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    week_label TEXT NOT NULL DEFAULT '',
    upload_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS training_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    file_url TEXT NOT NULL,
    file_type TEXT NOT NULL DEFAULT '',
    uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    tags TEXT[] NOT NULL DEFAULT '{}',
    upload_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL DEFAULT '',
    type TEXT NOT NULL DEFAULT 'info',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Backfills for databases that were first created by the earlier
--    Dart backend. CREATE TABLE IF NOT EXISTS above is a no-op once
--    the table exists, so any schema changes since that first run
--    need to be applied explicitly below. All statements are idempotent.

-- Session-token column (PHP auth stores a 64-char hex token per user).
ALTER TABLE users ADD COLUMN IF NOT EXISTS session_token TEXT;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'users_session_token_key'
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT users_session_token_key UNIQUE (session_token);
    END IF;
END $$;

-- Intern status constraint must allow the four values the Flutter
-- client uses: pending | active | rejected | completed.
DO $$
DECLARE
    conname TEXT;
BEGIN
    SELECT c.conname INTO conname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
     WHERE t.relname = 'interns'
       AND c.contype = 'c'
       AND pg_get_constraintdef(c.oid) ILIKE '%status%';
    IF conname IS NOT NULL THEN
        EXECUTE format('ALTER TABLE interns DROP CONSTRAINT %I', conname);
    END IF;
    ALTER TABLE interns
        ADD CONSTRAINT interns_status_check
            CHECK (status IN ('pending', 'active', 'rejected', 'completed'));
    -- Migrate any legacy 'approved' rows to 'active'.
    UPDATE interns SET status = 'active' WHERE status = 'approved';
END $$;

-- Intern columns that the PHP backend expects but the old Dart schema
-- may have named differently (registration_date → created_at etc.).
-- Only add if missing; never drop data.
ALTER TABLE interns ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE interns ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE interns ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE interns ADD COLUMN IF NOT EXISTS end_date DATE;
-- Backfill created_at from the old registration_date column if one existed
-- and the new column is empty.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_name='interns' AND column_name='registration_date') THEN
        UPDATE interns SET created_at = registration_date
         WHERE created_at IS NULL AND registration_date IS NOT NULL;
    END IF;
END $$;

-- attendance: old Dart schema named the column `date`; PHP code uses
-- `attendance_date`. Rename if present under the old name.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_name='attendance' AND column_name='date')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                        WHERE table_name='attendance' AND column_name='attendance_date') THEN
        ALTER TABLE attendance RENAME COLUMN date TO attendance_date;
    END IF;
END $$;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS attendance_date DATE;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'attendance_intern_id_attendance_date_key'
    ) THEN
        BEGIN
            ALTER TABLE attendance
                ADD CONSTRAINT attendance_intern_id_attendance_date_key
                UNIQUE (intern_id, attendance_date);
        EXCEPTION WHEN duplicate_table THEN
            -- already exists with another name; ignore
        END;
    END IF;
END $$;

-- evaluations: old Dart schema was missing created_at.
ALTER TABLE evaluations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE evaluations ADD COLUMN IF NOT EXISTS evaluation_date DATE DEFAULT CURRENT_DATE;
