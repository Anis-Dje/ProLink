import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth.dart';
import '../json_helpers.dart';
import '../middleware.dart';

/// /users/* routes (admin-only for the most part).
class UsersHandler {
  UsersHandler({required this.pool, required this.auth});
  final Pool<void> pool;
  final AuthHelper auth;

  Router get router {
    final r = Router();
    // Auth middleware applied at the server level for all /users routes.
    r.get('/', _list);
    r.post('/', _create);
    r.get('/<id>', _get);
    r.patch('/<id>', _update);
    r.post('/<id>/active', _toggleActive);
    return r;
  }

  Future<Response> _list(Request req) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final role = req.url.queryParameters['role'];
    final rows = role == null
        ? await pool.execute(
            Sql.named('SELECT * FROM users ORDER BY created_at DESC'),
          )
        : await pool.execute(
            Sql.named('SELECT * FROM users WHERE role = @role '
                'ORDER BY created_at DESC'),
            parameters: {'role': role},
          );
    return ok({
      'users': rows.map((r) => _userToJson(r.toColumnMap())).toList(),
    });
  }

  Future<Response> _get(Request req, String id) async {
    final caller = req.userId;
    if (req.userRole != 'admin' && caller != id) {
      return forbidden();
    }
    final rows = await pool.execute(
      Sql.named('SELECT * FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return notFound();
    return ok({'user': _userToJson(rows.first.toColumnMap())});
  }

  /// Admins only: create a mentor or admin account.
  Future<Response> _create(Request req) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;
    final fullName = (body['fullName'] as String?)?.trim();
    final phone = (body['phone'] as String?)?.trim() ?? '';
    final role = body['role'] as String?;

    if (email == null || password == null || fullName == null ||
        password.length < 6) {
      return badRequest(
        'email, password (>=6), fullName are required',
      );
    }
    if (role != 'mentor' && role != 'admin') {
      return badRequest('role must be mentor or admin');
    }

    try {
      final hash = auth.hashPassword(password);
      final result = await pool.execute(
        Sql.named('''
          INSERT INTO users (email, password_hash, full_name, phone, role)
          VALUES (@email, @hash, @fullName, @phone, @role)
          RETURNING *
        '''),
        parameters: {
          'email': email,
          'hash': hash,
          'fullName': fullName,
          'phone': phone,
          'role': role,
        },
      );
      return created({'user': _userToJson(result.first.toColumnMap())});
    } on ServerException catch (e) {
      if (e.code == '23505') {
        return jsonResponse(409, {'error': 'email_in_use'});
      }
      rethrow;
    }
  }

  Future<Response> _update(Request req, String id) async {
    final caller = req.userId;
    if (req.userRole != 'admin' && caller != id) return forbidden();
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final updates = <String, Object?>{};
    if (body.containsKey('fullName')) updates['full_name'] = body['fullName'];
    if (body.containsKey('phone')) updates['phone'] = body['phone'];
    if (body.containsKey('profilePhotoUrl')) {
      updates['profile_photo_url'] = body['profilePhotoUrl'];
    }
    if (req.userRole == 'admin' && body.containsKey('role')) {
      updates['role'] = body['role'];
    }
    if (updates.isEmpty) return badRequest('no fields to update');

    final setSql = updates.keys.map((k) => '$k = @$k').join(', ');
    final params = {...updates, 'id': id};

    final rows = await pool.execute(
      Sql.named('UPDATE users SET $setSql WHERE id = @id RETURNING *'),
      parameters: params,
    );
    if (rows.isEmpty) return notFound();
    return ok({'user': _userToJson(rows.first.toColumnMap())});
  }

  Future<Response> _toggleActive(Request req, String id) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final body = await readJsonMap(req);
    final isActive = body?['isActive'] as bool?;
    if (isActive == null) return badRequest('isActive (bool) required');
    final rows = await pool.execute(
      Sql.named(
          'UPDATE users SET is_active = @a WHERE id = @id RETURNING *'),
      parameters: {'a': isActive, 'id': id},
    );
    if (rows.isEmpty) return notFound();
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
