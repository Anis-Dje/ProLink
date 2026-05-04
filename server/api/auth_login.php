<?php
// POST /api/auth/login

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$body = pro_link_read_json();
$email = strtolower(trim($body['email'] ?? ''));
$password = $body['password'] ?? '';
if ($email === '' || $password === '') {
    pro_link_fail(400, 'missing_fields', 'email and password are required.');
}

$pdo = pro_link_pdo();
$stmt = $pdo->prepare('SELECT id, email, password_hash, full_name, phone, role,
                              is_active, must_change_password,
                              profile_photo_url, specialization, created_at
                         FROM users WHERE email = :e');
$stmt->execute([':e' => $email]);
$row = $stmt->fetch();
if (!$row || !password_verify($password, $row['password_hash'])) {
    pro_link_fail(401, 'invalid_credentials', 'Email or password is incorrect.');
}
if (!$row['is_active']) {
    pro_link_fail(403, 'account_disabled', 'Account has been disabled.');
}

// Interns must be approved by an admin before they can log in. Pending /
// rejected accounts get a clear 403 so the Flutter client can show a
// dedicated message instead of the generic "invalid credentials" toast.
if ($row['role'] === 'intern') {
    $iStmt = $pdo->prepare('SELECT status, rejection_reason
                              FROM interns WHERE user_id = :u');
    $iStmt->execute([':u' => $row['id']]);
    $intern = $iStmt->fetch();
    if ($intern) {
        $status = $intern['status'] ?? 'pending';
        if ($status === 'pending') {
            pro_link_fail(403, 'account_pending',
                'Your account is awaiting admin approval. You will be able to log in once approved.');
        }
        if ($status === 'rejected') {
            $reason = trim($intern['rejection_reason'] ?? '');
            pro_link_fail(403, 'account_rejected',
                $reason !== ''
                    ? 'Your registration was rejected: ' . $reason
                    : 'Your registration was rejected by the administrator.');
        }
    }
}

$token = pro_link_new_token();
$pdo->prepare('UPDATE users SET session_token = :t WHERE id = :id')
    ->execute([':t' => $token, ':id' => $row['id']]);

pro_link_ok([
    'token' => $token,
    'user' => pro_link_user_to_json($row),
]);
