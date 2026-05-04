<?php
// POST /api/upload/
//
// Two transport formats are accepted:
//
//   1. multipart/form-data, field "file"  (course default).
//   2. raw application/octet-stream body, with the filename passed in
//      either an `X-Filename` header or a `?filename=` query string.
//
// The raw POST path exists because Dart's `http.MultipartRequest`
// generates boundaries containing characters (`+`, `.`) that some
// HTTP middleware silently mangles — most notably ngrok-free, which
// stripped the `Content-Disposition: filename=...` segment on this
// project's setup, leaving PHP with `$_FILES['file']['name'] = ''`
// (UPLOAD_ERR_NO_FILE / err=4). Routing around the multipart parser
// makes uploads immune to that whole class of issues.
//
// Regardless of transport, after the bytes are on disk we sniff the
// magic header and use that to pick the on-disk extension. That way
// even if the client filename is missing or wrong (e.g. file_picker
// returning an empty name on some Android builds, leaving us with a
// `upload_<ts>.bin` fallback) the saved file still ends up with a
// correct extension and the in-app viewer can preview it.

require_once __DIR__ . '/../lib/helpers.php';
require_once __DIR__ . '/../lib/db.php';
pro_link_bootstrap();
pro_link_require_method('POST');

$pdo = pro_link_pdo();
pro_link_current_user($pdo);

$logFile = __DIR__ . '/../upload.log';
$proLinkLog = function (string $msg) use ($logFile) {
    @file_put_contents(
        $logFile,
        '[' . date('c') . "] [pro-link] upload.php $msg\n",
        FILE_APPEND
    );
};

$contentType = $_SERVER['CONTENT_TYPE'] ?? '';
$looksMultipart = stripos($contentType, 'multipart/form-data') !== false;

// --- post_max_size pre-check ---------------------------------------
// If the body exceeded `post_max_size`, PHP discards $_POST/$_FILES
// before any code runs and the symptom is an empty $_FILES with a
// non-empty Content-Length header. Surface a real error instead of
// the generic missing_file.
$contentLength = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
$postMax = pro_link_ini_to_bytes(ini_get('post_max_size'));
if ($looksMultipart
        && $contentLength > 0 && $postMax > 0 && $contentLength > $postMax
        && empty($_FILES) && empty($_POST)) {
    pro_link_fail(413, 'file_too_large',
        sprintf(
            'Upload exceeds the server post_max_size limit of %s. '
                . 'Increase post_max_size / upload_max_filesize in php.ini '
                . '(see server/php.ini), or paste a public URL instead of uploading the file.',
            ini_get('post_max_size')
        ));
}

$tmpPath = null;
$rawName = '';

if ($looksMultipart) {
    // ---- Standard multipart/form-data branch --------------------
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
    $tmpPath = $f['tmp_name'];
    $rawName = (string)$f['name'];
} else {
    // ---- Raw body branch ----------------------------------------
    // X-Filename header — look it up case-insensitively because PHP's
    // built-in dev server normalises header names inconsistently and
    // ngrok-free has historically rewritten their case.
    $rawHeader = $_SERVER['HTTP_X_FILENAME'] ?? '';
    if ($rawHeader === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $hdrName => $hdrVal) {
            if (strcasecmp($hdrName, 'X-Filename') === 0) {
                $rawHeader = (string)$hdrVal;
                break;
            }
        }
    }
    // Query-string fallback. Survives header-stripping middleware.
    if ($rawHeader === '' && !empty($_GET['filename'])) {
        $rawHeader = (string)$_GET['filename'];
    }
    $rawName = $rawHeader;

    // Materialise php://input to a temp file. We can't trust
    // `file_get_contents` to a string variable for very large bodies,
    // and stream_copy_to_stream gives us the same path-on-disk shape
    // the multipart branch already feeds into the rest of the file.
    $tmp = tempnam(sys_get_temp_dir(), 'pro_link_raw_');
    $in = fopen('php://input', 'rb');
    $out = fopen($tmp, 'wb');
    if (!$in || !$out) {
        pro_link_fail(500, 'save_failed', 'Could not buffer raw upload.');
    }
    $copied = stream_copy_to_stream($in, $out);
    fclose($in);
    fclose($out);
    if ($copied <= 0) {
        @unlink($tmp);
        pro_link_fail(400, 'missing_file',
            'PHP saw an empty request body. Make sure the upload was '
                . 'sent as raw bytes (Content-Type: application/octet-stream) '
                . 'and that nothing in front of PHP stripped the body.');
    }
    $tmpPath = $tmp;
    $proLinkLog(sprintf(
        'raw-upload: x_filename=%s bytes=%d tmp=%s',
        $rawHeader,
        $copied,
        $tmp
    ));
    if ($rawName === '') {
        // No name at all — synthesise one. The magic-byte sniff below
        // will still pick the right extension.
        $rawName = 'upload_' . round(microtime(true) * 1000) . '.bin';
    }
}

if ($tmpPath === null || !is_file($tmpPath)) {
    pro_link_fail(500, 'save_failed', 'Internal error: no upload buffered.');
}

// --- Pick a safe on-disk extension ----------------------------------
// Magic-byte sniff first (most reliable when the client name is
// missing/wrong); fall back to the extension hint from the filename.
$detectedExt = pro_link_sniff_extension($tmpPath);
$nameExt = strtolower(pathinfo($rawName, PATHINFO_EXTENSION));
$nameExt = preg_replace('/[^a-z0-9]/', '', $nameExt);
if ($detectedExt !== null) {
    $ext = $detectedExt;
} elseif ($nameExt !== '' && $nameExt !== 'bin') {
    $ext = $nameExt;
} else {
    $ext = 'bin';
}

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
$ok = $looksMultipart
    ? move_uploaded_file($tmpPath, $dest)
    : @rename($tmpPath, $dest);
if (!$ok) {
    @unlink($tmpPath);
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

/**
 * Sniff the first ~16 bytes of [path] and return a canonical extension
 * for the formats Pro-Link actually serves (PDF, common images, office
 * docs, zip), or NULL if we don't recognise the magic. Caller decides
 * whether to fall back to the filename's claimed extension.
 *
 * This protects us against clients that send wrong / missing filenames
 * (e.g. file_picker on Android sometimes returns an empty `XFile.name`,
 * making the client emit a placeholder `upload_<ts>.bin` — we'd
 * otherwise save the file as `.bin` and be unable to preview it later).
 */
function pro_link_sniff_extension(string $path): ?string {
    $fh = @fopen($path, 'rb');
    if (!$fh) return null;
    $head = fread($fh, 16) ?: '';
    fclose($fh);
    if ($head === '') return null;
    if (str_starts_with($head, '%PDF-'))               return 'pdf';
    if (str_starts_with($head, "\x89PNG\r\n\x1a\n"))   return 'png';
    if (str_starts_with($head, "\xFF\xD8\xFF"))        return 'jpg';
    if (substr($head, 0, 6) === 'GIF87a'
        || substr($head, 0, 6) === 'GIF89a')           return 'gif';
    if (substr($head, 0, 4) === 'RIFF'
        && substr($head, 8, 4) === 'WEBP')             return 'webp';
    if (substr($head, 0, 2) === 'BM')                  return 'bmp';
    // PK\x03\x04 = ZIP container. docx/xlsx/pptx are zip-based, so we
    // can't disambiguate from magic bytes alone — leave it to the
    // filename-extension hint.
    if (substr($head, 0, 4) === "PK\x03\x04")          return null;
    if (str_starts_with($head, "\xD0\xCF\x11\xE0"))    return 'doc'; // legacy office
    return null;
}
