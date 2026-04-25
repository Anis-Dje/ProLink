import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Returns a Shelf JSON response with an explicit content-type header.
Response jsonResponse(int status, Object? body) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Response ok(Object? body) => jsonResponse(200, body);
Response created(Object? body) => jsonResponse(201, body);
Response badRequest(String message) =>
    jsonResponse(400, {'error': 'bad_request', 'message': message});
Response notFound([String message = 'not found']) =>
    jsonResponse(404, {'error': 'not_found', 'message': message});
Response forbidden([String message = 'forbidden']) =>
    jsonResponse(403, {'error': 'forbidden', 'message': message});

/// Parses a JSON body into a Map. Returns null if the body is empty or not
/// a JSON object. Throws FormatException on malformed JSON.
Future<Map<String, dynamic>?> readJsonMap(Request req) async {
  final body = await req.readAsString();
  if (body.trim().isEmpty) return null;
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object body');
  }
  return Map<String, dynamic>.from(decoded);
}

/// Helper: render a [DateTime] as an ISO-8601 UTC string (or null).
String? isoOrNull(DateTime? d) => d?.toUtc().toIso8601String();
