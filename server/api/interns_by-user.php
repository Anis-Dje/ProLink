<?php
// GET /api/interns/by-user/<userId>

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('GET');

$pdo = pro_link_pdo();
pro_link_current_user($pdo);

$userId = $_GET['id'] ?? '';
if ($userId === '') pro_link_fail(400, 'missing_id', 'User id required.');
$stmt = $pdo->prepare('SELECT i.*, u.full_name, u.email, u.profile_photo_url,
                              u.is_active AS user_is_active
                         FROM interns i JOIN users u ON u.id = i.user_id
                        WHERE i.user_id = :uid');
$stmt->execute([':uid' => $userId]);
$row = $stmt->fetch();
if (!$row) pro_link_fail(404, 'not_found', 'Intern not found for user.');
pro_link_ok(['intern' => pro_link_intern_to_json($row)]);
