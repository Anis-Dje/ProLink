import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_helpers.dart';
import '../middleware.dart';

class AttendanceHandler {
  AttendanceHandler({required this.pool});
  final Pool<void> pool;

  Router get router {
    final r = Router();
    r.get('/', _list);
    r.post('/', _upsert);
    return r;
  }

  Future<Response> _list(Request req) async {
    final params = req.url.queryParameters;
    final clauses = <String>[];
    final values = <String, Object?>{};
    if (params['internId'] != null) {
      clauses.add('intern_id = @internId');
      values['internId'] = params['internId'];
    }
    if (params['mentorId'] != null) {
      clauses.add('mentor_id = @mentorId');
      values['mentorId'] = params['mentorId'];
    }
    if (params['from'] != null) {
      clauses.add('date >= @from::date');
      values['from'] = params['from'];
    }
    if (params['to'] != null) {
      clauses.add('date <= @to::date');
      values['to'] = params['to'];
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await pool.execute(
      Sql.named(
          'SELECT * FROM attendance $where ORDER BY date DESC'),
      parameters: values,
    );
    return ok({
      'attendance':
          rows.map((r) => _toJson(r.toColumnMap())).toList(),
    });
  }

  /// Upserts an attendance row keyed by (intern_id, date).
  Future<Response> _upsert(Request req) async {
    if (req.userRole != 'mentor' && req.userRole != 'admin') {
      return forbidden();
    }
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final internId = body['internId'] as String?;
    final date = body['date'] as String?;
    final status = body['status'] as String?;
    final notes = body['notes'] as String?;
    if (internId == null || date == null || status == null) {
      return badRequest('internId, date (YYYY-MM-DD), status required');
    }
    final mentorId = req.userId!;

    final rows = await pool.execute(
      Sql.named('''
        INSERT INTO attendance (intern_id, mentor_id, date, status, notes)
        VALUES (@internId, @mentorId, @date::date, @status, @notes)
        ON CONFLICT (intern_id, date) DO UPDATE
           SET status = EXCLUDED.status,
               notes = EXCLUDED.notes,
               mentor_id = EXCLUDED.mentor_id
        RETURNING *
      '''),
      parameters: {
        'internId': internId,
        'mentorId': mentorId,
        'date': date,
        'status': status,
        'notes': notes,
      },
    );
    return ok({'attendance': _toJson(rows.first.toColumnMap())});
  }
}

Map<String, dynamic> _toJson(Map<String, dynamic> r) => {
      'id': r['id'],
      'internId': r['intern_id'],
      'mentorId': r['mentor_id'],
      'date': (r['date'] as DateTime?)?.toUtc().toIso8601String(),
      'status': r['status'],
      'notes': r['notes'],
    };
