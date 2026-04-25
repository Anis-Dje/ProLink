import 'package:postgres/postgres.dart';

/// Parses a `postgres://user:pass@host:port/db?sslmode=require` URL into a
/// [Endpoint] that the postgres package understands.
Endpoint parseDatabaseUrl(String url) {
  final uri = Uri.parse(url);
  if (uri.scheme != 'postgres' && uri.scheme != 'postgresql') {
    throw FormatException('Expected postgres(ql):// scheme, got ${uri.scheme}');
  }
  final userInfo = uri.userInfo.split(':');
  if (userInfo.length != 2) {
    throw const FormatException('DATABASE_URL must include user:password');
  }
  final dbName = uri.path.replaceFirst('/', '');
  return Endpoint(
    host: uri.host,
    port: uri.port == 0 ? 5432 : uri.port,
    database: dbName,
    username: Uri.decodeComponent(userInfo[0]),
    password: Uri.decodeComponent(userInfo[1]),
  );
}

/// Returns connection settings honoring `?sslmode=` in the URL.
ConnectionSettings parseConnectionSettings(String url) {
  final uri = Uri.parse(url);
  final sslMode = uri.queryParameters['sslmode'] ?? 'require';
  return ConnectionSettings(
    sslMode: switch (sslMode) {
      'disable' => SslMode.disable,
      'require' => SslMode.require,
      _ => SslMode.require,
    },
  );
}

/// Opens a connection pool using a Postgres URL.
Future<Pool<void>> openPool(String url) async {
  final endpoint = parseDatabaseUrl(url);
  final settings = parseConnectionSettings(url);
  final pool = Pool.withEndpoints(
    [endpoint],
    settings: PoolSettings(
      maxConnectionCount: 10,
      sslMode: settings.sslMode,
    ),
  );
  // Warm up the pool & verify the connection works at boot.
  await pool.execute('SELECT 1');
  return pool;
}
