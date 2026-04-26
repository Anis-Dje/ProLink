<?php
// GET  /api/notifications/           — current user's notifications

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('GET');

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
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
