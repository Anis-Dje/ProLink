import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/intern_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/custom_search_bar.dart';
import '../../widgets/cards/intern_card.dart';

class ManageInternsScreen extends StatefulWidget {
  const ManageInternsScreen({super.key});

  @override
  State<ManageInternsScreen> createState() => _ManageInternsScreenState();
}

class _ManageInternsScreenState extends State<ManageInternsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<InternModel> _allInterns = [];
  List<InternModel> _filteredInterns = [];
  String _searchQuery = '';
  bool _loading = true;

  final List<String> _tabs = ['All', 'Active', 'Pending', 'Rejected', 'Completed'];
  final List<String?> _statusFilters = [
    null,
    AppConstants.statusActive,
    AppConstants.statusPending,
    AppConstants.statusRejected,
    AppConstants.statusCompleted,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadInterns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) _applyFilters();
  }

  Future<void> _loadInterns() async {
    setState(() => _loading = true);
    try {
      final interns = await context.read<FirestoreService>().getAllInterns();
      if (mounted) {
        setState(() {
          _allInterns = interns;
          _loading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final statusFilter = _statusFilters[_tabController.index];
    setState(() {
      _filteredInterns = _allInterns.where((intern) {
        final matchesStatus = statusFilter == null || intern.status == statusFilter;
        final matchesSearch = _searchQuery.isEmpty ||
            intern.fullName.toLowerCase().contains(_searchQuery) ||
            intern.studentId.toLowerCase().contains(_searchQuery) ||
            intern.email.toLowerCase().contains(_searchQuery) ||
            intern.department.toLowerCase().contains(_searchQuery);
        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Interns'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/admin/dashboard', (route) => false),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: CustomSearchBar(
              hintText: 'Search interns...',
              onChanged: (q) {
                _searchQuery = q.toLowerCase();
                _applyFilters();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_filteredInterns.length} intern(s)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : RefreshIndicator(
                    onRefresh: _loadInterns,
                    color: AppColors.accent,
                    child: _filteredInterns.isEmpty
                        ? _EmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filteredInterns.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InternCard(
                                intern: _filteredInterns[i],
                                onTap: () => _showInternDetails(_filteredInterns[i]),
                                actions: _buildActions(_filteredInterns[i]),
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(InternModel intern) {
    if (intern.status == AppConstants.statusPending) {
      return [
        _iconBtn(Icons.check, AppColors.success, () => _approveIntern(intern)),
        const SizedBox(width: 6),
        _iconBtn(Icons.close, AppColors.error, () => _rejectIntern(intern)),
      ];
    }
    return [
      _iconBtn(Icons.info_outline, AppColors.accent, () => _showInternDetails(intern)),
    ];
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
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

  Future<void> _approveIntern(InternModel intern) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Approve',
      content: 'Approve ${intern.fullName}?',
      confirmText: 'Approve',
    );
    if (confirm == true && mounted) {
      await context.read<FirestoreService>().approveIntern(
            intern.id,
            startDate: DateTime.now(),
          );
      AppUtils.showSnackBar(context, 'Intern approved');
      _loadInterns();
    }
  }

  Future<void> _rejectIntern(InternModel intern) async {
    String reason = '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection reason'),
        content: TextField(
          onChanged: (v) => reason = v,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<FirestoreService>().rejectIntern(intern.id, reason: reason);
      AppUtils.showSnackBar(context, 'Request rejected');
      _loadInterns();
    }
  }

  void _showInternDetails(InternModel intern) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InternDetailsSheet(intern: intern),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('No interns found', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _InternDetailsSheet extends StatelessWidget {
  final InternModel intern;
  const _InternDetailsSheet({required this.intern});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(intern.fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(intern.email, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _InfoRow(label: 'Student #', value: intern.studentId),
          _InfoRow(label: 'Department', value: intern.department),
          _InfoRow(label: 'Specialization', value: intern.specialization),
          _InfoRow(label: 'University', value: intern.university),
          _InfoRow(label: 'Phone', value: intern.phone),
          _InfoRow(
            label: 'Status',
            value: AppUtils.getStatusLabel(intern.status),
            valueColor: AppUtils.getStatusColor(intern.status),
          ),
          _InfoRow(
            label: 'Registration date',
            value: AppUtils.formatDate(intern.registrationDate),
          ),
          if (intern.startDate != null)
            _InfoRow(label: 'Internship start', value: AppUtils.formatDate(intern.startDate!)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
