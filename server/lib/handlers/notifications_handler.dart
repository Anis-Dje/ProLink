import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_helpers.dart';
import '../middleware.dart';

class NotificationsHandler {
  NotificationsHandler({required this.pool});
  final Pool<void> pool;

  Router get router {
    final r = Router();
    r.get('/', _list);
    r.post('/', _create);
    r.post('/<id>/read', _markRead);
    return r;
  }

  Future<Response> _list(Request req) async {
    final id = req.userId!;
    final rows = await pool.execute(
      Sql.named('''
        SELECT * FROM notifications
        WHERE user_id = @id
        ORDER BY created_at DESC LIMIT 100
      '''),
      parameters: {'id': id},
    );
    return ok({
      'notifications':
          rows.map((r) => _toJson(r.toColumnMap())).toList(),
    });
  }

  Future<Response> _create(Request req) async {
    if (req.userRole != 'admin' && req.userRole != 'mentor') {
      return forbidden();
    }
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final userId = body['userId'] as String?;
    final title = (body['title'] as String?)?.trim();
    final message = (body['message'] as String?) ?? '';
    final type = (body['type'] as String?) ?? 'info';
    if (userId == null || title == null) {
      return badRequest('userId and title required');
    }

    final rows = await pool.execute(
      Sql.named('''
        INSERT INTO notifications (user_id, title, message, type)
        VALUES (@userId, @title, @message, @type)
        RETURNING *
      '''),
      parameters: {
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
      },
    );
    return created({'notification': _toJson(rows.first.toColumnMap())});
  }

  Future<Response> _markRead(Request req, String id) async {
    final rows = await pool.execute(
      Sql.named('''
        UPDATE notifications SET is_read = TRUE
        WHERE id = @id AND user_id = @userId RETURNING *
      '''),
      parameters: {'id': id, 'userId': req.userId},
    );
    if (rows.isEmpty) return notFound();
    return ok({'notification': _toJson(rows.first.toColumnMap())});
  }
}

Map<String, dynamic> _toJson(Map<String, dynamic> r) => {
      'id': r['id'],
      'userId': r['user_id'],
      'title': r['title'],
      'message': r['message'],
      'type': r['type'],
      'isRead': r['is_read'],
      'createdAt': isoOrNull(r['created_at'] as DateTime?),
    };
