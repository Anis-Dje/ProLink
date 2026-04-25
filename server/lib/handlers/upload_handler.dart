import 'dart:io';

import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../json_helpers.dart';

/// Handles `POST /upload` (multipart/form-data with one or more `file` parts)
/// and writes files to local disk under [uploadDir]. Returns the public URLs.
class UploadHandler {
  UploadHandler({
    required this.uploadDir,
    required this.publicBaseUrl,
  });

  final String uploadDir;
  final String publicBaseUrl;
  static const _uuid = Uuid();

  Router get router {
    final r = Router();
    r.post('/', _upload);
    return r;
  }

  Future<Response> _upload(Request req) async {
    final form = req.formData();
    if (form == null) {
      return badRequest('multipart/form-data required');
    }
    final dir = Directory(uploadDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final urls = <String>[];

    await for (final entry in form.formData) {
      if (entry.filename == null) continue; // skip non-file fields
      final ext = _safeExtension(entry.filename!);
      final id = _uuid.v4();
      final filename = '$id$ext';
      final outFile = File('${dir.path}/$filename');
      final sink = outFile.openWrite();
      try {
        await entry.part.forEach(sink.add);
      } finally {
        await sink.close();
      }
      urls.add('$publicBaseUrl/files/$filename');
    }

    if (urls.isEmpty) {
      return badRequest('no file part found');
    }
    return ok({'urls': urls, 'url': urls.first});
  }

  static String _safeExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) {
      // Fall back to MIME-guessed extension or empty.
      final mime = lookupMimeType(filename);
      return switch (mime) {
        'image/png' => '.png',
        'image/jpeg' => '.jpg',
        'application/pdf' => '.pdf',
        _ => '',
      };
    }
    final ext = filename.substring(dot).toLowerCase();
    // Strip anything other than [a-z0-9.] for safety.
    return ext.replaceAll(RegExp(r'[^a-z0-9.]'), '');
  }
}
