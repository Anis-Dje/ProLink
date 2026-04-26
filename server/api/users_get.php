<?php
// GET    /api/users/<id>  — fetch a user by id
// PATCH  /api/users/<id>  — update full_name / phone / profile_photo_url

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$id = $_GET['id'] ?? '';
if ($id === '') {
    pro_link_fail(400, 'missing_id', 'User id is required in the URL.');
}

if ($method === 'GET') {
    $stmt = $pdo->prepare('SELECT id, email, full_name, phone, role, is_active,
                                  profile_photo_url, created_at
                             FROM users WHERE id = :id');
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch();
    if (!$row) pro_link_fail(404, 'not_found', 'User not found.');
    pro_link_ok(['user' => pro_link_user_to_json($row)]);
}

if ($method === 'PATCH') {
    if ($me['id'] !== $id && $me['role'] !== 'admin') {
        pro_link_fail(403, 'forbidden', 'You can only edit your own profile.');
    }
    $body = pro_link_read_json();
    $sets = [];
    $params = [':id' => $id];
    foreach (['fullName' => 'full_name',
              'phone' => 'phone',
              'profilePhotoUrl' => 'profile_photo_url'] as $api => $col) {
        if (array_key_exists($api, $body)) {
            $sets[] = "$col = :$col";
            $params[":$col"] = $body[$api];
        }
    }
    if (!$sets) pro_link_ok(['user' => pro_link_user_to_json($me)]);
    $sql = 'UPDATE users SET ' . implode(', ', $sets) .
        ' WHERE id = :id
           RETURNING id, email, full_name, phone, role, is_active,
                     profile_photo_url, created_at';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $row = $stmt->fetch();
    if (!$row) pro_link_fail(404, 'not_found', 'User not found.');
    pro_link_ok(['user' => pro_link_user_to_json($row)]);
}

if ($method === 'POST' && ($_GET['action'] ?? '') === 'active') {
    // Placeholder for POST /api/users/<id>/active handled by users_active.php.
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or PATCH.');
