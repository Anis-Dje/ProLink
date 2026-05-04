<?php
// GET  /api/users/      — list users (admin only), optional ?role=intern|mentor|admin
// POST /api/users/      — admin creates a mentor or admin account

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
require_once __DIR__ . '/../lib/notifications.php';
pro_link_bootstrap();

$pdo = pro_link_pdo();
$me = pro_link_current_user($pdo);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    $role = $_GET['role'] ?? '';
    $sql = 'SELECT id, email, full_name, phone, role, is_active,
                   must_change_password, profile_photo_url, specialization,
                   created_at
              FROM users';
    $params = [];
    if ($role !== '') {
        $sql .= ' WHERE role = :r';
        $params[':r'] = $role;
    }
    $sql .= ' ORDER BY created_at DESC';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $users = array_map('pro_link_user_to_json', $stmt->fetchAll());
    pro_link_ok(['users' => $users]);
}

if ($method === 'POST') {
    pro_link_require_role($me, 'admin');
    $body = pro_link_read_json();
    $email = strtolower(trim($body['email'] ?? ''));
    $password = $body['password'] ?? '';
    $fullName = trim($body['fullName'] ?? '');
    $phone = trim($body['phone'] ?? '');
    $role = $body['role'] ?? '';
    // Optional for admin accounts; required (and meaningful) for mentors so
    // they can be matched against an intern's specialization at assignment
    // time.
    $specialization = trim((string)($body['specialization'] ?? ''));
    if (!in_array($role, ['admin', 'mentor'], true)) {
        pro_link_fail(400, 'invalid_role',
            'Role must be "admin" or "mentor" on this endpoint.');
    }
    if ($email === '' || $password === '' || $fullName === '') {
        pro_link_fail(400, 'missing_fields',
            'email, password, fullName required.');
    }
    if (strlen($password) < 6) {
        pro_link_fail(400, 'weak_password', 'Password must be at least 6 characters.');
    }
    $exists = $pdo->prepare('SELECT 1 FROM users WHERE email = :e');
    $exists->execute([':e' => $email]);
    if ($exists->fetch()) {
        pro_link_fail(409, 'email_in_use', 'Email already registered.');
    }
    // Admin-created accounts always get a temporary password — flag the
    // user so the Flutter client forces a password change on first login.
    $ins = $pdo->prepare('INSERT INTO users
        (email, password_hash, full_name, phone, role, specialization, must_change_password)
        VALUES (:e, :h, :n, :p, :r, :s, TRUE)
        RETURNING id, email, full_name, phone, role, is_active,
                  must_change_password, profile_photo_url, specialization,
                  created_at');
    $ins->execute([
        ':e' => $email,
        ':h' => password_hash($password, PASSWORD_BCRYPT),
        ':n' => $fullName,
        ':p' => $phone,
        ':r' => $role,
        ':s' => $specialization,
    ]);
    $newUser = $ins->fetch();
    pro_link_ok(['user' => pro_link_user_to_json($newUser)], 201);
}

pro_link_fail(405, 'method_not_allowed', 'Use GET or POST.');
