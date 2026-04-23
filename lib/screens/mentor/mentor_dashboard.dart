import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/intern_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/cards/stats_card.dart';
import '../../widgets/cards/intern_card.dart';

/// Entry point for mentor users. Shows a quick summary of assigned interns
/// and shortcuts to the main mentor workflows (evaluate, attendance, upload).
class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  UserModel? _currentUser;
  List<InternModel> _assignedInterns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final fs = context.read<FirestoreService>();
      final user = await authService.getCurrentUser();
      final interns = user == null
          ? <InternModel>[]
          : await fs.getInternsByMentor(user.id);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _assignedInterns = interns;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pro-Link Encadreur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: _currentUser != null ? AppDrawer(user: _currentUser!) : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStats(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildInterns(),
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
              const Text('Bienvenue,',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              Text(
                _currentUser?.fullName ?? 'Encadreur',
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
            color: AppColors.accent.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withAlpha(77)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.supervisor_account,
                  color: AppColors.accent, size: 16),
              SizedBox(width: 6),
              Text('Encadreur',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final active =
        _assignedInterns.where((i) => i.status == 'active').length;
    final departments =
        _assignedInterns.map((i) => i.department).toSet().length;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.3,
      children: [
        StatsCard(
          title: 'Mes Stagiaires',
          value: '${_assignedInterns.length}',
          icon: Icons.groups_outlined,
          color: AppColors.accent,
          onTap: () => context.go('/mentor/interns'),
        ),
        StatsCard(
          title: 'Actifs',
          value: '$active',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        ),
        StatsCard(
          title: 'Départements',
          value: '$departments',
          icon: Icons.business_center_outlined,
          color: AppColors.gold,
        ),
        StatsCard(
          title: 'Cette semaine',
          value: '7j',
          icon: Icons.calendar_today_outlined,
          color: AppColors.warning,
          onTap: () => context.go('/mentor/attendance'),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _actionChip(Icons.star_outline, 'Évaluer',
                () => context.go('/mentor/evaluate')),
            _actionChip(Icons.fact_check_outlined, 'Présences',
                () => context.go('/mentor/attendance')),
            _actionChip(Icons.upload_file_outlined, 'Support',
                () => context.go('/mentor/training')),
          ],
        ),
      ],
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.accent),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.cardBorder),
    );
  }

  Widget _buildInterns() {
    if (_assignedInterns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: const Column(
          children: [
            Icon(Icons.people_outline,
                size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('Aucun stagiaire affecté pour le moment',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mes stagiaires',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/mentor/interns'),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._assignedInterns.take(4).map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InternCard(intern: i),
              ),
            ),
      ],
    );
  }
}
