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
                              is_active, profile_photo_url, created_at
                         FROM users WHERE email = :e');
$stmt->execute([':e' => $email]);
$row = $stmt->fetch();
if (!$row || !password_verify($password, $row['password_hash'])) {
    pro_link_fail(401, 'invalid_credentials', 'Email or password is incorrect.');
}
if (!$row['is_active']) {
    pro_link_fail(403, 'account_disabled', 'Account has been disabled.');
}

$token = pro_link_new_token();
$pdo->prepare('UPDATE users SET session_token = :t WHERE id = :id')
    ->execute([':t' => $token, ':id' => $row['id']]);

pro_link_ok([
    'token' => $token,
    'user' => pro_link_user_to_json($row),
]);
