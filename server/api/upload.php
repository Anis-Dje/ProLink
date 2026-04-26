<?php
// POST /api/upload/   — multipart/form-data, field "file"

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
pro_link_current_user($pdo);

if (empty($_FILES['file'])) {
    pro_link_fail(400, 'missing_file', 'No file uploaded under the "file" field.');
}
$f = $_FILES['file'];
if ($f['error'] !== UPLOAD_ERR_OK) {
    pro_link_fail(400, 'upload_error', 'Upload failed with code ' . $f['error']);
}

$ext = strtolower(pathinfo($f['name'], PATHINFO_EXTENSION));
$ext = preg_replace('/[^a-z0-9]/', '', $ext) ?: 'bin';
if (!function_exists('_pl_uuid')) {
    function _pl_uuid(): string {
        $b = random_bytes(16);
        $b[6] = chr((ord($b[6]) & 0x0f) | 0x40);
        $b[8] = chr((ord($b[8]) & 0x3f) | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($b), 4));
    }
}
$name = _pl_uuid() . '.' . $ext;
$dest = __DIR__ . '/../uploads/' . $name;
if (!move_uploaded_file($f['tmp_name'], $dest)) {
    pro_link_fail(500, 'save_failed', 'Could not save uploaded file.');
}

$url = pro_link_public_base_url() . '/files/' . $name;
pro_link_ok(['url' => $url, 'filename' => $name], 201);
