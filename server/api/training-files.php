<?php
// GET    /api/training-files/        — list training modules / resources
// POST   /api/training-files/        — mentor/admin publishes a resource
// DELETE /api/training-files/<id>    — uploader (or admin) removes a resource

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
require_once __DIR__ . '/../lib/notifications.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $sql = 'SELECT * FROM training_files';
    $params = [];
    if (!empty($_GET['q'])) {
        $sql .= ' WHERE title ILIKE :q OR description ILIKE :q';
        $params[':q'] = '%' . $_GET['q'] . '%';
    }
    $sql .= ' ORDER BY upload_date DESC';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['fileUrl'] = $r['file_url'];
        $r['fileType'] = $r['file_type'];
        $r['uploadedBy'] = $r['uploaded_by'];
        $r['uploadDate'] = pro_link_iso($r['upload_date']);
        // Postgres TEXT[] comes back as "{a,b,c}" — parse into a JSON array.
        $t = $r['tags'] ?? '{}';
        if (is_string($t)) {
            $t = trim($t, '{}');
            $r['tags'] = $t === '' ? [] :
                array_map(fn($x) => trim($x, '"'), str_getcsv($t));
        }
    }
    pro_link_ok(['trainingFiles' => $rows]);
}

if ($method === 'POST') {
    pro_link_require_role($me, 'mentor', 'admin');
    $body = pro_link_read_json();
    if (($body['title'] ?? '') === '' || ($body['fileUrl'] ?? '') === '') {
        pro_link_fail(400, 'missing_fields', 'title and fileUrl are required.');
    }
    $tags = $body['tags'] ?? [];
    $tagsArr = '{' . implode(',', array_map(
        fn($t) => '"' . str_replace('"', '', $t) . '"', $tags)) . '}';
    $ins = $pdo->prepare('INSERT INTO training_files
        (title, description, file_url, file_type, uploaded_by, tags)
        VALUES (:t, :d, :f, :ft, :u, :tg) RETURNING *');
    $ins->execute([
        ':t' => $body['title'],
        ':d' => $body['description'] ?? '',
        ':f' => $body['fileUrl'],
        ':ft' => $body['fileType'] ?? '',
        ':u' => $me['id'],
        ':tg' => $tagsArr,
    ]);
    $r = $ins->fetch();
    $r['fileUrl'] = $r['file_url'];
    $r['fileType'] = $r['file_type'];
    $r['uploadedBy'] = $r['uploaded_by'];
    $r['uploadDate'] = pro_link_iso($r['upload_date']);
    $t = $r['tags'] ?? '{}';
    if (is_string($t)) {
        $t = trim($t, '{}');
        $r['tags'] = $t === '' ? [] :
            array_map(fn($x) => trim($x, '"'), str_getcsv($t));
    }

    // Tell every intern that a new resource is available. When an admin
    // uploads, also tell every mentor.
    $title = (string)$body['title'];
    pro_link_notify_role($pdo, 'intern',
        'New training material',
        '"' . $title . '" was added to your training materials.',
        'training');
    if ($me['role'] === 'admin') {
        pro_link_notify_role($pdo, 'mentor',
            'New training material',
            '"' . $title . '" was added to your training materials.',
            'training');
    }

    pro_link_ok(['trainingFile' => $r], 201);
}

if ($method === 'DELETE') {
    $id = $_GET['id'] ?? '';
    if ($id === '') {
        pro_link_fail(400, 'missing_id',
            'DELETE /api/training-files/<id> requires an id.');
    }
    $sel = $pdo->prepare('SELECT uploaded_by, file_url FROM training_files WHERE id = :id');
    $sel->execute([':id' => $id]);
    $row = $sel->fetch();
    if ($row === false) {
        pro_link_fail(404, 'not_found', 'No training file with that id.');
    }
    // Admins can delete anything; mentors only their own uploads.
    if ($me['role'] !== 'admin' && $row['uploaded_by'] !== $me['id']) {
        pro_link_fail(403, 'forbidden',
            'Only admins or the original uploader can delete this resource.');
    }
    $del = $pdo->prepare('DELETE FROM training_files WHERE id = :id');
    $del->execute([':id' => $id]);
    pro_link_delete_uploaded_file($row['file_url'] ?? '');
    pro_link_ok(['deleted' => $id]);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET, POST, or DELETE.');
