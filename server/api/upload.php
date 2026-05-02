<?php
// POST /api/upload/   — multipart/form-data, field "file"

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
pro_link_current_user($pdo);

// Detect the most common silent failure on a stock PHP install: the
// request body is bigger than `post_max_size`, in which case PHP discards
// $_POST and $_FILES entirely before any code runs and the symptom is an
// empty $_FILES with a non-empty Content-Length header. Without this
// branch the client only sees `missing_file` which is misleading.
$contentLength = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
$postMax = pro_link_ini_to_bytes(ini_get('post_max_size'));
if ($contentLength > 0 && $postMax > 0 && $contentLength > $postMax
        && empty($_FILES) && empty($_POST)) {
    pro_link_fail(413, 'file_too_large',
        sprintf(
            'Upload exceeds the server post_max_size limit of %s. '
                . 'Increase post_max_size / upload_max_filesize in php.ini '
                . '(see server/php.ini), or paste a public URL instead of uploading the file.',
            ini_get('post_max_size')
        ));
}

if (empty($_FILES['file'])) {
    pro_link_fail(400, 'missing_file',
        'No file uploaded under the "file" form field.');
}
$f = $_FILES['file'];
if ($f['error'] !== UPLOAD_ERR_OK) {
    pro_link_fail($f['error'] === UPLOAD_ERR_INI_SIZE
            || $f['error'] === UPLOAD_ERR_FORM_SIZE ? 413 : 400,
        pro_link_upload_error_code($f['error']),
        pro_link_upload_error_message($f['error']));
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
if (!is_dir(dirname($dest))) {
    @mkdir(dirname($dest), 0775, true);
}
if (!move_uploaded_file($f['tmp_name'], $dest)) {
    pro_link_fail(500, 'save_failed', 'Could not save uploaded file.');
}

$url = pro_link_public_base_url() . '/files/' . $name;
pro_link_ok(['url' => $url, 'filename' => $name], 201);


/** Translate an UPLOAD_ERR_* constant into a stable error code. */
function pro_link_upload_error_code(int $code): string {
    return [
        UPLOAD_ERR_INI_SIZE   => 'file_too_large',
        UPLOAD_ERR_FORM_SIZE  => 'file_too_large',
        UPLOAD_ERR_PARTIAL    => 'partial_upload',
        UPLOAD_ERR_NO_FILE    => 'missing_file',
        UPLOAD_ERR_NO_TMP_DIR => 'server_misconfig',
        UPLOAD_ERR_CANT_WRITE => 'server_misconfig',
        UPLOAD_ERR_EXTENSION  => 'server_misconfig',
    ][$code] ?? 'upload_error';
}

/** Human-friendly message for an UPLOAD_ERR_* constant. */
function pro_link_upload_error_message(int $code): string {
    $upload = ini_get('upload_max_filesize');
    return [
        UPLOAD_ERR_INI_SIZE => sprintf(
            'File exceeds the server upload_max_filesize limit of %s. '
                . 'Increase upload_max_filesize in php.ini (see server/php.ini), '
                . 'or paste a public URL instead.', $upload),
        UPLOAD_ERR_FORM_SIZE => 'File exceeds the form size limit specified in the HTML form.',
        UPLOAD_ERR_PARTIAL => 'File was only partially uploaded. Please retry.',
        UPLOAD_ERR_NO_FILE => 'No file was uploaded under the "file" form field.',
        UPLOAD_ERR_NO_TMP_DIR => 'Server has no upload temp directory configured.',
        UPLOAD_ERR_CANT_WRITE => 'Server failed to write the upload to disk.',
        UPLOAD_ERR_EXTENSION => 'A PHP extension stopped the upload.',
    ][$code] ?? ('Upload failed with code ' . $code . '.');
}

/**
 * Convert a php.ini shorthand (e.g. "8M", "1G") into bytes.
 */
function pro_link_ini_to_bytes(string $val): int {
    $val = trim($val);
    if ($val === '') return 0;
    $unit = strtolower(substr($val, -1));
    $num = (int)$val;
    return match ($unit) {
        'g' => $num * 1024 * 1024 * 1024,
        'm' => $num * 1024 * 1024,
        'k' => $num * 1024,
        default => (int)$val,
    };
}
