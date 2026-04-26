<?php
// POST /api/users/<id>/active   body: {"isActive": true|false}
// Admin-only toggle for disabling/re-enabling an account.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
pro_link_require_role($me, 'admin');

$id = $_GET['id'] ?? '';
if ($id === '') {
    pro_link_fail(400, 'missing_id', 'User id is required in the URL.');
}
$body = pro_link_read_json();
if (!array_key_exists('isActive', $body)) {
    pro_link_fail(400, 'missing_fields', 'isActive is required.');
}
$isActive = (bool)$body['isActive'];

// PDOStatement::execute(array) binds every value as PARAM_STR, which
// turns PHP `false` into the empty string '' — Postgres then rejects
// it with "invalid input syntax for type boolean". Bind the value
// explicitly as PARAM_BOOL via bindValue() instead.
$stmt = $pdo->prepare('UPDATE users SET is_active = :a
                        WHERE id = :id
                        RETURNING id, email, full_name, phone, role,
                                  is_active, profile_photo_url, created_at');
$stmt->bindValue(':a', $isActive, PDO::PARAM_BOOL);
$stmt->bindValue(':id', $id);
$stmt->execute();
$row = $stmt->fetch();
if (!$row) {
    pro_link_fail(404, 'not_found', 'User not found.');
}
pro_link_ok(['user' => pro_link_user_to_json($row)]);
