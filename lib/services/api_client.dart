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

  /// Multipart upload. Returns the public file URL served by PHP at
  /// `/files/<name>`. Works on both mobile (file system path) and web
  /// (only bytes available) by reading the file through `XFile`.
  Future<String> uploadFile(XFile file, {String fieldName = 'file'}) async {
    final bytes = await file.readAsBytes();
    final filename = p.basename(file.path.isEmpty ? file.name : file.path);
    final req = http.MultipartRequest('POST', _uri('/upload/'))
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
      ));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _decode(res);
    return body['url'] as String;
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
