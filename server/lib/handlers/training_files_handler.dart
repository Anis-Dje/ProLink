import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../json_helpers.dart';
import '../middleware.dart';

class TrainingFilesHandler {
  TrainingFilesHandler({required this.pool});
  final Pool<void> pool;

  Router get router {
    final r = Router();
    r.get('/', _list);
    r.post('/', _create);
    r.delete('/<id>', _delete);
    return r;
  }

  Future<Response> _list(Request req) async {
    final query = req.url.queryParameters['q']?.trim();
    final rows = (query == null || query.isEmpty)
        ? await pool.execute(
            Sql.named('''
              SELECT * FROM training_files ORDER BY upload_date DESC
            '''),
          )
        : await pool.execute(
            Sql.named('''
              SELECT * FROM training_files
              WHERE title ILIKE @q OR description ILIKE @q
                 OR @raw = ANY(tags)
              ORDER BY upload_date DESC
            '''),
            parameters: {'q': '%$query%', 'raw': query},
          );
    return ok({
      'trainingFiles':
          rows.map((r) => _toJson(r.toColumnMap())).toList(),
    });
  }

  Future<Response> _create(Request req) async {
    if (req.userRole != 'mentor' && req.userRole != 'admin') {
      return forbidden();
    }
    final body = await readJsonMap(req);
    if (body == null) return badRequest('JSON body required');

    final title = (body['title'] as String?)?.trim();
    final fileUrl = (body['fileUrl'] as String?)?.trim();
    final description = (body['description'] as String?) ?? '';
    final fileType = (body['fileType'] as String?) ?? '';
    final tagsRaw = body['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    if (title == null || fileUrl == null) {
      return badRequest('title and fileUrl required');
    }

    final rows = await pool.execute(
      Sql.named('''
        INSERT INTO training_files
          (title, description, file_url, file_type, uploaded_by, tags)
        VALUES
          (@title, @description, @fileUrl, @fileType, @uploadedBy, @tags)
        RETURNING *
      '''),
      parameters: {
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'uploadedBy': req.userId,
        'tags': tags,
      },
    );
    return created({'trainingFile': _toJson(rows.first.toColumnMap())});
  }

  Future<Response> _delete(Request req, String id) async {
    if (req.userRole != 'mentor' && req.userRole != 'admin') {
      return forbidden();
    }
    final rows = await pool.execute(
      Sql.named('DELETE FROM training_files WHERE id = @id RETURNING id'),
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
      'fileType': r['file_type'],
      'uploadedBy': r['uploaded_by'],
      'uploadDate': isoOrNull(r['upload_date'] as DateTime?),
      'tags': (r['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    };
