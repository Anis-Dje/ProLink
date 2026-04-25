import 'dart:io';

import 'package:postgres/postgres.dart';

/// Runs every `migrations/*.sql` file in lexical order against the database.
/// Migration files are expected to be idempotent (use `IF NOT EXISTS` etc.).
Future<void> runMigrations(Pool<void> pool, {String dir = 'migrations'}) async {
  final directory = Directory(dir);
  if (!directory.existsSync()) {
    print('[migrations] $dir not found, skipping');
    return;
  }
  final files = directory
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    final sql = await f.readAsString();
    print('[migrations] applying ${f.uri.pathSegments.last}');
    // Multi-statement migrations require simple-query mode (no prepare).
    await pool.execute(sql, queryMode: QueryMode.simple);
  }
  print('[migrations] done (${files.length} file(s))');
}
