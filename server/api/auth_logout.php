<?php
// POST /api/auth/logout

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
$user = pro_link_current_user($pdo);
$pdo->prepare('UPDATE users SET session_token = NULL WHERE id = :id')
    ->execute([':id' => $user['id']]);
pro_link_ok(['ok' => true]);
