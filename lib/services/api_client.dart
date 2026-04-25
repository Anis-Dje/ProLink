import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP client around the Pro-Link REST API. Owns the JWT token
/// (persisted via flutter_secure_storage) and applies it as a Bearer header
/// on every authenticated request.
class ApiClient {
  ApiClient({String? baseUrl, FlutterSecureStorage? storage})
      : baseUrl = (baseUrl ?? _defaultBaseUrl).trimRight(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Override at build time with `--dart-define=API_BASE_URL=https://...`.
  static const _defaultBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: _envFallback);
  static const _envFallback = 'http://10.0.2.2:8080/api';

  final String baseUrl;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'prolink_jwt';

  String? _token;

  /// Loads any persisted token off disk. Call once at app boot.
  Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
  }

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  Future<void> setToken(String? token) async {
    _token = token;
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
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

  /// Multipart upload of a single file. Returns the public file URL.
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
  String get messageOrError =>
      (body['message'] as String?) ?? error;

  @override
  String toString() => 'ApiException($statusCode): $messageOrError';
}
