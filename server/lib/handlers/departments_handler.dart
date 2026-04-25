import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_helpers.dart';
import '../middleware.dart';

class DepartmentsHandler {
  DepartmentsHandler({required this.pool});
  final Pool<void> pool;

  Router get router {
    final r = Router();
    r.get('/', _list);
    r.post('/', _create);
    r.delete('/<id>', _delete);
    return r;
  }

  Future<Response> _list(Request req) async {
    final rows = await pool.execute(
      Sql.named('SELECT * FROM departments ORDER BY name'),
    );
    return ok({
      'departments':
          rows.map((r) => _toJson(r.toColumnMap())).toList(),
    });
  }

  Future<Response> _create(Request req) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');
    final name = (body['name'] as String?)?.trim();
    final description = (body['description'] as String?) ?? '';
    if (name == null || name.isEmpty) return badRequest('name required');
    try {
      final rows = await pool.execute(
        Sql.named('''
          INSERT INTO departments (name, description)
          VALUES (@name, @description) RETURNING *
        '''),
        parameters: {'name': name, 'description': description},
      );
      return created({'department': _toJson(rows.first.toColumnMap())});
    } on ServerException catch (e) {
      if (e.code == '23505') {
        return jsonResponse(409, {'error': 'name_taken'});
      }
      rethrow;
    }
  }

  Future<Response> _delete(Request req, String id) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final rows = await pool.execute(
      Sql.named('DELETE FROM departments WHERE id = @id RETURNING id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return notFound();
    return ok({'deleted': id});
  }
}

Map<String, dynamic> _toJson(Map<String, dynamic> r) => {
      'id': r['id'],
      'name': r['name'],
      'description': r['description'],
      'createdAt': isoOrNull(r['created_at'] as DateTime?),
    };
