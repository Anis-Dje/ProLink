<?php
// GET   /api/notifications/         — current user's notifications
// PATCH /api/notifications/<id>     — body: {"isRead": true}
// POST  /api/notifications/read-all — mark every notification of the current user as read

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// /api/notifications/<id> hits this file too — `id` is set on the GET
// superglobal by the router. /api/notifications/read-all turns into
// $_GET['action']='read-all' through the same router, but read-all
// includes a hyphen so the router routes it to a separate file. We
// handle both forms here for robustness.
$id = $_GET['id'] ?? '';

if ($method === 'GET' && $id === '') {
    $stmt = $pdo->prepare('SELECT * FROM notifications
                            WHERE user_id = :u
                            ORDER BY created_at DESC');
    $stmt->execute([':u' => $me['id']]);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['userId'] = $r['user_id'];
        $r['isRead'] = (bool)$r['is_read'];
        $r['createdAt'] = pro_link_iso($r['created_at']);
    }
    pro_link_ok(['notifications' => $rows]);
}

if (($method === 'PATCH' || $method === 'POST') && $id !== '') {
    $body = pro_link_read_json();
    $isRead = (bool)($body['isRead'] ?? true);
    $stmt = $pdo->prepare('UPDATE notifications
                              SET is_read = :r
                            WHERE id = :id AND user_id = :u
                            RETURNING *');
    // PDOStatement::execute(array) binds every value as PARAM_STR, which
    // turns PHP `false` into '' and Postgres rejects '' for BOOLEAN
    // columns. Bind the boolean explicitly via PARAM_BOOL.
    $stmt->bindValue(':r', $isRead, PDO::PARAM_BOOL);
    $stmt->bindValue(':id', $id);
    $stmt->bindValue(':u', $me['id']);
    $stmt->execute();
    $r = $stmt->fetch();
    if (!$r) pro_link_fail(404, 'not_found', 'Notification not found.');
    $r['userId'] = $r['user_id'];
    $r['isRead'] = (bool)$r['is_read'];
    $r['createdAt'] = pro_link_iso($r['created_at']);
    pro_link_ok(['notification' => $r]);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET, or PATCH /api/notifications/<id>.');
