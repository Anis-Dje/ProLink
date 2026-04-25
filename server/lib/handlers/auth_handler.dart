import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth.dart';
import '../json_helpers.dart';
import '../middleware.dart';

/// /auth/* routes.
class AuthHandler {
  AuthHandler({required this.pool, required this.auth});
  final Pool<void> pool;
  final AuthHelper auth;

  Router get router {
    final r = Router();

    // Self-service intern registration. Other roles are created by an admin
    // via /users (see UsersHandler).
    r.post('/register', _register);
    r.post('/login', _login);

    // /me requires a valid token.
    r.get(
      '/me',
      Pipeline().addMiddleware(requireAuth(auth)).addHandler(_me),
    );

    return r;
  }

  Future<Response> _register(Request req) async {
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;
    final fullName = (body['fullName'] as String?)?.trim();
    final phone = (body['phone'] as String?)?.trim() ?? '';
    final studentId = (body['studentId'] as String?)?.trim();
    final university = (body['university'] as String?)?.trim() ?? '';
    final specialization = (body['specialization'] as String?)?.trim() ?? '';
    final department = (body['department'] as String?)?.trim() ?? '';

    if (email == null || password == null || fullName == null ||
        studentId == null || password.length < 6) {
      return badRequest(
        'email, password (>=6 chars), fullName, studentId are required',
      );
    }

    final hash = auth.hashPassword(password);

    try {
      final result = await pool.runTx<Map<String, dynamic>>((session) async {
        final userInsert = await session.execute(
          Sql.named('''
            INSERT INTO users (email, password_hash, full_name, phone, role)
            VALUES (@email, @hash, @fullName, @phone, 'intern')
            RETURNING id
          '''),
          parameters: {
            'email': email,
            'hash': hash,
            'fullName': fullName,
            'phone': phone,
          },
        );
        final userId = userInsert.first[0] as String;
        await session.execute(
          Sql.named('''
            INSERT INTO interns (
              user_id, student_id, university, specialization, department
            ) VALUES (
              @userId, @studentId, @university, @specialization, @department
            )
          '''),
          parameters: {
            'userId': userId,
            'studentId': studentId,
            'university': university,
            'specialization': specialization,
            'department': department,
          },
        );
        return {
          'userId': userId,
          'token': auth.issueToken(
              userId: userId, email: email, role: 'intern'),
        };
      });
      return created({
        'token': result['token'],
        'user': {
          'id': result['userId'],
          'email': email,
          'fullName': fullName,
          'role': 'intern',
        },
      });
    } on ServerException catch (e) {
      // Postgres unique violation.
      if (e.code == '23505') {
        return jsonResponse(409, {
          'error': 'email_in_use',
          'message': 'Email already registered',
        });
      }
      rethrow;
    }
  }

  Future<Response> _login(Request req) async {
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;
    if (email == null || password == null) {
      return badRequest('email and password are required');
    }

    final rows = await pool.execute(
      Sql.named('''
        SELECT id, email, password_hash, full_name, role, is_active,
               profile_photo_url, phone
          FROM users WHERE email = @email
      '''),
      parameters: {'email': email},
    );
    if (rows.isEmpty) {
      return jsonResponse(401, {'error': 'invalid_credentials'});
    }
    final row = rows.first.toColumnMap();
    if (!auth.verifyPassword(password, row['password_hash'] as String)) {
      return jsonResponse(401, {'error': 'invalid_credentials'});
    }
    if (!(row['is_active'] as bool)) {
      return jsonResponse(403, {'error': 'account_disabled'});
    }
    final token = auth.issueToken(
      userId: row['id'] as String,
      email: row['email'] as String,
      role: row['role'] as String,
    );
    return ok({
      'token': token,
      'user': _userToJson(row),
    });
  }

  Future<Response> _me(Request req) async {
    final id = req.userId;
    if (id == null) return forbidden();
    final rows = await pool.execute(
      Sql.named('''
        SELECT id, email, full_name, role, is_active, profile_photo_url,
               phone, created_at
          FROM users WHERE id = @id
      '''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return notFound('user not found');
    return ok({'user': _userToJson(rows.first.toColumnMap())});
  }
}

Map<String, dynamic> _userToJson(Map<String, dynamic> row) => {
      'id': row['id'],
      'email': row['email'],
      'fullName': row['full_name'],
      'role': row['role'],
      'isActive': row['is_active'],
      'profilePhotoUrl': row['profile_photo_url'],
      'phone': row['phone'] ?? '',
      'createdAt': isoOrNull(row['created_at'] as DateTime?),
    };
