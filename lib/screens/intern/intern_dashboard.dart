import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/attendance_model.dart';
import '../../models/evaluation_model.dart';
import '../../models/intern_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/cards/stats_card.dart';

/// Intern home dashboard with quick access to the ID card, schedule,
/// training files and evaluations.
class InternDashboard extends StatefulWidget {
  const InternDashboard({super.key});

  @override
  State<InternDashboard> createState() => _InternDashboardState();
}

class _InternDashboardState extends State<InternDashboard> {
  UserModel? _currentUser;
  InternModel? _internProfile;
  List<EvaluationModel> _evaluations = [];
  List<AttendanceModel> _attendance = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await context.read<AuthService>().getCurrentUser();
      final fs = context.read<FirestoreService>();

      InternModel? intern;
      List<EvaluationModel> evals = [];
      List<AttendanceModel> att = [];
      if (user != null) {
        intern = await fs.getInternByUserId(user.id);
        if (intern != null) {
          evals = await fs.getEvaluationsByIntern(intern.id);
          att = await fs.getAttendanceByIntern(intern.id);
        }
      }

      if (mounted) {
        setState(() {
          _currentUser = user;
          _internProfile = intern;
          _evaluations = evals;
          _attendance = att;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _avgScore {
    if (_evaluations.isEmpty) return 0;
    final sum = _evaluations.map((e) => e.overallScore).reduce((a, b) => a + b);
    return sum / _evaluations.length;
  }

  int get _presenceRate {
    if (_attendance.isEmpty) return 100;
    final present = _attendance
        .where((a) =>
            a.status == AppConstants.attendancePresent ||
            a.status == AppConstants.attendanceLate)
        .length;
    return (present * 100 / _attendance.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pro-Link Intern'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      drawer: _currentUser != null ? AppDrawer(user: _currentUser!) : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildIdCardTeaser(),
                    const SizedBox(height: 24),
                    _buildStats(),
                    const SizedBox(height: 24),
                    _buildQuickAccess(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hello,',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              Text(
                _currentUser?.fullName ?? 'Intern',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withAlpha(77)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined,
                  color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                _internProfile == null
                    ? 'Intern'
                    : AppUtils.getStatusLabel(_internProfile!.status),
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdCardTeaser() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/intern/id-card', (route) => false),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.idCardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withAlpha(77)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withAlpha(40),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.badge_outlined,
                  size: 32, color: AppColors.accent),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My ID Card',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Show it at the entrance',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: AppColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final cols = MediaQuery.of(context).size.width >= 900 ? 4 : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [
        StatsCard(
          title: 'Évaluations',
          value: '${_evaluations.length}',
          icon: Icons.star_outline,
          color: AppColors.gold,
          subtitle: _evaluations.isEmpty
              ? null
              : 'Average ${_avgScore.toStringAsFixed(1)}/20',
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/intern/evaluations', (route) => false),
        ),
        StatsCard(
          title: 'Attendance',
          value: '$_presenceRate%',
          icon: Icons.check_circle_outline,
          color: _presenceRate >= 80
              ? AppColors.success
              : AppColors.warning,
        ),
        StatsCard(
          title: 'Department',
          value: _internProfile?.department.split(' ').first ?? '—',
          icon: Icons.business_center_outlined,
          color: AppColors.accent,
        ),
        StatsCard(
          title: 'Training',
          value: '→',
          icon: Icons.library_books_outlined,
          color: AppColors.warning,
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/intern/training', (route) => false),
        ),
      ],
    );
  }

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _quickTile(
          Icons.schedule_outlined,
          'Schedule',
          'View schedules',
          () => Navigator.of(context).pushNamedAndRemoveUntil('/intern/schedule', (route) => false),
        ),
        _quickTile(
          Icons.library_books_outlined,
          'Course materials',
          'Access files',
          () => Navigator.of(context).pushNamedAndRemoveUntil('/intern/training', (route) => false),
        ),
        _quickTile(
          Icons.assessment_outlined,
          'My evaluations',
          'View my grades and comments',
          () => Navigator.of(context).pushNamedAndRemoveUntil('/intern/evaluations', (route) => false),
        ),
      ],
    );
  }

  Widget _quickTile(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.textSecondary, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
