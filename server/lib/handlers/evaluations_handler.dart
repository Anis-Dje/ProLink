import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_helpers.dart';
import '../middleware.dart';

class EvaluationsHandler {
  EvaluationsHandler({required this.pool});
  final Pool<void> pool;

  Router get router {
    final r = Router();
    r.get('/', _list);
    r.post('/', _create);
    r.delete('/<id>', _delete);
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
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await pool.execute(
      Sql.named('''
        SELECT * FROM evaluations $where ORDER BY evaluation_date DESC
      '''),
      parameters: values,
    );
    return ok({
      'evaluations':
          rows.map((r) => _toJson(r.toColumnMap())).toList(),
    });
  }

  Future<Response> _create(Request req) async {
    if (req.userRole != 'mentor' && req.userRole != 'admin') {
      return forbidden('mentor or admin only');
    }
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final internId = body['internId'] as String?;
    final title = (body['title'] as String?)?.trim();
    final description = (body['description'] as String?) ?? '';
    final criteriaRaw = body['criteria'];
    final overall = (body['overallScore'] as num?)?.toDouble() ?? 0.0;
    final comment = (body['comment'] as String?) ?? '';

    if (internId == null || title == null) {
      return badRequest('internId and title required');
    }

    final criteria = criteriaRaw is Map ? criteriaRaw : <String, dynamic>{};
    final mentorId = req.userId!;

    final rows = await pool.execute(
      Sql.named('''
        INSERT INTO evaluations
          (intern_id, mentor_id, title, description, criteria,
           overall_score, comment)
        VALUES
          (@internId, @mentorId, @title, @description, @criteria::jsonb,
           @overall, @comment)
        RETURNING *
      '''),
      parameters: {
        'internId': internId,
        'mentorId': mentorId,
        'title': title,
        'description': description,
        'criteria': jsonEncode(criteria),
        'overall': overall,
        'comment': comment,
      },
    );
    return created({'evaluation': _toJson(rows.first.toColumnMap())});
  }

  Future<Response> _delete(Request req, String id) async {
    if (req.userRole != 'mentor' && req.userRole != 'admin') {
      return forbidden();
    }
    final rows = await pool.execute(
      Sql.named('DELETE FROM evaluations WHERE id = @id RETURNING id'),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return notFound();
    return ok({'deleted': id});
  }
}

Map<String, dynamic> _toJson(Map<String, dynamic> r) {
  final criteria = r['criteria'];
  return {
    'id': r['id'],
    'internId': r['intern_id'],
    'mentorId': r['mentor_id'],
    'title': r['title'],
    'description': r['description'],
    'criteria': criteria is String ? jsonDecode(criteria) : criteria,
    'overallScore': (r['overall_score'] as num?)?.toDouble() ?? 0.0,
    'comment': r['comment'],
    'evaluationDate': isoOrNull(r['evaluation_date'] as DateTime?),
  };
}
