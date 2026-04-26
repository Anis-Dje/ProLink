<?php
// Front controller for `php -S`. Dispatches /api/<group> and optional
// action/id segments onto files under server/api/, and serves
// /files/<name> from server/uploads/.

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';

// Static uploads.
if (preg_match('#^/files/([A-Za-z0-9._-]+)$#', $uri, $m)) {
    $path = __DIR__ . '/uploads/' . $m[1];
    if (is_file($path)) {
        $mime = mime_content_type($path) ?: 'application/octet-stream';
        header('Content-Type: ' . $mime);
        header('Content-Length: ' . filesize($path));
        readfile($path);
        return true;
    }
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'not_found']);
    return true;
}

if (!str_starts_with($uri, '/api/')) {
    header('Content-Type: application/json');
    http_response_code(404);
    echo json_encode(['error' => 'not_found', 'path' => $uri]);
    return true;
}

$segments = array_values(array_filter(explode('/', trim($uri, '/'))));
array_shift($segments); // drop the leading 'api'
$group = $segments[0] ?? '';
$second = $segments[1] ?? null;
$third = $segments[2] ?? null;

// Heuristic: a segment is an "id" if it looks like a UUID or any string
// containing a digit or hyphen+digit. Otherwise treat it as an action.
$isId = fn($s) => $s !== null && preg_match('/[0-9]/', $s);

$action = null;
$id = null;
if ($third !== null) {
    // /api/interns/<uuid>/approve  → id=uuid, action=approve
    // /api/interns/by-user/<uuid>  → action=by-user, id=uuid
    if ($isId($second)) {
        $id = $second;
        $action = $third;
    } else {
        $action = $second;
        $id = $third;
    }
} elseif ($second !== null) {
    if ($isId($second)) {
        $id = $second;
    } else {
        $action = $second;
    }
}
if ($id !== null) {
    $_GET['id'] = $id;
}

$safe = fn($s) => $s !== null && preg_match('/^[A-Za-z0-9_-]+$/', $s);
if (!$safe($group) || ($action !== null && !$safe($action))) {
    header('Content-Type: application/json');
    http_response_code(404);
    echo json_encode(['error' => 'not_found', 'path' => $uri]);
    return true;
}

$candidates = [];
if ($action !== null) {
    $candidates[] = __DIR__ . "/api/{$group}_{$action}.php";
}
if ($id !== null && $action === null) {
    // /api/users/<id>  -> api/users_get.php
    $candidates[] = __DIR__ . "/api/{$group}_get.php";
}
$candidates[] = __DIR__ . "/api/{$group}.php";

foreach ($candidates as $f) {
    if (is_file($f)) {
        require $f;
        return true;
    }
}
header('Content-Type: application/json');
http_response_code(404);
echo json_encode(['error' => 'not_found', 'tried' => array_map('basename', $candidates)]);
return true;
