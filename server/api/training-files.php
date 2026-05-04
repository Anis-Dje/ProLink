<?php
// GET  /api/training-files/   — list training modules / resources
// POST /api/training-files/   — mentor/admin publishes a resource
//
// Visibility rules (issue: mentor materials should be private to that
// mentor's interns):
//   * admin-uploaded files (is_admin_uploaded=TRUE) are visible to
//     everybody.
//   * mentor-uploaded files (is_admin_uploaded=FALSE) are only visible
//     to:
//       - the uploading mentor themselves,
//       - any intern whose interns.mentor_id matches the uploader,
//       - any admin (so the admin can audit / delete).
// Mentor uploads are also implicitly tagged with the mentor's
// specialization (via the uploader's user row) — that's how interns
// see "their mentor's" documents and not other mentors'.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
require_once __DIR__ . '/../lib/notifications.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $sql = 'SELECT * FROM training_files';
    $where = [];
    $params = [];

    if ($me['role'] === 'intern') {
        // Find this intern's mentor (if any). Always include admin
        // uploads; include mentor's uploads only if a mentor is set.
        $mentorIdStmt = $pdo->prepare(
            'SELECT mentor_id FROM interns WHERE user_id = :u');
        $mentorIdStmt->execute([':u' => $me['id']]);
        $mentorId = $mentorIdStmt->fetchColumn();
        if ($mentorId) {
            $where[] = '(is_admin_uploaded = TRUE OR uploaded_by = :mid)';
            $params[':mid'] = $mentorId;
        } else {
            $where[] = 'is_admin_uploaded = TRUE';
        }
    } elseif ($me['role'] === 'mentor') {
        // Mentor sees admin uploads + their own.
        $where[] = '(is_admin_uploaded = TRUE OR uploaded_by = :me)';
        $params[':me'] = $me['id'];
    }
    // Admin: no scope filter — full visibility.

    if (!empty($_GET['q'])) {
        $where[] = '(title ILIKE :q OR description ILIKE :q)';
        $params[':q'] = '%' . $_GET['q'] . '%';
    }
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= ' ORDER BY upload_date DESC';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['fileUrl'] = $r['file_url'];
        $r['fileType'] = $r['file_type'];
        $r['uploadedBy'] = $r['uploaded_by'];
        $r['uploadDate'] = pro_link_iso($r['upload_date']);
        $r['isAdminUploaded'] = (bool)($r['is_admin_uploaded'] ?? false);
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
    $isAdmin = $me['role'] === 'admin';
    $ins = $pdo->prepare('INSERT INTO training_files
        (title, description, file_url, file_type, uploaded_by, tags,
         is_admin_uploaded)
        VALUES (:t, :d, :f, :ft, :u, :tg, :ia) RETURNING *');
    $ins->bindValue(':t', $body['title']);
    $ins->bindValue(':d', $body['description'] ?? '');
    $ins->bindValue(':f', $body['fileUrl']);
    $ins->bindValue(':ft', $body['fileType'] ?? '');
    $ins->bindValue(':u', $me['id']);
    $ins->bindValue(':tg', $tagsArr);
    $ins->bindValue(':ia', $isAdmin, PDO::PARAM_BOOL);
    $ins->execute();
    $r = $ins->fetch();
    $r['fileUrl'] = $r['file_url'];
    $r['fileType'] = $r['file_type'];
    $r['uploadedBy'] = $r['uploaded_by'];
    $r['uploadDate'] = pro_link_iso($r['upload_date']);
    $r['isAdminUploaded'] = (bool)($r['is_admin_uploaded'] ?? false);
    $t = $r['tags'] ?? '{}';
    if (is_string($t)) {
        $t = trim($t, '{}');
        $r['tags'] = $t === '' ? [] :
            array_map(fn($x) => trim($x, '"'), str_getcsv($t));
    }

    // Notification fan-out follows the same scoping rules as the GET
    // visibility filter so we don't ping interns who can't see the file.
    $title = (string)$body['title'];
    if ($isAdmin) {
        // Admin uploads are visible to everyone — notify every intern
        // and every mentor.
        pro_link_notify_role($pdo, 'intern',
            'New training material',
            '"' . $title . '" was added to your training materials.',
            'training');
        pro_link_notify_role($pdo, 'mentor',
            'New training material',
            '"' . $title . '" was added to your training materials.',
            'training');
    } else {
        // Mentor uploads are private to that mentor's assigned interns.
        $stmt = $pdo->prepare('SELECT user_id FROM interns
                                WHERE mentor_id = :m');
        $stmt->execute([':m' => $me['id']]);
        foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $uid) {
            pro_link_notify($pdo, (string)$uid,
                'New training material',
                '"' . $title . '" was added by your mentor.',
                'training');
        }
    }

    pro_link_ok(['trainingFile' => $r], 201);
}

if ($method === 'DELETE') {
    // /api/training-files/<id>
    //   * admin can delete any row
    //   * mentor can delete only rows they uploaded
    //   * intern: forbidden
    pro_link_require_role($me, 'mentor', 'admin');
    $id = $_GET['id'] ?? '';
    if ($id === '') {
        pro_link_fail(400, 'missing_id', 'Training file id is required.');
    }

    $sel = $pdo->prepare(
        'SELECT id, file_url, uploaded_by FROM training_files WHERE id = :id');
    $sel->execute([':id' => $id]);
    $row = $sel->fetch();
    if (!$row) {
        pro_link_fail(404, 'not_found', 'Training file not found.');
    }
    if ($me['role'] !== 'admin' && (string)$row['uploaded_by'] !== (string)$me['id']) {
        // Mentors cannot delete another mentor's (or admin's) materials.
        pro_link_fail(403, 'forbidden',
            'You can only delete training materials you uploaded.');
    }

    $del = $pdo->prepare('DELETE FROM training_files WHERE id = :id');
    $del->execute([':id' => $id]);

    // Best-effort cleanup of the underlying upload on disk. The
    // canonical URL shape is /files/<uuid>.<ext>; anything else (eg. an
    // external Drive / YouTube link the mentor pasted via the URL flow)
    // is left alone since we don't own that storage.
    $url = (string)($row['file_url'] ?? '');
    if (preg_match('#/files/([A-Za-z0-9._-]+)$#', $url, $m)) {
        $path = __DIR__ . '/../uploads/' . $m[1];
        if (is_file($path)) @unlink($path);
    }

    pro_link_ok(['deleted' => $id]);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET, POST or DELETE.');
