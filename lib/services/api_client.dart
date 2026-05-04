import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Thin HTTP client around the Pro-Link PHP REST API.
///
/// Uses the `http` package directly (the one taught in the
/// *Flutter – REST API* course module). The session token lives
/// in memory only — no on-device persistence — so the user re-logs
/// after each cold start. That keeps the surface area to what the
/// course covers.
class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = (baseUrl ?? _defaultBaseUrl).trimRight() {
    if (kDebugMode) {
      debugPrint('[ApiClient] baseUrl=$baseUrl');
    }
  }

  /// Override at build time with `--dart-define=API_BASE_URL=http://...`.
  /// The default targets the Android emulator talking to a `php -S` on
  /// the host, which is the course's localhost pattern.
  static const _defaultBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: _envFallback);
  static const _envFallback = 'http://192.168.1.60:8081/api';

  final String baseUrl;

  String? _token;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
      if (_token != null) 'authorization': 'Bearer $_token',
      // Bypasses ngrok-free's "you are about to visit" interstitial
      // when the API is exposed through a free tunnel. Harmless
      // otherwise.
      'ngrok-skip-browser-warning': 'true',
    };
  }

  /// Downloads a file URL as raw bytes. Used by the in-app file viewer
  /// so PDF / image previews work even when the URL sits behind a
  /// `ngrok-free` interstitial (which blocks browser-style requests
  /// without the skip header above).
  Future<List<int>> downloadBytes(String url) async {
    final uri = Uri.parse(url);
    if (kDebugMode) debugPrint('[ApiClient] DOWNLOAD $uri');
    final res = await http.get(uri, headers: {
      'accept': '*/*',
      if (_token != null) 'authorization': 'Bearer $_token',
      'ngrok-skip-browser-warning': 'true',
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, {
        'error': 'download_failed',
        'message': 'Could not download file (HTTP ${res.statusCode}).',
      });
    }
    return res.bodyBytes;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanQuery = query == null
        ? null
        : Map<String, String>.fromEntries(
            query.entries
                .where((e) => e.value != null)
                .map((e) => MapEntry(e.key, e.value.toString())),
          );
    return Uri.parse('$baseUrl$path').replace(
      queryParameters:
          (cleanQuery == null || cleanQuery.isEmpty) ? null : cleanQuery,
    );
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    final uri = _uri(path, query);
    if (kDebugMode) debugPrint('[ApiClient] GET $uri');
    final res = await http.get(uri, headers: _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path,
      {Object? body, Map<String, dynamic>? query}) async {
    final uri = _uri(path, query);
    if (kDebugMode) debugPrint('[ApiClient] POST $uri');
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path,
      {Object? body, Map<String, dynamic>? query}) async {
    final uri = _uri(path, query);
    if (kDebugMode) debugPrint('[ApiClient] PATCH $uri');
    final res = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? query}) async {
    final uri = _uri(path, query);
    if (kDebugMode) debugPrint('[ApiClient] DELETE $uri');
    final res = await http.delete(uri, headers: _headers());
    return _decode(res);
  }

  /// Uploads [file] and returns the public URL the server serves it
  /// from (`/files/<uuid>.<ext>`).
  ///
  /// Sent as a raw `application/octet-stream` body with the filename
  /// in BOTH an `X-Filename` header AND a `?filename=` query string —
  /// some HTTP middleware (including ngrok-free, which this project
  /// uses for mobile testing) drops or mangles `multipart/form-data`
  /// boundaries containing certain characters, so the multipart parser
  /// on PHP's end ends up with `$_FILES[file][name] = ''` and a
  /// useless `UPLOAD_ERR_NO_FILE`. Bypassing multipart entirely
  /// eliminates that whole class of bugs.
  ///
  /// Server-side, we ALSO sniff the magic bytes of the body, so even
  /// if the filename ends up missing or extension-less the saved file
  /// will still get the correct extension based on its real type.
  Future<String> uploadFile(XFile file, {String fieldName = 'file'}) async {
    final bytes = await file.readAsBytes();
    final filename = _deriveFilename(file, bytes);
    final uri = _uri('/upload/', {'filename': filename});
    final headers = _headers(json: false)
      ..['content-type'] = 'application/octet-stream'
      ..['x-filename'] = filename;
    if (kDebugMode) {
      debugPrint('[ApiClient] UPLOAD $uri name=$filename bytes=${bytes.length}');
    }
    final res = await http.post(uri, headers: headers, body: bytes);
    final body = _decode(res);
    return body['url'] as String;
  }

  /// Best-effort filename for the upload.
  ///
  /// Source of truth ranking:
  ///   1. `XFile.name` if it has an extension (file_picker normally
  ///      gives this).
  ///   2. `basename(XFile.path)` if `name` is missing or extensionless
  ///      and the path has a real extension.
  ///   3. The MIME-derived extension from `XFile.mimeType` glued onto
  ///      whichever stem we have (e.g. `application/pdf` → `.pdf`).
  ///   4. Magic-byte sniff of the first few bytes — bullet-proof
  ///      against pickers that return nothing usable on some Android
  ///      builds.
  ///   5. `upload_<ts>.bin` as the absolute last resort. The server
  ///      sniffs the body too, so even this still saves with the
  ///      right extension on disk.
  String _deriveFilename(XFile file, Uint8List bytes) {
    String stem = '';
    String ext = '';

    if (file.name.isNotEmpty) {
      final n = p.basename(file.name);
      stem = p.basenameWithoutExtension(n);
      ext = p.extension(n).replaceFirst('.', '').toLowerCase();
    }
    if ((stem.isEmpty || ext.isEmpty) && file.path.isNotEmpty) {
      final n = p.basename(file.path);
      if (stem.isEmpty) stem = p.basenameWithoutExtension(n);
      if (ext.isEmpty) {
        ext = p.extension(n).replaceFirst('.', '').toLowerCase();
      }
    }
    if (ext.isEmpty && file.mimeType != null && file.mimeType!.isNotEmpty) {
      ext = _extForMime(file.mimeType!) ?? '';
    }
    if (ext.isEmpty) {
      ext = _sniffExt(bytes) ?? '';
    }
    if (stem.isEmpty) {
      stem = 'upload_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (ext.isEmpty) {
      ext = 'bin';
    }
    return '$stem.$ext';
  }

  /// Maps a MIME type to a canonical lower-case extension (no dot).
  /// Keep in sync with the server-side mime map in router.php.
  String? _extForMime(String mime) {
    switch (mime.toLowerCase().split(';').first.trim()) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/bmp':
        return 'bmp';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'application/vnd.ms-excel':
        return 'xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      case 'application/vnd.ms-powerpoint':
        return 'ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';
      case 'application/zip':
        return 'zip';
      case 'text/plain':
        return 'txt';
      case 'text/csv':
        return 'csv';
    }
    return null;
  }

  /// Quick magic-byte sniffer; mirrors `pro_link_sniff_extension` on
  /// the server so client-derived names line up with what the server
  /// would pick if it had to fall back.
  String? _sniffExt(Uint8List bytes) {
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 && bytes[1] == 0x50 &&
        bytes[2] == 0x44 && bytes[3] == 0x46 && bytes[4] == 0x2D) {
      return 'pdf';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) && bytes[5] == 0x61) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'bmp';
    }
    return null;
  }

  Map<String, dynamic> _decode(http.Response res) {
    final code = res.statusCode;
    final body = res.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
    if (code >= 200 && code < 300) return body;
    throw ApiException(code, body);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;

  String get error => body['error'] as String? ?? 'unknown_error';
  String get messageOrError => (body['message'] as String?) ?? error;

  @override
  String toString() => 'ApiException($statusCode): $messageOrError';
}
