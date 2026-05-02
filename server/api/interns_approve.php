<?php
// POST /api/interns/approve/<internId>
//   body: {"startDate": "YYYY-MM-DD", "endDate": "YYYY-MM-DD"}

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
require_once __DIR__ . '/../lib/notifications.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
pro_link_require_role($me, 'admin');

$id = $_GET['id'] ?? '';
if ($id === '') pro_link_fail(400, 'missing_id', 'Intern id required.');
$body = pro_link_read_json();
$startDate = $body['startDate'] ?? null;
$endDate = $body['endDate'] ?? null;

$stmt = $pdo->prepare('UPDATE interns
                          SET status = :s,
                              rejection_reason = NULL,
                              start_date = COALESCE(:sd::DATE, start_date),
                              end_date = COALESCE(:ed::DATE, end_date)
                        WHERE id = :id
                        RETURNING *');
$stmt->execute([
    ':s' => 'active',
    ':sd' => $startDate,
    ':ed' => $endDate,
    ':id' => $id,
]);
$row = $stmt->fetch();
if (!$row) pro_link_fail(404, 'not_found', 'Intern not found.');

$join = $pdo->prepare('SELECT full_name, email, profile_photo_url
                         FROM users WHERE id = :u');
$join->execute([':u' => $row['user_id']]);
$row += $join->fetch();

// Notify the newly approved intern so they know they can now log in.
pro_link_notify(
    $pdo,
    (string)$row['user_id'],
    'Account approved',
    'Your Pro-Link account has been approved. You can now log in.',
    'approval'
);

pro_link_ok(['intern' => pro_link_intern_to_json($row)]);
