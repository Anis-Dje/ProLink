-- Standardize every intern's student_id on the canonical STU-YYYY-NNN
-- format (where NNN is a zero-padded sequence that resets each calendar
-- year). The Flutter client no longer asks the user for a student id —
-- the server is now the single source of truth.

-- 1. Backfill: regenerate student_id for every existing intern, ordered
--    by their original registration timestamp so the earliest-registered
--    intern of a given year ends up as 001. Idempotent under repeat runs
--    because the same row order produces the same ids.
WITH numbered AS (
    SELECT
        id,
        EXTRACT(YEAR FROM COALESCE(created_at, NOW()))::int AS yr,
        ROW_NUMBER() OVER (
            PARTITION BY EXTRACT(YEAR FROM COALESCE(created_at, NOW()))
            ORDER BY created_at NULLS LAST, id
        ) AS rn
    FROM interns
)
UPDATE interns i
   SET student_id =
        'STU-' || numbered.yr::text || '-' ||
        LPAD(numbered.rn::text,
             GREATEST(3, LENGTH(numbered.rn::text)), '0')
  FROM numbered
 WHERE i.id = numbered.id;

-- 2. Enforce uniqueness so duplicate ids are impossible going forward.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'interns_student_id_key'
    ) THEN
        ALTER TABLE interns
            ADD CONSTRAINT interns_student_id_key UNIQUE (student_id);
    END IF;
END $$;

-- 3. Helper used by /api/auth/register to compute the next id for a
--    given calendar year. Reads MAX(seq) for that year's prefix and
--    adds one. The UNIQUE constraint above protects us from races.
CREATE OR REPLACE FUNCTION pro_link_next_student_id(p_year INT)
RETURNS TEXT AS $$
DECLARE
    next_seq INT;
    prefix   TEXT := 'STU-' || p_year::text || '-';
BEGIN
    SELECT COALESCE(
               MAX(
                   NULLIF(
                       SUBSTRING(student_id FROM '^' || prefix || '([0-9]+)$'),
                       ''
                   )::int
               ),
               0
           ) + 1
      INTO next_seq
      FROM interns
     WHERE student_id LIKE prefix || '%';
    -- Pad to at least 3 digits, but allow growth past 999 — LPAD with
    -- a length shorter than the input would truncate from the right
    -- and silently produce duplicate ids.
    RETURN prefix ||
           LPAD(next_seq::text,
                GREATEST(3, LENGTH(next_seq::text)), '0');
END;
$$ LANGUAGE plpgsql;
