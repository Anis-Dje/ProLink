import 'dart:io';

/// Server configuration sourced from environment variables.
class ServerConfig {
  ServerConfig({
    required this.databaseUrl,
    required this.jwtSecret,
    required this.port,
    required this.host,
    required this.uploadDir,
    required this.publicBaseUrl,
  });

  final String databaseUrl;
  final String jwtSecret;
  final int port;
  final String host;
  final String uploadDir;
  final String publicBaseUrl;

  factory ServerConfig.fromEnv() {
    final env = Platform.environment;
    final dbUrl = env['DATABASE_URL'];
    if (dbUrl == null || dbUrl.isEmpty) {
      throw StateError(
        'DATABASE_URL is required (Neon Postgres connection string).',
      );
    }
    final port = int.tryParse(env['PORT'] ?? '8080') ?? 8080;
    return ServerConfig(
      databaseUrl: dbUrl,
      jwtSecret: env['JWT_SECRET'] ??
          'dev-only-secret-change-me-' * 4, // 100+ chars for dev
      port: port,
      host: env['HOST'] ?? '0.0.0.0',
      uploadDir: env['UPLOAD_DIR'] ?? 'uploads',
      publicBaseUrl: env['PUBLIC_BASE_URL'] ?? 'http://localhost:$port',
    );
  }
}
