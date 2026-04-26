<?php
// GET  /api/evaluations/        — list (optional ?internId= or ?mentorId=)
// POST /api/evaluations/        — mentor creates an evaluation

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $sql = 'SELECT * FROM evaluations';
    $where = [];
    $params = [];
    if (!empty($_GET['internId'])) {
        $where[] = 'intern_id = :iid';
        $params[':iid'] = $_GET['internId'];
    }
    if (!empty($_GET['mentorId'])) {
        $where[] = 'mentor_id = :mid';
        $params[':mid'] = $_GET['mentorId'];
    }
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= ' ORDER BY evaluation_date DESC, created_at DESC';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['criteria'] = json_decode($r['criteria'] ?? '{}', true) ?: [];
        $r['evaluationDate'] = pro_link_iso($r['evaluation_date'] . ' 00:00:00');
        $r['overallScore'] = (float)$r['overall_score'];
        $r['internId'] = $r['intern_id'];
        $r['mentorId'] = $r['mentor_id'];
        $r['createdAt'] = pro_link_iso($r['created_at']);
    }
    pro_link_ok(['evaluations' => $rows]);
}

if ($method === 'POST') {
    pro_link_require_role($me, 'mentor', 'admin');
    $body = pro_link_read_json();
    $internId = $body['internId'] ?? '';
    if ($internId === '') {
        pro_link_fail(400, 'missing_fields', 'internId is required.');
    }
    $criteria = json_encode($body['criteria'] ?? []);
    $ins = $pdo->prepare('INSERT INTO evaluations
        (intern_id, mentor_id, title, description, criteria,
         overall_score, comment, evaluation_date)
        VALUES (:i, :m, :t, :d, :c::jsonb, :s, :co, COALESCE(:ed::date, CURRENT_DATE))
        RETURNING *');
    $ins->execute([
        ':i' => $internId,
        ':m' => $me['id'],
        ':t' => $body['title'] ?? '',
        ':d' => $body['description'] ?? '',
        ':c' => $criteria,
        ':s' => $body['overallScore'] ?? 0,
        ':co' => $body['comment'] ?? '',
        ':ed' => $body['evaluationDate'] ?? null,
    ]);
    $r = $ins->fetch();
    $r['criteria'] = json_decode($r['criteria'], true) ?: [];
    $r['evaluationDate'] = pro_link_iso($r['evaluation_date'] . ' 00:00:00');
    $r['overallScore'] = (float)$r['overall_score'];
    $r['internId'] = $r['intern_id'];
    $r['mentorId'] = $r['mentor_id'];
    $r['createdAt'] = pro_link_iso($r['created_at']);
    pro_link_ok(['evaluation' => $r], 201);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or POST.');
