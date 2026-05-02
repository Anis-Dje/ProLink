-- Pro-Link demo seed: 3 mentors, 10 interns across different fields,
-- mentor assignments, and one week of past attendance for each intern.
--
-- All accounts use the password "123456". The bcrypt hash below was
-- generated with PHP's password_hash($password, PASSWORD_BCRYPT) and
-- is verified against any future password_hash() call thanks to bcrypt's
-- built-in random salt; the same hash is reused for every seeded user.
--
-- Re-running this script is safe: every INSERT uses ON CONFLICT (email)
-- DO UPDATE / ON CONFLICT DO NOTHING so existing rows are not duplicated
-- and IDs stay stable across runs.
--
-- Run this in Neon's SQL editor (or via psql) AFTER the schema migrations
-- (server/migrations/001_initial.sql) have been applied. The script uses
-- only standard SQL — no psql-specific meta-commands — so it works in
-- any client.

BEGIN;

-- ──────────────────────────────────────────────────────────────────
-- 1. Mentors (3 accounts). All passwords are "123456" hashed with
--    PHP's password_hash(..., PASSWORD_BCRYPT).
-- ──────────────────────────────────────────────────────────────────
INSERT INTO users (email, password_hash, full_name, phone, role, is_active)
VALUES
    ('mentor1@gmail.com', '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Karim Bensalah', '+213 555 110 001', 'mentor', TRUE),
    ('mentor2@gmail.com', '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Sara Hadj-Ali',  '+213 555 110 002', 'mentor', TRUE),
    ('mentor3@gmail.com', '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Yacine Meddah',  '+213 555 110 003', 'mentor', TRUE)
ON CONFLICT (email) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        role      = EXCLUDED.role,
        is_active = EXCLUDED.is_active;

-- ──────────────────────────────────────────────────────────────────
-- 2. Intern user accounts (10 accounts across different fields).
-- ──────────────────────────────────────────────────────────────────
INSERT INTO users (email, password_hash, full_name, phone, role, is_active)
VALUES
    ('intern1@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Amine Boudjelal',     '+213 555 220 001', 'intern', TRUE),
    ('intern2@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Lina Cherif',         '+213 555 220 002', 'intern', TRUE),
    ('intern3@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Rayan Belkacem',      '+213 555 220 003', 'intern', TRUE),
    ('intern4@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Nour El Houda Saidi', '+213 555 220 004', 'intern', TRUE),
    ('intern5@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Mehdi Tahar',         '+213 555 220 005', 'intern', TRUE),
    ('intern6@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Ines Mahmoudi',       '+213 555 220 006', 'intern', TRUE),
    ('intern7@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Walid Hamidi',        '+213 555 220 007', 'intern', TRUE),
    ('intern8@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Sarra Lounis',        '+213 555 220 008', 'intern', TRUE),
    ('intern9@gmail.com',  '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Adel Brahimi',        '+213 555 220 009', 'intern', TRUE),
    ('intern10@gmail.com', '$2y$10$QuyQRMAfK2BUFmoW2iFPnOocLbSy2bFqgzG/OUiYgvRVKJ2kxs8Aq', 'Yasmine Khellaf',     '+213 555 220 010', 'intern', TRUE)
ON CONFLICT (email) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        role      = EXCLUDED.role,
        is_active = EXCLUDED.is_active;

-- ──────────────────────────────────────────────────────────────────
-- 3. Intern profile rows (linked to user, assigned to a mentor, given
--    a specialization / department / start date / status). Mentor
--    distribution: mentor1 ← interns 1-4, mentor2 ← interns 5-7,
--    mentor3 ← interns 8-10.
-- ──────────────────────────────────────────────────────────────────
WITH intern_data (email, student_id, university, specialization, department, mentor_email) AS (
    VALUES
        ('intern1@gmail.com',  'STU-2026-001', 'University of Algiers',     'Software Engineering',   'Computer Science',     'mentor1@gmail.com'),
        ('intern2@gmail.com',  'STU-2026-002', 'University of Algiers',     'Cybersecurity',          'Computer Science',     'mentor1@gmail.com'),
        ('intern3@gmail.com',  'STU-2026-003', 'USTHB',                     'Data Science',           'Computer Science',     'mentor1@gmail.com'),
        ('intern4@gmail.com',  'STU-2026-004', 'USTHB',                     'Network Engineering',    'Networks & Telecoms',  'mentor1@gmail.com'),
        ('intern5@gmail.com',  'STU-2026-005', 'University of Constantine', 'Mobile Development',     'Software Engineering', 'mentor2@gmail.com'),
        ('intern6@gmail.com',  'STU-2026-006', 'University of Oran',        'Web Development',        'Software Engineering', 'mentor2@gmail.com'),
        ('intern7@gmail.com',  'STU-2026-007', 'University of Oran',        'Cloud Computing',        'Cloud & DevOps',       'mentor2@gmail.com'),
        ('intern8@gmail.com',  'STU-2026-008', 'University of Tlemcen',     'AI / Machine Learning',  'Data & AI',            'mentor3@gmail.com'),
        ('intern9@gmail.com',  'STU-2026-009', 'University of Bejaia',      'DevOps Engineering',     'Cloud & DevOps',       'mentor3@gmail.com'),
        ('intern10@gmail.com', 'STU-2026-010', 'University of Annaba',      'UI/UX Design',           'Design',               'mentor3@gmail.com')
)
INSERT INTO interns (
    user_id, student_id, university, specialization, department,
    mentor_id, status, start_date, end_date
)
SELECT
    u.id,
    d.student_id,
    d.university,
    d.specialization,
    d.department,
    m.id,
    'active',
    CURRENT_DATE - INTERVAL '21 days',
    CURRENT_DATE + INTERVAL '70 days'
FROM intern_data d
JOIN users u  ON u.email = d.email
JOIN users m  ON m.email = d.mentor_email
ON CONFLICT (user_id) DO UPDATE
    SET student_id     = EXCLUDED.student_id,
        university     = EXCLUDED.university,
        specialization = EXCLUDED.specialization,
        department     = EXCLUDED.department,
        mentor_id      = EXCLUDED.mentor_id,
        status         = EXCLUDED.status,
        start_date     = EXCLUDED.start_date,
        end_date       = EXCLUDED.end_date;

-- ──────────────────────────────────────────────────────────────────
-- 4. Past-week attendance per intern. Each intern gets 7 rows for the
--    last 7 calendar days, with a varied status mix so the weekly
--    matrix and analytics screens have something realistic to show.
-- ──────────────────────────────────────────────────────────────────
INSERT INTO attendance (intern_id, mentor_id, attendance_date, status, notes)
SELECT
    i.id,
    i.mentor_id,
    CURRENT_DATE - g.offset_days,
    -- Deterministic but uneven distribution per intern × day so the
    -- demo doesn't look identical for every user.
    CASE ((row_number() OVER (PARTITION BY i.id ORDER BY g.offset_days)
           + abs(hashtext(i.student_id))) % 10)
        WHEN 0 THEN 'absent'
        WHEN 1 THEN 'late'
        WHEN 2 THEN 'justified'
        ELSE        'present'
    END,
    'Seeded demo data'
FROM interns i
CROSS JOIN (
    SELECT generate_series(1, 7) AS offset_days
) g
WHERE i.mentor_id IS NOT NULL
ON CONFLICT (intern_id, attendance_date) DO UPDATE
    SET status    = EXCLUDED.status,
        mentor_id = EXCLUDED.mentor_id,
        notes     = EXCLUDED.notes;

COMMIT;

-- Quick sanity-check queries you can run after the seed:
--   SELECT email, role FROM users WHERE email LIKE 'mentor%@gmail.com' OR email LIKE 'intern%@gmail.com' ORDER BY role, email;
--   SELECT u.email, i.specialization, m.email AS mentor FROM interns i JOIN users u ON u.id = i.user_id LEFT JOIN users m ON m.id = i.mentor_id ORDER BY u.email;
--   SELECT u.email, COUNT(*) FILTER (WHERE a.status = 'present') AS present_days FROM attendance a JOIN interns i ON i.id = a.intern_id JOIN users u ON u.id = i.user_id GROUP BY u.email ORDER BY u.email;
