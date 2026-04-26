import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        // Named routes — course pattern (Navigator.pushNamed, Navigator.pop).
        home: const RootGate(),
        routes: {
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.register: (_) => const RegisterScreen(),
          AppRoutes.pending: (_) => const PendingApprovalScreen(),

          AppRoutes.adminDashboard: (_) => const AdminDashboard(),
          AppRoutes.adminInterns: (_) => const ManageInternsScreen(),
          AppRoutes.adminAssign: (_) => const AssignInternScreen(),
          AppRoutes.adminDocuments: (_) => const UploadDocumentsScreen(),
          AppRoutes.adminUsers: (_) => const UserManagementScreen(),

          AppRoutes.mentorDashboard: (_) => const MentorDashboard(),
          AppRoutes.mentorInterns: (_) => const AssignedInternsScreen(),
          AppRoutes.mentorEvaluate: (_) => const EvaluateInternScreen(),
          AppRoutes.mentorAttendance: (_) => const AttendanceTrackingScreen(),
          AppRoutes.mentorTraining: (_) => const UploadTrainingScreen(),

          AppRoutes.internDashboard: (_) => const InternDashboard(),
          AppRoutes.internIdCard: (_) => const WorkIdCardScreen(),
          AppRoutes.internSchedule: (_) => const ScheduleScreen(),
          AppRoutes.internTraining: (_) => const TrainingFilesScreen(),
          AppRoutes.internEvaluations: (_) => const EvaluationsScreen(),
        },
      ),
    );
  }
}

/// Routes table. Keeping them as plain `String` constants matches the
/// course's `Navigator.pushNamed(context, '/home')` examples while making
/// refactors easier.
abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const pending = '/pending';

  static const adminDashboard = '/admin/dashboard';
  static const adminInterns = '/admin/interns';
  static const adminAssign = '/admin/assign';
  static const adminDocuments = '/admin/documents';
  static const adminUsers = '/admin/users';

  static const mentorDashboard = '/mentor/dashboard';
  static const mentorInterns = '/mentor/interns';
  static const mentorEvaluate = '/mentor/evaluate';
  static const mentorAttendance = '/mentor/attendance';
  static const mentorTraining = '/mentor/training';

  static const internDashboard = '/intern/dashboard';
  static const internIdCard = '/intern/id-card';
  static const internSchedule = '/intern/schedule';
  static const internTraining = '/intern/training';
  static const internEvaluations = '/intern/evaluations';

  static String homeFor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return adminDashboard;
      case UserRole.mentor:
        return mentorDashboard;
      case UserRole.intern:
        return internDashboard;
    }
  }
}

/// Selects the initial screen based on auth state. Rebuilds whenever
/// AuthService notifies (Provider `Consumer`), so login / logout
/// automatically swap the visible screen with no manual Navigator work.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.initializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = auth.currentUser;
        if (user == null) return const LoginScreen();
        switch (user.role) {
          case UserRole.admin:
            return const AdminDashboard();
          case UserRole.mentor:
            return const MentorDashboard();
          case UserRole.intern:
            return const InternDashboard();
        }
      },
    );
  }
}
