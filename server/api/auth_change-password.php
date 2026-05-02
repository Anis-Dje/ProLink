<?php
// POST /api/auth/change-password
// Body: {"currentPassword": "...", "newPassword": "..."}
//
// Authenticated endpoint. Verifies the current password, updates the
// hash, clears must_change_password, and rotates the session token so
// any other devices still holding the old token are forced to re-login.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);

$body = pro_link_read_json();
$current = $body['currentPassword'] ?? '';
$next = $body['newPassword'] ?? '';
if ($current === '' || $next === '') {
    pro_link_fail(400, 'missing_fields',
        'currentPassword and newPassword are required.');
}
if (strlen($next) < 6) {
    pro_link_fail(400, 'weak_password',
        'New password must be at least 6 characters.');
}
if ($current === $next) {
    pro_link_fail(400, 'same_password',
        'New password must be different from the current password.');
}

$row = $pdo->prepare('SELECT password_hash FROM users WHERE id = :id');
$row->execute([':id' => $me['id']]);
$hash = $row->fetchColumn();
if ($hash === false || !password_verify($current, $hash)) {
    pro_link_fail(401, 'invalid_credentials', 'Current password is incorrect.');
}

$newHash = password_hash($next, PASSWORD_BCRYPT);
$newToken = pro_link_new_token();
$pdo->prepare('UPDATE users
                  SET password_hash = :h,
                      must_change_password = FALSE,
                      session_token = :t
                WHERE id = :id')
    ->execute([':h' => $newHash, ':t' => $newToken, ':id' => $me['id']]);

// Re-fetch so the response carries the fresh must_change_password=false.
$me['must_change_password'] = false;
pro_link_ok([
    'token' => $newToken,
    'user' => pro_link_user_to_json($me),
]);
