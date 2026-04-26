<?php
// POST /api/interns/assign/<internId>  body: {"mentorId":"...","department":"..."}

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
pro_link_require_role($me, 'admin');

$id = $_GET['id'] ?? '';
$body = pro_link_read_json();
$mentorId = $body['mentorId'] ?? null;
$department = $body['department'] ?? null;
if ($id === '') pro_link_fail(400, 'missing_id', 'Intern id required.');

$stmt = $pdo->prepare('UPDATE interns
                          SET mentor_id = :m,
                              department = COALESCE(:d, department)
                        WHERE id = :id RETURNING *');
$stmt->execute([':m' => $mentorId, ':d' => $department, ':id' => $id]);
$row = $stmt->fetch();
if (!$row) pro_link_fail(404, 'not_found', 'Intern not found.');
$join = $pdo->prepare('SELECT full_name, email, profile_photo_url FROM users WHERE id = :u');
$join->execute([':u' => $row['user_id']]);
$row += $join->fetch();
pro_link_ok(['intern' => pro_link_intern_to_json($row)]);
