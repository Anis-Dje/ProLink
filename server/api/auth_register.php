<?php
// POST /api/auth/register  — self-service intern signup.
//
// Newly registered interns are created with status = 'pending' and are
// NOT issued a session token. They cannot log in until an admin approves
// the registration. Every active admin receives a notification so the
// approval queue is surfaced in the bell icon on their dashboard.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
require_once __DIR__ . '/../lib/notifications.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$body = pro_link_read_json();
$email = strtolower(trim($body['email'] ?? ''));
$password = $body['password'] ?? '';
$fullName = trim($body['fullName'] ?? '');
$phone = trim($body['phone'] ?? '');
$studentId = trim($body['studentId'] ?? '');
$university = trim($body['university'] ?? '');
$specialization = trim($body['specialization'] ?? '');
$department = trim($body['department'] ?? '');
$profilePhotoUrl = trim($body['profilePhotoUrl'] ?? '');

if ($email === '' || $password === '' || $fullName === '' || $studentId === '') {
    pro_link_fail(400, 'missing_fields',
        'email, password, fullName and studentId are required.');
}
if (strlen($password) < 6) {
    pro_link_fail(400, 'weak_password', 'Password must be at least 6 characters.');
}

$pdo = pro_link_pdo();
$exists = $pdo->prepare('SELECT 1 FROM users WHERE email = :e');
$exists->execute([':e' => $email]);
if ($exists->fetch()) {
    pro_link_fail(409, 'email_in_use', 'Email already registered.');
}

$hash = password_hash($password, PASSWORD_BCRYPT);

$pdo->beginTransaction();
try {
    $ins = $pdo->prepare('INSERT INTO users
        (email, password_hash, full_name, phone, role, profile_photo_url)
        VALUES (:e, :h, :n, :p, :r, :u)
        RETURNING id, email, full_name, phone, role, is_active,
                  must_change_password, profile_photo_url, created_at');
    $ins->execute([
        ':e' => $email,
        ':h' => $hash,
        ':n' => $fullName,
        ':p' => $phone,
        ':r' => 'intern',
        ':u' => $profilePhotoUrl !== '' ? $profilePhotoUrl : null,
    ]);
    $userRow = $ins->fetch();
    $userId = $userRow['id'];

    // status defaults to 'pending' on the column.
    $pdo->prepare('INSERT INTO interns
        (user_id, student_id, university, specialization, department)
        VALUES (:u, :s, :un, :sp, :d)')
        ->execute([
            ':u' => $userId,
            ':s' => $studentId,
            ':un' => $university,
            ':sp' => $specialization,
            ':d' => $department,
        ]);
    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;
}

// Notify every admin that a new intern is awaiting approval.
pro_link_notify_role(
    $pdo,
    'admin',
    'New intern registration',
    $fullName . ' (' . $email . ') registered and is awaiting your approval.',
    'intern_pending'
);

// No token: the intern must wait for admin approval and then log in.
pro_link_ok([
    'pending' => true,
    'message' => 'Your registration was received and is awaiting admin approval. '
        . 'You will be able to log in as soon as the administrator approves your account.',
    'user' => pro_link_user_to_json($userRow),
], 201);
