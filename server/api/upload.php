<?php
// POST /api/upload/
//
// Two accepted body formats:
//   1. multipart/form-data with a "file" part (classic browser uploads, curl)
//   2. raw bytes (any other content-type) with the original filename in
//      either an `X-Filename` request header or a `?filename=...` query
//      parameter. Used by the Flutter client because dart `http`'s
//      auto-generated multipart boundary + ngrok-free have proven
//      unreliable on real devices (PHP's parser strips the file part).

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
pro_link_current_user($pdo);

$contentLength  = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
$contentType    = $_SERVER['CONTENT_TYPE'] ?? '';
$postMax        = pro_link_ini_to_bytes(ini_get('post_max_size'));
$looksMultipart = stripos($contentType, 'multipart/form-data') === 0;

// --- Raw-body upload path --------------------------------------------------
// Look up the filename in (a) X-Filename header (case-insensitively, since
// some HTTP layers normalise differently), then (b) ?filename=... query
// string, then (c) a generated upload_<ts>.bin if everything is missing.
$rawHeader = $_SERVER['HTTP_X_FILENAME'] ?? '';
if ($rawHeader === '' && function_exists('getallheaders')) {
    foreach (getallheaders() as $hdrName => $hdrVal) {
        if (strcasecmp($hdrName, 'X-Filename') === 0) {
            $rawHeader = (string)$hdrVal;
            break;
        }
    }
}
if ($rawHeader === '' && !empty($_GET['filename'])) {
    $rawHeader = (string)$_GET['filename'];
}
if ($rawHeader === '' && !$looksMultipart && $contentLength > 0) {
    $rawHeader = 'upload_' . time() . '.bin';
}
if ($rawHeader !== '' && !$looksMultipart) {
    $rawName = basename($rawHeader);
    $tmp = tempnam(sys_get_temp_dir(), 'pro_link_raw_');
    if ($tmp === false) {
        pro_link_fail(500, 'server_misconfig',
            'Could not create temp file for raw upload.');
    }
    $in = fopen('php://input', 'rb');
    $out = fopen($tmp, 'wb');
    $written = 0;
    if ($in && $out) {
        while (!feof($in)) {
            $chunk = fread($in, 65536);
            if ($chunk === false) break;
            fwrite($out, $chunk);
            $written += strlen($chunk);
        }
    }
    if ($in) fclose($in);
    if ($out) fclose($out);
    if ($written <= 0) {
        @unlink($tmp);
        pro_link_fail(400, 'missing_file',
            'Raw upload body was empty.');
    }
    // Synthesise $_FILES['file'] so the rest of the script (which was
    // written for multipart) runs unchanged. We have to remember to use
    // rename() instead of move_uploaded_file() since this temp file was
    // not created by PHP's multipart machinery.
    $_FILES['file'] = [
        'name'     => $rawName,
        'type'     => $_SERVER['CONTENT_TYPE'] ?? 'application/octet-stream',
        'size'     => $written,
        'tmp_name' => $tmp,
        'error'    => UPLOAD_ERR_OK,
    ];
    $proLinkRawUpload = true;
}
// --------------------------------------------------------------------------

// Detect the most common silent failure on a stock PHP install: the
// request body is bigger than `post_max_size`, in which case PHP discards
// $_POST and $_FILES entirely before any code runs. Without this branch
// the client would only see the misleading `missing_file` error.
if ($contentLength > 0 && $postMax > 0 && $contentLength > $postMax
        && empty($_FILES) && empty($_POST)) {
    pro_link_fail(413, 'file_too_large',
        sprintf(
            'Upload exceeds the server post_max_size limit of %s (file is %s). '
                . 'Restart the dev server with `server/start.bat` (or `start.sh`) '
                . 'to apply the bumped limits, or attach a URL instead.',
            ini_get('post_max_size'),
            pro_link_format_bytes($contentLength)
        ));
}

if (empty($_FILES['file'])) {
    pro_link_fail(400, 'missing_file', sprintf(
        'No file in request. content_type=%s, content_length=%s, '
            . 'post_max_size=%s, upload_max_filesize=%s.',
        $contentType !== '' ? $contentType : '<missing>',
        $contentLength > 0 ? pro_link_format_bytes($contentLength) : '<missing>',
        ini_get('post_max_size'),
        ini_get('upload_max_filesize')
    ));
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
// Raw uploads use rename() because move_uploaded_file() refuses paths
// that weren't created by the multipart machinery.
$saveOk = !empty($proLinkRawUpload)
    ? @rename($f['tmp_name'], $dest)
    : @move_uploaded_file($f['tmp_name'], $dest);
if (!$saveOk) {
    pro_link_fail(500, 'save_failed', sprintf(
        'Could not save uploaded file. tmp=%s dest=%s tmp_exists=%s dest_dir_writable=%s',
        $f['tmp_name'] ?? '<none>',
        $dest,
        (isset($f['tmp_name']) && is_file($f['tmp_name'])) ? 'yes' : 'no',
        is_writable(dirname($dest)) ? 'yes' : 'no'
    ));
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

/** Format an integer byte count as a short human-readable string. */
function pro_link_format_bytes(int $bytes): string {
    if ($bytes < 1024) return $bytes . 'B';
    if ($bytes < 1024 * 1024) return sprintf('%.1fKB', $bytes / 1024);
    if ($bytes < 1024 * 1024 * 1024) return sprintf('%.1fMB', $bytes / 1024 / 1024);
    return sprintf('%.2fGB', $bytes / 1024 / 1024 / 1024);
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
