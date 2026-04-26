<?php
// GET  /api/attendance/   — list (?internId=&mentorId=&from=&to=)
// POST /api/attendance/   — mentor records one day's attendance

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $sql = 'SELECT * FROM attendance';
    $where = [];
    $params = [];
    foreach (['internId' => 'intern_id', 'mentorId' => 'mentor_id'] as $k => $c) {
        if (!empty($_GET[$k])) {
            $where[] = "$c = :$c";
            $params[":$c"] = $_GET[$k];
        }
    }
    if (!empty($_GET['from'])) {
        $where[] = 'attendance_date >= :from';
        $params[':from'] = $_GET['from'];
    }
    if (!empty($_GET['to'])) {
        $where[] = 'attendance_date <= :to';
        $params[':to'] = $_GET['to'];
    }
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= ' ORDER BY attendance_date DESC';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['internId'] = $r['intern_id'];
        $r['mentorId'] = $r['mentor_id'];
        // Flutter AttendanceModel.fromJson reads `date`; keep both for
        // forward compatibility.
        $iso = pro_link_iso($r['attendance_date'] . ' 00:00:00');
        $r['attendanceDate'] = $iso;
        $r['date'] = $iso;
        $r['createdAt'] = pro_link_iso($r['created_at']);
    }
    pro_link_ok(['attendance' => $rows]);
}

if ($method === 'POST') {
    pro_link_require_role($me, 'mentor', 'admin');
    $body = pro_link_read_json();
    $internId = $body['internId'] ?? '';
    // Flutter sends `date`; accept `attendanceDate` too.
    $date = $body['date'] ?? ($body['attendanceDate'] ?? '');
    $status = $body['status'] ?? '';
    if ($internId === '' || $date === '' || $status === '') {
        pro_link_fail(400, 'missing_fields',
            'internId, date, status are required.');
    }
    $sql = 'INSERT INTO attendance
        (intern_id, mentor_id, attendance_date, status, notes)
        VALUES (:i, :m, :d::date, :s, :n)
        ON CONFLICT (intern_id, attendance_date)
        DO UPDATE SET status = EXCLUDED.status, notes = EXCLUDED.notes,
                      mentor_id = EXCLUDED.mentor_id
        RETURNING *';
    $ins = $pdo->prepare($sql);
    $ins->execute([
        ':i' => $internId,
        ':m' => $me['id'],
        ':d' => $date,
        ':s' => $status,
        ':n' => $body['notes'] ?? '',
    ]);
    $r = $ins->fetch();
    $r['internId'] = $r['intern_id'];
    $r['mentorId'] = $r['mentor_id'];
    $iso = pro_link_iso($r['attendance_date'] . ' 00:00:00');
    $r['attendanceDate'] = $iso;
    $r['date'] = $iso;
    $r['createdAt'] = pro_link_iso($r['created_at']);
    pro_link_ok(['attendance' => $r], 201);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or POST.');
