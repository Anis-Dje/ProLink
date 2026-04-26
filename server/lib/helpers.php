<?php
// Shared helpers used by every endpoint: JSON I/O, auth, error bodies.

// Always respond as JSON and enable CORS for the Flutter client (dev setup).
function pro_link_bootstrap(): void {
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Headers: Authorization, Content-Type');
    header('Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS');
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
    set_error_handler(function ($severity, $message, $file, $line) {
        throw new ErrorException($message, 0, $severity, $file, $line);
    });
    set_exception_handler(function (Throwable $e) {
        error_log('[pro-link] unhandled: ' . $e->getMessage() . "\n" .
            $e->getTraceAsString());
        // Generic message to the client so we never leak SQL strings / paths.
        pro_link_fail(500, 'internal_error', 'An unexpected error occurred.');
    });
}

function pro_link_require_method(string ...$methods): void {
    $m = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (!in_array($m, $methods, true)) {
        pro_link_fail(405, 'method_not_allowed',
            'Allowed methods: ' . implode(', ', $methods));
    }
}

function pro_link_read_json(): array {
    $raw = file_get_contents('php://input');
    if ($raw === '' || $raw === false) {
        return [];
    }
    try {
        $decoded = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
    } catch (Throwable $e) {
        pro_link_fail(400, 'invalid_json', 'Request body is not valid JSON.');
    }
    if (!is_array($decoded)) {
        pro_link_fail(400, 'invalid_json', 'Request body must be a JSON object.');
    }
    return $decoded;
}

function pro_link_ok(array $payload, int $status = 200): void {
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function pro_link_fail(int $status, string $code, string $message): void {
    http_response_code($status);
    echo json_encode(['error' => $code, 'message' => $message]);
    exit;
}

// Session tokens are random 64-char hex strings stored in users.session_token.
// No JWT (out of course scope): the client just sends this token back as the
// Authorization header. We trade complexity for something closer to the
// course's "read.php / write.php" style.
function pro_link_new_token(): string {
    return bin2hex(random_bytes(32));
}

function pro_link_current_user(PDO $pdo): array {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        $header = $headers['Authorization'] ?? ($headers['authorization'] ?? '');
    }
    if (stripos($header, 'Bearer ') !== 0) {
        pro_link_fail(401, 'missing_token', 'Authorization Bearer token required.');
    }
    $token = trim(substr($header, 7));
    if ($token === '') {
        pro_link_fail(401, 'missing_token', 'Authorization Bearer token required.');
    }
    $stmt = $pdo->prepare('SELECT id, email, full_name, phone, role, is_active,
                                  profile_photo_url, created_at
                             FROM users WHERE session_token = :t');
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch();
    if (!$row) {
        pro_link_fail(401, 'invalid_token', 'Token is invalid or expired.');
    }
    if (!$row['is_active']) {
        pro_link_fail(403, 'account_disabled', 'Account has been disabled.');
    }
    return $row;
}

function pro_link_require_role(array $user, string ...$roles): void {
    if (!in_array($user['role'], $roles, true)) {
        pro_link_fail(403, 'forbidden',
            'This endpoint is restricted to: ' . implode(', ', $roles));
    }
}

// Normalizes a DB row into the JSON shape the Flutter models expect.
function pro_link_user_to_json(array $row): array {
    return [
        'id' => $row['id'],
        'email' => $row['email'],
        'fullName' => $row['full_name'] ?? '',
        'phone' => $row['phone'] ?? '',
        'role' => $row['role'],
        'isActive' => (bool)$row['is_active'],
        'profilePhotoUrl' => $row['profile_photo_url'] ?? null,
        'createdAt' => pro_link_iso($row['created_at'] ?? null),
    ];
}

function pro_link_intern_to_json(array $row): array {
    // Flutter's InternModel.fromJson reads `registrationDate`; keep
    // `createdAt` too for any future consumers.
    $created = pro_link_iso($row['created_at'] ?? null);
    return [
        'id' => $row['id'],
        'userId' => $row['user_id'],
        'studentId' => $row['student_id'] ?? '',
        'university' => $row['university'] ?? '',
        'specialization' => $row['specialization'] ?? '',
        'department' => $row['department'] ?? '',
        'mentorId' => $row['mentor_id'] ?? null,
        'status' => $row['status'] ?? 'pending',
        'rejectionReason' => $row['rejection_reason'] ?? null,
        'startDate' => pro_link_iso($row['start_date'] ?? null),
        'endDate' => pro_link_iso($row['end_date'] ?? null),
        'registrationDate' => $created,
        'createdAt' => $created,
        // Flattened user fields for the UI cards.
        'fullName' => $row['full_name'] ?? '',
        'email' => $row['email'] ?? '',
        'profilePhotoUrl' => $row['profile_photo_url'] ?? null,
    ];
}

function pro_link_iso(?string $ts): ?string {
    if ($ts === null || $ts === '') return null;
    try {
        return (new DateTimeImmutable($ts))
            ->setTimezone(new DateTimeZone('UTC'))
            ->format('Y-m-d\TH:i:s.v\Z');
    } catch (Throwable $e) {
        return null;
    }
}

function pro_link_public_base_url(): string {
    $env = getenv('PUBLIC_BASE_URL');
    if ($env !== false && $env !== '') {
        return rtrim($env, '/');
    }
    $proto = (($_SERVER['HTTPS'] ?? '') === 'on') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost:8080';
    return $proto . '://' . $host;
}
