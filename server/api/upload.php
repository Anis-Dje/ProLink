<?php
// POST /api/upload/   — multipart/form-data, field "file"

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

// Diagnostics so the operator can see exactly what PHP saw on every
// upload request without depending on log_errors / error_log ini state:
// we write to STDERR directly *and* append to server/upload.log.
$proLinkUploadDiag = sprintf(
    '[pro-link] upload.php v2: post_max_size=%s, upload_max_filesize=%s, '
        . 'content_length=%s, content_type=%s, files_keys=[%s]',
    ini_get('post_max_size'),
    ini_get('upload_max_filesize'),
    $_SERVER['CONTENT_LENGTH'] ?? '<missing>',
    $_SERVER['CONTENT_TYPE'] ?? '<missing>',
    implode(',', array_keys($_FILES))
);
// php://stderr works in both CLI and built-in webserver modes; the
// STDERR constant is only defined in pure CLI, so we use the stream.
$proLinkErr = @fopen('php://stderr', 'w');
if ($proLinkErr) {
    @fwrite($proLinkErr, $proLinkUploadDiag . "\n");
    @fclose($proLinkErr);
}
@file_put_contents(__DIR__ . '/../upload.log',
    date('c') . ' ' . $proLinkUploadDiag . "\n",
    FILE_APPEND);
error_log($proLinkUploadDiag);

// Helper to write a checkpoint line to upload.log so we can pinpoint
// exactly where a failed request stopped executing.
$proLinkLog = function (string $msg): void {
    @file_put_contents(__DIR__ . '/../upload.log',
        date('c') . ' [pro-link] upload.php ' . $msg . "\n",
        FILE_APPEND);
};

$proLinkLog('checkpoint: about to connect to DB');
$pdo = pro_link_pdo();
$proLinkLog('checkpoint: DB connected, calling pro_link_current_user');
$proLinkLog(sprintf('  auth_header_present=%s',
    isset($_SERVER['HTTP_AUTHORIZATION']) ? 'yes' : 'no'));
pro_link_current_user($pdo);
$proLinkLog('checkpoint: auth passed');

// Wrap pro_link_fail so every failure inside upload.php leaves a log
// line — otherwise the script just exits and we have no idea which
// branch fired.
$proLinkFail = function (int $status, string $code, string $message)
        use ($proLinkLog): void {
    $proLinkLog(sprintf('FAIL %d %s: %s', $status, $code, $message));
    pro_link_fail($status, $code, $message);
};

// Detect the most common silent failure on a stock PHP install: the
// request body is bigger than `post_max_size`, in which case PHP discards
// $_POST and $_FILES entirely before any code runs and the symptom is an
// empty $_FILES with a non-empty Content-Length header. Without this
// branch the client only sees `missing_file` which is misleading.
$contentLength   = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
$contentType     = $_SERVER['CONTENT_TYPE'] ?? '';
$postMax         = pro_link_ini_to_bytes(ini_get('post_max_size'));
$uploadMax       = pro_link_ini_to_bytes(ini_get('upload_max_filesize'));
$looksMultipart  = stripos($contentType, 'multipart/form-data') === 0;

$proLinkLog(sprintf('checkpoint: file meta name=%s size=%s tmp_name=%s err=%s',
    $_FILES['file']['name'] ?? '<none>',
    $_FILES['file']['size'] ?? '<none>',
    $_FILES['file']['tmp_name'] ?? '<none>',
    $_FILES['file']['error'] ?? '<none>'
));

// ---- Raw-body upload path -------------------------------------------------
// ngrok-free + the dart `http` package's auto-generated multipart boundary
// have proven unreliable on real Android devices: the binary body reaches
// the backend with the right Content-Length but PHP's multipart parser
// rejects the file part. To stay immune to anything ngrok or the http
// package does to the wire format, the client may also POST the file as
// a raw body (any Content-Type other than multipart/form-data) with the
// original filename in the `X-Filename` header. We materialise that body
// to a temp file and then re-enter the same save / response code path
// the multipart branch uses.
// Look up X-Filename case-insensitively via getallheaders() — PHP's
// built-in dev server normalises some headers into $_SERVER inconsistently
// (and ngrok-free has been observed to mangle case), so we don't trust
// $_SERVER['HTTP_X_FILENAME'] alone.
$rawHeader = $_SERVER['HTTP_X_FILENAME'] ?? '';
if ($rawHeader === '' && function_exists('getallheaders')) {
    foreach (getallheaders() as $hdrName => $hdrVal) {
        if (strcasecmp($hdrName, 'X-Filename') === 0) {
            $rawHeader = (string)$hdrVal;
            break;
        }
    }
}
// Also dump the full header list to upload.log so we can audit what
// PHP actually received in case the header is missing entirely.
if (function_exists('getallheaders')) {
    $hdrPairs = [];
    foreach (getallheaders() as $k => $v) {
        $hdrPairs[] = $k . '=' . $v;
    }
    $proLinkLog('headers: ' . implode(' | ', $hdrPairs));
}
if ($rawHeader !== '' && !$looksMultipart) {
    $rawName = basename($rawHeader);
    $tmp = tempnam(sys_get_temp_dir(), 'pro_link_raw_');
    if ($tmp === false) {
        $proLinkFail(500, 'server_misconfig',
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
    $proLinkLog(sprintf(
        'raw-upload: x_filename=%s bytes=%d tmp=%s',
        $rawName, $written, $tmp));
    if ($written <= 0) {
        @unlink($tmp);
        $proLinkFail(400, 'missing_file',
            'Raw upload body was empty (X-Filename header was present but no bytes followed).');
    }
    // Synthesise a $_FILES['file'] entry so the rest of the script can run
    // unchanged. We use UPLOAD_ERR_OK and set tmp_name to our temp path.
    // Note: move_uploaded_file() rejects paths that were not created by a
    // multipart upload, so we have to use rename() instead in this branch.
    $_FILES['file'] = [
        'name'     => $rawName,
        'type'     => $_SERVER['CONTENT_TYPE'] ?? 'application/octet-stream',
        'size'     => $written,
        'tmp_name' => $tmp,
        'error'    => UPLOAD_ERR_OK,
    ];
    $proLinkRawUpload = true; // signal below to use rename() not move_uploaded_file()
}
// ---------------------------------------------------------------------------

if ($contentLength > 0 && $postMax > 0 && $contentLength > $postMax
        && empty($_FILES) && empty($_POST)) {
    $proLinkFail(413, 'file_too_large',
        sprintf(
            'Upload exceeds the server post_max_size limit of %s '
                . '(file is %s). Restart the dev server with '
                . '`server/start.bat` (or `start.sh`) to apply the bumped '
                . 'limits, or attach a URL instead of uploading.',
            ini_get('post_max_size'),
            pro_link_format_bytes($contentLength)
        ));
}

if (empty($_FILES['file'])) {
    // $_FILES is empty even though the client sent a multipart POST.
    // Surface what PHP *thinks* the limits are so the operator knows
    // whether the start scripts actually applied — and what the request
    // body looked like — instead of showing a generic "missing_file".
    $proLinkFail(400, 'missing_file', sprintf(
        'PHP saw an empty $_FILES superglobal. '
            . 'request_method=%s, content_type=%s, content_length=%s, '
            . 'post_max_size=%s, upload_max_filesize=%s. '
            . 'If content_length is bigger than post_max_size, restart '
            . 'the dev server with server/start.bat (-d post_max_size=55M).',
        $_SERVER['REQUEST_METHOD'] ?? '?',
        $contentType !== '' ? $contentType : '<missing>',
        $contentLength > 0 ? pro_link_format_bytes($contentLength) : '<missing>',
        ini_get('post_max_size'),
        ini_get('upload_max_filesize')
    ));
}
$f = $_FILES['file'];
if ($f['error'] !== UPLOAD_ERR_OK) {
    $proLinkFail($f['error'] === UPLOAD_ERR_INI_SIZE
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
$proLinkLog(sprintf(
    'checkpoint: about to move_uploaded_file tmp=%s dest=%s '
        . 'tmp_exists=%s dest_dir_writable=%s',
    $f['tmp_name'] ?? '<none>',
    $dest,
    (isset($f['tmp_name']) && is_file($f['tmp_name'])) ? 'yes' : 'no',
    is_writable(dirname($dest)) ? 'yes' : 'no'
));
// Raw uploads land in our own temp file (created via tempnam, not the
// multipart machinery), so move_uploaded_file() refuses them — we have
// to fall back to rename() in that case.
$saveOk = !empty($proLinkRawUpload)
    ? @rename($f['tmp_name'], $dest)
    : @move_uploaded_file($f['tmp_name'], $dest);
if (!$saveOk) {
    $proLinkFail(500, 'save_failed', sprintf(
        'Could not save uploaded file. tmp=%s dest=%s tmp_exists=%s dest_dir_writable=%s raw=%s',
        $f['tmp_name'] ?? '<none>',
        $dest,
        (isset($f['tmp_name']) && is_file($f['tmp_name'])) ? 'yes' : 'no',
        is_writable(dirname($dest)) ? 'yes' : 'no',
        !empty($proLinkRawUpload) ? 'yes' : 'no'
    ));
}

$proLinkLog('checkpoint: file saved -> ' . $dest);
$url = pro_link_public_base_url() . '/files/' . $name;
$proLinkLog('checkpoint: returning 201 url=' . $url);
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
