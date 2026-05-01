import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../models/intern_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/cards/stats_card.dart';
import '../../widgets/cards/intern_card.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  UserModel? _currentUser;
  List<InternModel> _pendingInterns = [];
  int _totalInterns = 0;
  int _activeInterns = 0;
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
      final firestoreService = context.read<FirestoreService>();
      final user = await authService.getCurrentUser();
      final pending = await firestoreService.getPendingInterns();
      final allInterns = await firestoreService.getAllInterns();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _pendingInterns = pending.take(5).toList();
          _totalInterns = allInterns.length;
          _activeInterns = allInterns.where((i) => i.status == 'active').length;
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
        title: const Text('Pro-Link Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: _currentUser != null
          ? AppDrawer(user: _currentUser!)
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
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
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildPendingSection(),
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
              Text(
                'Hello,',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                _currentUser?.fullName ?? 'Administrator',
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
            color: AppColors.gold.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withAlpha(77)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 16),
              SizedBox(width: 6),
              Text(
                'Administrator',
                style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    // Responsive: phones get 2 columns, tablets/web get 4 so the
    // dashboard stays readable across screen sizes.
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 900 ? 4 : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [
        StatsCard(
          title: 'Total Interns',
          value: '$_totalInterns',
          icon: Icons.people_outline,
          color: AppColors.accent,
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/interns', (route) => false),
        ),
        StatsCard(
          title: 'Active Interns',
          value: '$_activeInterns',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/interns', (route) => false),
        ),
        StatsCard(
          title: 'Pending',
          value: '${_pendingInterns.length}',
          icon: Icons.hourglass_empty_outlined,
          color: AppColors.warning,
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/interns', (route) => false),
        ),
        StatsCard(
          title: 'Documents',
          value: 'Docs',
          icon: Icons.folder_outlined,
          color: AppColors.secondary,
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/documents', (route) => false),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 6 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: [
            _QuickActionCard(
              icon: Icons.people_outline,
              label: 'Interns',
              onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/interns', (route) => false),
            ),
            _QuickActionCard(
              icon: Icons.assignment_ind_outlined,
              label: 'Assignments',
              onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/assign', (route) => false),
            ),
            _QuickActionCard(
              icon: Icons.schedule_outlined,
              label: 'Schedule',
              onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/documents', (route) => false),
            ),
            _QuickActionCard(
              icon: Icons.folder_outlined,
              label: 'Documents',
              onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/documents', (route) => false),
            ),
            _QuickActionCard(
              icon: Icons.manage_accounts_outlined,
              label: 'Users',
              onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/users', (route) => false),
            ),
            _QuickActionCard(
              icon: Icons.analytics_outlined,
              label: 'Analytics',
              onTap: () => Navigator.of(context).pushNamed('/analytics'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_pendingInterns.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/interns', (route) => false),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pendingInterns.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'No pending requests',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_pendingInterns.map(
            (intern) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InternCard(
                intern: intern,
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/interns', (route) => false),
                actions: [
                  _ActionButton(
                    icon: Icons.check,
                    color: AppColors.success,
                    onTap: () => _approveIntern(intern),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.close,
                    color: AppColors.error,
                    onTap: () => _rejectIntern(intern),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Future<void> _approveIntern(InternModel intern) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Approve intern',
      content: 'Approve ${intern.fullName}?',
      confirmText: 'Approve',
    );
    if (confirm == true && mounted) {
      await context.read<FirestoreService>().approveIntern(intern.id);
      _loadData();
    }
  }

  Future<void> _rejectIntern(InternModel intern) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Reject request',
      content: "Reject ${intern.fullName}'s request?",
      confirmText: 'Reject',
    );
    if (confirm == true && mounted) {
      await context.read<FirestoreService>().rejectIntern(intern.id);
      _loadData();
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accent, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
