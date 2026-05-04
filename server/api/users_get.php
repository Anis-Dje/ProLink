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
                                  profile_photo_url, specialization, created_at
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
              'profilePhotoUrl' => 'profile_photo_url',
              'specialization' => 'specialization'] as $api => $col) {
        if (array_key_exists($api, $body)) {
            // specialization gates mentor↔intern assignment eligibility
            // (see interns_assign.php + assign_intern_screen.dart). A
            // mentor self-editing it would let them slip into another
            // specialization's eligible list, so only admins may set it.
            if ($col === 'specialization' && $me['role'] !== 'admin') {
                continue;
            }
            $sets[] = "$col = :$col";
            $val = $body[$api];
            // Coalesce empty strings to NULL for profile_photo_url so the
            // Flutter "remove picture" flow can rely on a single null check.
            if ($col === 'profile_photo_url' && $val === '') {
                $val = null;
            }
            $params[":$col"] = $val;
        }
    }
    if (!$sets) pro_link_ok(['user' => pro_link_user_to_json($me)]);
    $sql = 'UPDATE users SET ' . implode(', ', $sets) .
        ' WHERE id = :id
           RETURNING id, email, full_name, phone, role, is_active,
                     profile_photo_url, specialization, created_at';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $row = $stmt->fetch();
    if (!$row) pro_link_fail(404, 'not_found', 'User not found.');
    pro_link_ok(['user' => pro_link_user_to_json($row)]);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or PATCH.');
