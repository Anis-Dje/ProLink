import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'auth.dart';

/// Marker keys for request context.
const _authPayloadKey = 'authPayload';

extension AuthPayloadAccess on Request {
  Map<String, dynamic>? get authPayload =>
      context[_authPayloadKey] as Map<String, dynamic>?;

  String? get userId => authPayload?['sub'] as String?;
  String? get userRole => authPayload?['role'] as String?;
  String? get userEmail => authPayload?['email'] as String?;
}

/// Returns 401 unless the request carries a valid JWT in the `Authorization`
/// header. Decoded claims are placed in `request.context['authPayload']`.
Middleware requireAuth(AuthHelper auth) {
  return (Handler inner) {
    return (Request request) async {
      final header = request.headers['authorization'];
      if (header == null || !header.toLowerCase().startsWith('bearer ')) {
        return _json(401, {'error': 'Missing Authorization Bearer token'});
      }
      final token = header.substring(7).trim();
      final payload = auth.verifyToken(token);
      if (payload == null) {
        return _json(401, {'error': 'Invalid or expired token'});
      }
      final updated =
          request.change(context: {_authPayloadKey: payload});
      return inner(updated);
    };
  };
}

/// 403 if the requesting user is not in [allowedRoles].
Middleware requireRole(List<String> allowedRoles) {
  return (Handler inner) {
    return (Request request) async {
      final role = request.userRole;
      if (role == null || !allowedRoles.contains(role)) {
        return _json(403, {'error': 'Forbidden for role $role'});
      }
      return inner(request);
    };
  };
}

/// Catches uncaught exceptions and returns a structured 500 response so the
/// server never returns an opaque "Internal error".
Middleware errorHandler() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } catch (e, st) {
        // Full details go to the server logs; the client receives a generic
        // message so we don't leak SQL strings, table names, file paths, etc.
        print('[error] ${request.method} ${request.requestedUri}: $e\n$st');
        return _json(500, {
          'error': 'internal_error',
          'message': 'An unexpected error occurred',
        });
      }
    };
  };
}

/// Logs incoming requests + response status.
Middleware requestLogger() {
  return (Handler inner) {
    return (Request request) async {
      final stopwatch = Stopwatch()..start();
      final response = await inner(request);
      stopwatch.stop();
      print(
        '[${request.method}] ${request.requestedUri.path} '
        '-> ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
      );
      return response;
    };
  };
}

Response _json(int status, Object? body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
