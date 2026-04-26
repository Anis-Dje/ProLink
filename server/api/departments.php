<?php
// GET  /api/departments/   — list all departments
// POST /api/departments/   — admin creates a department

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

function pro_link_department_to_json(array $r): array {
    return [
        'id' => $r['id'],
        'name' => $r['name'],
        'description' => $r['description'] ?? '',
        'createdAt' => pro_link_iso($r['created_at'] ?? null),
    ];
}

if ($method === 'GET') {
    $stmt = $pdo->query('SELECT * FROM departments ORDER BY name ASC');
    $rows = array_map('pro_link_department_to_json', $stmt->fetchAll());
    pro_link_ok(['departments' => $rows]);
}

if ($method === 'POST') {
    pro_link_require_role($me, 'admin');
    $body = pro_link_read_json();
    $name = trim($body['name'] ?? '');
    if ($name === '') {
        pro_link_fail(400, 'missing_fields', 'name is required.');
    }
    $ins = $pdo->prepare('INSERT INTO departments (name, description)
                               VALUES (:n, :d) RETURNING *');
    $ins->execute([':n' => $name, ':d' => $body['description'] ?? '']);
    $row = $ins->fetch();
    pro_link_ok(['department' => pro_link_department_to_json($row)], 201);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or POST.');
