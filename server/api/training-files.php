<?php
// GET  /api/training-files/   — list training modules / resources
// POST /api/training-files/   — mentor/admin publishes a resource

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
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
    pro_link_ok(['trainingFile' => $r], 201);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or POST.');
