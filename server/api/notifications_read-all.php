<?php
// POST /api/notifications/read-all  — mark every notification of the
// current user as read.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$pdo->prepare('UPDATE notifications SET is_read = TRUE WHERE user_id = :u AND is_read = FALSE')
    ->execute([':u' => $me['id']]);

pro_link_ok(['ok' => true]);
