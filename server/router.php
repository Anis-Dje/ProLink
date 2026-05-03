<?php
// Front controller for `php -S`. Dispatches /api/<group> and optional
// action/id segments onto files under server/api/, and serves
// /files/<name> from server/uploads/.

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';

/**
 * Best-effort MIME guess that does NOT require the `fileinfo` PHP
 * extension. We previously called `mime_content_type()` directly,
 * but on some XAMPP / Windows PHP setups `fileinfo` is disabled and
 * the call fatals out with `Call to undefined function`, taking the
 * whole /files/ static handler down with it. Falls back to a small
 * extension table covering the formats Pro-Link actually serves
 * (PDF, common images, office docs); unknown types degrade to
 * application/octet-stream so the browser / Flutter viewer can still
 * download the bytes.
 */
function pro_link_mime_for(string $path): string
{
    if (function_exists('mime_content_type')) {
        $detected = @mime_content_type($path);
        if (is_string($detected) && $detected !== '') {
            return $detected;
        }
    }
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    static $map = [
        'pdf'  => 'application/pdf',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'gif'  => 'image/gif',
        'webp' => 'image/webp',
        'bmp'  => 'image/bmp',
        'svg'  => 'image/svg+xml',
        'txt'  => 'text/plain; charset=utf-8',
        'csv'  => 'text/csv; charset=utf-8',
        'json' => 'application/json',
        'doc'  => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls'  => 'application/vnd.ms-excel',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'ppt'  => 'application/vnd.ms-powerpoint',
        'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'zip'  => 'application/zip',
    ];
    return $map[$ext] ?? 'application/octet-stream';
}

// Static uploads.
if (preg_match('#^/files/([A-Za-z0-9._-]+)$#', $uri, $m)) {
    $path = __DIR__ . '/uploads/' . $m[1];
    if (is_file($path)) {
        header('Content-Type: ' . pro_link_mime_for($path));
        header('Content-Length: ' . filesize($path));
        // Lets the Flutter in-app viewer / browser cache the file. Not
        // strictly required, but harmless and friendlier on slow links.
        header('Cache-Control: private, max-age=3600');
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
