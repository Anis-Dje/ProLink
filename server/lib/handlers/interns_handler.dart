import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_helpers.dart';
import '../middleware.dart';

/// /interns/* routes.
class InternsHandler {
  InternsHandler({required this.pool});
  final Pool<void> pool;

  Router get router {
    final r = Router();
    r.get('/', _list);
    r.get('/<id>', _get);
    r.get('/by-user/<userId>', _byUser);
    r.patch('/<id>', _update);
    r.post('/<id>/approve', _approve);
    r.post('/<id>/reject', _reject);
    r.post('/<id>/assign', _assign);
    return r;
  }

  Future<Response> _list(Request req) async {
    final params = req.url.queryParameters;
    final status = params['status'];
    final mentorId = params['mentorId'];
    final query = params['q'];

    final clauses = <String>[];
    final values = <String, Object?>{};
    if (status != null) {
      clauses.add('i.status = @status');
      values['status'] = status;
    }
    if (mentorId != null) {
      clauses.add('i.mentor_id = @mentorId');
      values['mentorId'] = mentorId;
    }
    if (query != null && query.trim().isNotEmpty) {
      clauses.add(
        '(u.full_name ILIKE @q OR u.email ILIKE @q '
        'OR i.student_id ILIKE @q OR i.department ILIKE @q)',
      );
      values['q'] = '%${query.trim()}%';
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';

    final rows = await pool.execute(
      Sql.named('''
        SELECT i.*, u.email, u.full_name, u.phone, u.profile_photo_url
          FROM interns i JOIN users u ON u.id = i.user_id
        $where
        ORDER BY i.registration_date DESC
      '''),
      parameters: values,
    );
    return ok({
      'interns': rows.map((r) => _toJson(r.toColumnMap())).toList(),
    });
  }

  Future<Response> _get(Request req, String id) async {
    final rows = await pool.execute(
      Sql.named('''
        SELECT i.*, u.email, u.full_name, u.phone, u.profile_photo_url
          FROM interns i JOIN users u ON u.id = i.user_id
        WHERE i.id = @id
      '''),
      parameters: {'id': id},
    );
    if (rows.isEmpty) return notFound();
    return ok({'intern': _toJson(rows.first.toColumnMap())});
  }

  Future<Response> _byUser(Request req, String userId) async {
    final rows = await pool.execute(
      Sql.named('''
        SELECT i.*, u.email, u.full_name, u.phone, u.profile_photo_url
          FROM interns i JOIN users u ON u.id = i.user_id
        WHERE i.user_id = @userId
      '''),
      parameters: {'userId': userId},
    );
    if (rows.isEmpty) return notFound();
    return ok({'intern': _toJson(rows.first.toColumnMap())});
  }

  Future<Response> _update(Request req, String id) async {
    if (req.userRole != 'admin' && req.userRole != 'mentor') {
      return forbidden();
    }
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final updates = <String, Object?>{};
    const allowed = {
      'studentId': 'student_id',
      'university': 'university',
      'specialization': 'specialization',
      'department': 'department',
      'mentorId': 'mentor_id',
      'status': 'status',
      'startDate': 'start_date',
      'endDate': 'end_date',
    };
    body.forEach((k, v) {
      if (allowed.containsKey(k)) {
        updates[allowed[k]!] = v;
      }
    });
    if (updates.isEmpty) return badRequest('no fields to update');

    final setSql = updates.keys.map((k) => '$k = @$k').join(', ');
    final result = await pool.execute(
      Sql.named(
          'UPDATE interns SET $setSql WHERE id = @id RETURNING id'),
      parameters: {...updates, 'id': id},
    );
    if (result.isEmpty) return notFound();
    return _get(req, id);
  }

  Future<Response> _approve(Request req, String id) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final body = await readJsonMap(req) ?? {};
    final start = body['startDate'] as String?;
    final end = body['endDate'] as String?;
    final rows = await pool.execute(
      Sql.named('''
        UPDATE interns
           SET status = 'active',
               start_date = COALESCE(@start::timestamptz, NOW()),
               end_date = @end::timestamptz
         WHERE id = @id RETURNING id
      '''),
      parameters: {'start': start, 'end': end, 'id': id},
    );
    if (rows.isEmpty) return notFound();
    return _get(req, id);
  }

  Future<Response> _reject(Request req, String id) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final body = await readJsonMap(req) ?? {};
    final reason = (body['reason'] as String?) ?? '';
    final rows = await pool.execute(
      Sql.named('''
        UPDATE interns SET status = 'rejected', rejection_reason = @reason
         WHERE id = @id RETURNING id
      '''),
      parameters: {'reason': reason, 'id': id},
    );
    if (rows.isEmpty) return notFound();
    return _get(req, id);
  }

  Future<Response> _assign(Request req, String id) async {
    if (req.userRole != 'admin') return forbidden('admin only');
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');
    final mentorId = body['mentorId'] as String?;
    final department = body['department'] as String?;
    if (mentorId == null && department == null) {
      return badRequest('mentorId and/or department required');
    }
    final updates = <String, Object?>{};
    if (mentorId != null) updates['mentor_id'] = mentorId;
    if (department != null) updates['department'] = department;
    final setSql = updates.keys.map((k) => '$k = @$k').join(', ');
    final rows = await pool.execute(
      Sql.named(
          'UPDATE interns SET $setSql WHERE id = @id RETURNING id'),
      parameters: {...updates, 'id': id},
    );
    if (rows.isEmpty) return notFound();
    return _get(req, id);
  }
}

Map<String, dynamic> _toJson(Map<String, dynamic> r) => {
      'id': r['id'],
      'userId': r['user_id'],
      'fullName': r['full_name'] ?? '',
      'email': r['email'] ?? '',
      'phone': r['phone'] ?? '',
      'profilePhotoUrl': r['profile_photo_url'],
      'studentId': r['student_id'],
      'university': r['university'],
      'specialization': r['specialization'],
      'department': r['department'],
      'mentorId': r['mentor_id'],
      'status': r['status'],
      'registrationDate': isoOrNull(r['registration_date'] as DateTime?),
      'startDate': isoOrNull(r['start_date'] as DateTime?),
      'endDate': isoOrNull(r['end_date'] as DateTime?),
      'rejectionReason': r['rejection_reason'],
    };
