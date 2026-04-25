import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_helpers.dart';
import '../middleware.dart';

class SchedulesHandler {
  SchedulesHandler({required this.pool});
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
      Sql.named('SELECT * FROM schedules ORDER BY upload_date DESC'),
    );
    return ok({
      'schedules':
          rows.map((r) => _toJson(r.toColumnMap())).toList(),
    });
  }

  Future<Response> _create(Request req) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');
    final title = (body['title'] as String?)?.trim();
    final fileUrl = (body['fileUrl'] as String?)?.trim();
    final description = (body['description'] as String?) ?? '';
    final weekLabel = (body['weekLabel'] as String?) ?? '';
    if (title == null || fileUrl == null) {
      return badRequest('title and fileUrl required');
    }
    final rows = await pool.execute(
      Sql.named('''
        INSERT INTO schedules
          (title, description, file_url, uploaded_by, week_label)
        VALUES (@title, @description, @fileUrl, @uploadedBy, @weekLabel)
        RETURNING *
      '''),
      parameters: {
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'uploadedBy': req.userId,
        'weekLabel': weekLabel,
      },
    );
    return created({'schedule': _toJson(rows.first.toColumnMap())});
  }

  Future<Response> _delete(Request req, String id) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final rows = await pool.execute(
      Sql.named('DELETE FROM schedules WHERE id = @id RETURNING id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return notFound();
    return ok({'deleted': id});
  }
}

Map<String, dynamic> _toJson(Map<String, dynamic> r) => {
      'id': r['id'],
      'title': r['title'],
      'description': r['description'],
      'fileUrl': r['file_url'],
      'uploadedBy': r['uploaded_by'],
      'uploadDate': isoOrNull(r['upload_date'] as DateTime?),
      'weekLabel': r['week_label'],
    };
