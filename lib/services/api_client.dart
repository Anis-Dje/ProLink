import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Thin HTTP client around the Pro-Link PHP REST API.
///
/// Uses the `http` package directly (the one taught in the
/// *Flutter – REST API* course module). The session token lives
/// in memory only — no on-device persistence — so the user re-logs
/// after each cold start. That keeps the surface area to what the
/// course covers.
class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = (baseUrl ?? _defaultBaseUrl).trimRight();

  /// Override at build time with `--dart-define=API_BASE_URL=http://...`.
  /// The default targets the Android emulator talking to a `php -S` on
  /// the host, which is the course's localhost pattern.
  static const _defaultBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: _envFallback);
  static const _envFallback = 'http://10.0.2.2:8080/api';

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
    };
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
    final res = await http.get(_uri(path, query), headers: _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path,
      {Object? body, Map<String, dynamic>? query}) async {
    final res = await http.post(
      _uri(path, query),
      headers: _headers(),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path,
      {Object? body, Map<String, dynamic>? query}) async {
    final res = await http.patch(
      _uri(path, query),
      headers: _headers(),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? query}) async {
    final res =
        await http.delete(_uri(path, query), headers: _headers());
    return _decode(res);
  }

  /// Multipart upload. Returns the public file URL served by PHP at
  /// `/files/<name>`.
  Future<String> uploadFile(File file, {String fieldName = 'file'}) async {
    final req = http.MultipartRequest('POST', _uri('/upload/'))
      ..headers.addAll(_headers(json: false))
      ..files.add(await http.MultipartFile.fromPath(fieldName, file.path));
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
