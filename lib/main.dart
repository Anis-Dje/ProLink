import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'models/user_model.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';

// Auth screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/register_screen.dart';

// Admin screens
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/assign_intern_screen.dart';
import 'screens/admin/manage_interns_screen.dart';
import 'screens/admin/upload_documents_screen.dart';
import 'screens/admin/user_management_screen.dart';

// Mentor screens
import 'screens/mentor/assigned_interns_screen.dart';
import 'screens/mentor/attendance_tracking_screen.dart';
import 'screens/mentor/evaluate_intern_screen.dart';
import 'screens/mentor/mentor_dashboard.dart';
import 'screens/mentor/upload_training_screen.dart';

// Intern screens
import 'screens/intern/evaluations_screen.dart';
import 'screens/intern/intern_dashboard.dart';
import 'screens/intern/schedule_screen.dart';
import 'screens/intern/training_files_screen.dart';
import 'screens/intern/work_id_card_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final authService = AuthService(apiClient);
  // Resolve any persisted session before the first frame so the router can
  // pick the right initial route.
  await authService.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(ProLinkApp(
    apiClient: apiClient,
    authService: authService,
  ));
}

class ProLinkApp extends StatelessWidget {
  const ProLinkApp({
    super.key,
    required this.apiClient,
    required this.authService,
  });

  final ApiClient apiClient;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(apiClient),
        ),
        Provider<StorageService>(
          create: (_) => StorageService(apiClient),
        ),
      ],
      child: _AppWithRouter(authService: authService),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter({required this.authService});
  final AuthService authService;

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/login',
    refreshListenable: widget.authService,
    redirect: (context, state) {
      if (widget.authService.initializing) return null;

      final user = widget.authService.currentUser;
      final isLoggedIn = user != null;
      final loc = state.matchedLocation;
      final isOnAuth = loc == '/login' || loc == '/register';

      if (!isLoggedIn && !isOnAuth && loc != '/pending') return '/login';
      if (isLoggedIn && isOnAuth) {
        return _homeFor(user);
      }

      if (isLoggedIn) {
        final role = user.role;
        if (role == UserRole.admin && loc == '/pending') {
          return '/admin/dashboard';
        }
        // Prevent role cross-navigation.
        if (role == UserRole.intern &&
            (loc.startsWith('/admin') || loc.startsWith('/mentor'))) {
          return '/intern/dashboard';
        }
        if (role == UserRole.mentor &&
            (loc.startsWith('/admin') || loc.startsWith('/intern'))) {
          return '/mentor/dashboard';
        }
        if (role == UserRole.admin &&
            (loc.startsWith('/mentor') || loc.startsWith('/intern'))) {
          return '/admin/dashboard';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/pending',
          builder: (_, __) => const PendingApprovalScreen()),

      // Admin
      GoRoute(
          path: '/admin/dashboard',
          builder: (_, __) => const AdminDashboard()),
      GoRoute(
          path: '/admin/interns',
          builder: (_, __) => const ManageInternsScreen()),
      GoRoute(
          path: '/admin/assign',
          builder: (_, __) => const AssignInternScreen()),
      GoRoute(
          path: '/admin/documents',
          builder: (_, __) => const UploadDocumentsScreen()),
      GoRoute(
          path: '/admin/users',
          builder: (_, __) => const UserManagementScreen()),

      // Mentor
      GoRoute(
          path: '/mentor/dashboard',
          builder: (_, __) => const MentorDashboard()),
      GoRoute(
          path: '/mentor/interns',
          builder: (_, __) => const AssignedInternsScreen()),
      GoRoute(
          path: '/mentor/evaluate',
          builder: (_, __) => const EvaluateInternScreen()),
      GoRoute(
          path: '/mentor/attendance',
          builder: (_, __) => const AttendanceTrackingScreen()),
      GoRoute(
          path: '/mentor/training',
          builder: (_, __) => const UploadTrainingScreen()),

      // Intern
      GoRoute(
          path: '/intern/dashboard',
          builder: (_, __) => const InternDashboard()),
      GoRoute(
          path: '/intern/id-card',
          builder: (_, __) => const WorkIdCardScreen()),
      GoRoute(
          path: '/intern/schedule',
          builder: (_, __) => const ScheduleScreen()),
      GoRoute(
          path: '/intern/training',
          builder: (_, __) => const TrainingFilesScreen()),
      GoRoute(
          path: '/intern/evaluations',
          builder: (_, __) => const EvaluationsScreen()),
    ],
  );

  String _homeFor(UserModel user) {
    switch (user.role) {
      case UserRole.admin:
        return '/admin/dashboard';
      case UserRole.mentor:
        return '/mentor/dashboard';
      case UserRole.intern:
        return '/intern/dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
