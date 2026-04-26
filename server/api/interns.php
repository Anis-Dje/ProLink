<?php
// GET /api/interns/ — list with optional filters
//   ?status=pending|approved|rejected
//   ?mentorId=<uuid>
//   ?q=<substring of name/student_id>

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('GET');

$pdo = pro_link_pdo();
pro_link_current_user($pdo);

$sql = 'SELECT i.*, u.full_name, u.email, u.profile_photo_url
          FROM interns i JOIN users u ON u.id = i.user_id';
$where = [];
$params = [];
if (!empty($_GET['status'])) {
    $where[] = 'i.status = :status';
    $params[':status'] = $_GET['status'];
}
if (!empty($_GET['mentorId'])) {
    $where[] = 'i.mentor_id = :mid';
    $params[':mid'] = $_GET['mentorId'];
}
if (!empty($_GET['department'])) {
    $where[] = 'i.department = :dept';
    $params[':dept'] = $_GET['department'];
}
if (!empty($_GET['q'])) {
    $where[] = '(u.full_name ILIKE :q OR i.student_id ILIKE :q)';
    $params[':q'] = '%' . $_GET['q'] . '%';
}
if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
$sql .= ' ORDER BY i.created_at DESC';

$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$rows = array_map('pro_link_intern_to_json', $stmt->fetchAll());
pro_link_ok(['interns' => $rows]);
