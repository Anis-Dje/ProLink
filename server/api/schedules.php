<?php
// GET    /api/schedules/        — list office schedules / timetables
// POST   /api/schedules/        — admin uploads a new schedule (already-uploaded file url)
// DELETE /api/schedules/<id>    — admin removes a schedule (and its uploaded file)

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
require_once __DIR__ . '/../lib/notifications.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $stmt = $pdo->query('SELECT * FROM schedules ORDER BY upload_date DESC');
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['fileUrl'] = $r['file_url'];
        $r['uploadedBy'] = $r['uploaded_by'];
        $r['weekLabel'] = $r['week_label'];
        $r['uploadDate'] = pro_link_iso($r['upload_date']);
    }
    pro_link_ok(['schedules' => $rows]);
}

if ($method === 'POST') {
    pro_link_require_role($me, 'admin');
    $body = pro_link_read_json();
    if (($body['title'] ?? '') === '' || ($body['fileUrl'] ?? '') === '') {
        pro_link_fail(400, 'missing_fields', 'title and fileUrl are required.');
    }
    $ins = $pdo->prepare('INSERT INTO schedules
        (title, description, file_url, uploaded_by, week_label)
        VALUES (:t, :d, :f, :u, :w) RETURNING *');
    $ins->execute([
        ':t' => $body['title'],
        ':d' => $body['description'] ?? '',
        ':f' => $body['fileUrl'],
        ':u' => $me['id'],
        ':w' => $body['weekLabel'] ?? '',
    ]);
    $r = $ins->fetch();
    $r['fileUrl'] = $r['file_url'];
    $r['uploadedBy'] = $r['uploaded_by'];
    $r['weekLabel'] = $r['week_label'];
    $r['uploadDate'] = pro_link_iso($r['upload_date']);

    // Notify every mentor and intern that a new schedule is available.
    $msg = 'A new schedule has been published'
        . ((string)($body['weekLabel'] ?? '') !== ''
            ? ' for ' . $body['weekLabel'] : '') . '.';
    pro_link_notify_role($pdo, 'mentor', 'New schedule', $msg, 'schedule');
    pro_link_notify_role($pdo, 'intern', 'New schedule', $msg, 'schedule');

    pro_link_ok(['schedule' => $r], 201);
}

if ($method === 'DELETE') {
    pro_link_require_role($me, 'admin');
    $id = $_GET['id'] ?? '';
    if ($id === '') {
        pro_link_fail(400, 'missing_id', 'DELETE /api/schedules/<id> requires an id.');
    }
    $sel = $pdo->prepare('SELECT file_url FROM schedules WHERE id = :id');
    $sel->execute([':id' => $id]);
    $row = $sel->fetch();
    if ($row === false) {
        pro_link_fail(404, 'not_found', 'No schedule with that id.');
    }
    $del = $pdo->prepare('DELETE FROM schedules WHERE id = :id');
    $del->execute([':id' => $id]);
    pro_link_delete_uploaded_file($row['file_url'] ?? '');
    pro_link_ok(['deleted' => $id]);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET, POST, or DELETE.');
