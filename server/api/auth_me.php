<?php
// GET /api/auth/me

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('GET');

$pdo = pro_link_pdo();
$user = pro_link_current_user($pdo);
pro_link_ok(['user' => pro_link_user_to_json($user)]);
