import 'dart:io';

import 'package:prolink_server/auth.dart';
import 'package:prolink_server/config.dart';
import 'package:prolink_server/db.dart';
import 'package:prolink_server/handlers/attendance_handler.dart';
import 'package:prolink_server/handlers/auth_handler.dart';
import 'package:prolink_server/handlers/departments_handler.dart';
import 'package:prolink_server/handlers/evaluations_handler.dart';
import 'package:prolink_server/handlers/interns_handler.dart';
import 'package:prolink_server/handlers/notifications_handler.dart';
import 'package:prolink_server/handlers/schedules_handler.dart';
import 'package:prolink_server/handlers/training_files_handler.dart';
import 'package:prolink_server/handlers/upload_handler.dart';
import 'package:prolink_server/handlers/users_handler.dart';
import 'package:prolink_server/json_helpers.dart';
import 'package:prolink_server/middleware.dart';
import 'package:prolink_server/migrations.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

Future<void> main(List<String> args) async {
  final config = ServerConfig.fromEnv();
  print('[boot] connecting to Postgres...');
  final pool = await openPool(config.databaseUrl);
  print('[boot] connected.');

  await runMigrations(pool);

  final authHelper = AuthHelper(config.jwtSecret);

  final authHandler = AuthHandler(pool: pool, auth: authHelper);
  final usersHandler = UsersHandler(pool: pool, auth: authHelper);
  final internsHandler = InternsHandler(pool: pool);
  final departmentsHandler = DepartmentsHandler(pool: pool);
  final evaluationsHandler = EvaluationsHandler(pool: pool);
  final attendanceHandler = AttendanceHandler(pool: pool);
  final schedulesHandler = SchedulesHandler(pool: pool);
  final trainingHandler = TrainingFilesHandler(pool: pool);
  final notificationsHandler = NotificationsHandler(pool: pool);
  final uploadHandler = UploadHandler(
    uploadDir: config.uploadDir,
    publicBaseUrl: config.publicBaseUrl,
  );

  // Auth-required pipeline mounts everything under /api except /auth/login,
  // /auth/register, /health.
  final api = Router();
  api.mount('/auth', authHandler.router.call);
  api.mount(
    '/users',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(usersHandler.router.call),
  );
  api.mount(
    '/interns',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(internsHandler.router.call),
  );
  api.mount(
    '/departments',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(departmentsHandler.router.call),
  );
  api.mount(
    '/evaluations',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(evaluationsHandler.router.call),
  );
  api.mount(
    '/attendance',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(attendanceHandler.router.call),
  );
  api.mount(
    '/schedules',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(schedulesHandler.router.call),
  );
  api.mount(
    '/training-files',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(trainingHandler.router.call),
  );
  api.mount(
    '/notifications',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(notificationsHandler.router.call),
  );
  api.mount(
    '/upload',
    Pipeline()
        .addMiddleware(requireAuth(authHelper))
        .addHandler(uploadHandler.router.call),
  );
  api.get('/health', (Request _) => ok({'status': 'ok'}));

  // Static file server for uploaded files.
  final filesHandler = createStaticHandler(
    config.uploadDir,
    listDirectories: false,
  );

  final root = Router();
  root.mount('/api', api.call);
  root.mount('/files', filesHandler);
  root.get('/', (Request _) => ok({'service': 'prolink-api'}));

  final pipeline = Pipeline()
      .addMiddleware(requestLogger())
      .addMiddleware(corsHeaders())
      .addMiddleware(errorHandler())
      .addHandler(root.call);

  final server = await shelf_io.serve(
    pipeline,
    config.host,
    config.port,
  );
  print('[boot] listening on http://${server.address.address}:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    print('[boot] shutting down...');
    await server.close(force: true);
    await pool.close();
    exit(0);
  });
}
