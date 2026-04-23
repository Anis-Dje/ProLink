import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';

// Auth screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/pending_approval_screen.dart';

// Admin screens
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/manage_interns_screen.dart';
import 'screens/admin/assign_intern_screen.dart';
import 'screens/admin/upload_documents_screen.dart';
import 'screens/admin/user_management_screen.dart';

// Mentor screens
import 'screens/mentor/mentor_dashboard.dart';
import 'screens/mentor/assigned_interns_screen.dart';
import 'screens/mentor/evaluate_intern_screen.dart';
import 'screens/mentor/attendance_tracking_screen.dart';
import 'screens/mentor/upload_training_screen.dart';

// Intern screens
import 'screens/intern/intern_dashboard.dart';
import 'screens/intern/work_id_card_screen.dart';
import 'screens/intern/schedule_screen.dart';
import 'screens/intern/training_files_screen.dart';
import 'screens/intern/evaluations_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ProLinkApp());
}

class ProLinkApp extends StatelessWidget {
  const ProLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<StorageService>(create: (_) => StorageService()),
        StreamProvider<User?>(
          create: (ctx) => ctx.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: const _AppWithRouter(),
    );
  }
}

class _AppWithRouter extends StatefulWidget {
  const _AppWithRouter();

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  UserModel? _currentUserModel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _listenToAuth();
  }

  void _listenToAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        setState(() {
          _currentUserModel = null;
          _loading = false;
        });
      } else {
        final authService = context.read<AuthService>();
        final userModel = await authService.getUserById(user.uid);
        setState(() {
          _currentUserModel = userModel;
          _loading = false;
        });
      }
    });
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (_loading) return null;

      final isLoggedIn = _currentUserModel != null;
      final isOnAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isOnAuth) return '/login';
      if (isLoggedIn && isOnAuth) {
        return _getHomeRouteForUser(_currentUserModel!);
      }

      if (isLoggedIn) {
        final role = _currentUserModel!.role;
        final loc = state.matchedLocation;

        if (role == UserRole.admin && loc == '/pending') return '/admin/dashboard';

        if (role == UserRole.intern) {
          // Check pending status via route
          if (loc.startsWith('/admin') || loc.startsWith('/mentor')) {
            return '/intern/dashboard';
          }
        }
        if (role == UserRole.mentor) {
          if (loc.startsWith('/admin') || loc.startsWith('/intern')) {
            return '/mentor/dashboard';
          }
        }
        if (role == UserRole.admin) {
          if (loc.startsWith('/mentor') || loc.startsWith('/intern')) {
            return '/admin/dashboard';
          }
        }
      }

      return null;
    },
    refreshListenable: _RouterNotifier(this),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/pending', builder: (_, __) => const PendingApprovalScreen()),

      // Admin routes
      GoRoute(path: '/admin/dashboard', builder: (_, __) => const AdminDashboard()),
      GoRoute(path: '/admin/interns', builder: (_, __) => const ManageInternsScreen()),
      GoRoute(path: '/admin/assign', builder: (_, __) => const AssignInternScreen()),
      GoRoute(path: '/admin/documents', builder: (_, __) => const UploadDocumentsScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const UserManagementScreen()),

      // Mentor routes
      GoRoute(path: '/mentor/dashboard', builder: (_, __) => const MentorDashboard()),
      GoRoute(path: '/mentor/interns', builder: (_, __) => const AssignedInternsScreen()),
      GoRoute(path: '/mentor/evaluate', builder: (_, __) => const EvaluateInternScreen()),
      GoRoute(path: '/mentor/attendance', builder: (_, __) => const AttendanceTrackingScreen()),
      GoRoute(path: '/mentor/training', builder: (_, __) => const UploadTrainingScreen()),

      // Intern routes
      GoRoute(path: '/intern/dashboard', builder: (_, __) => const InternDashboard()),
      GoRoute(path: '/intern/id-card', builder: (_, __) => const WorkIdCardScreen()),
      GoRoute(path: '/intern/schedule', builder: (_, __) => const ScheduleScreen()),
      GoRoute(path: '/intern/training', builder: (_, __) => const TrainingFilesScreen()),
      GoRoute(path: '/intern/evaluations', builder: (_, __) => const EvaluationsScreen()),
    ],
  );

  String _getHomeRouteForUser(UserModel user) {
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

class _RouterNotifier extends ChangeNotifier {
  final _AppWithRouterState _state;
  _RouterNotifier(this._state) {
    _state.addListener(notifyListeners);
  }
}
