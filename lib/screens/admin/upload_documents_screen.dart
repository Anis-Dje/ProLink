import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/schedule_model.dart';
import '../../models/training_file_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/loading_overlay.dart';

/// Admin screen to upload office schedules and policy handbooks.
class UploadDocumentsScreen extends StatefulWidget {
  const UploadDocumentsScreen({super.key});

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ScheduleModel> _schedules = [];
  List<TrainingFileModel> _policies = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final fs = context.read<FirestoreService>();
      final schedules = await fs.getSchedules();
      // Policies use the training files collection but are tagged 'policy'.
      final training = await fs.getTrainingFiles();
      final policies =
          training.where((t) => t.tags.contains('policy')).toList();
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _policies = policies;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _uploading,
      message: 'Téléversement en cours...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Documents & Plannings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.go('/admin/dashboard'),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(text: 'Plannings', icon: Icon(Icons.schedule)),
              Tab(text: 'Règlements', icon: Icon(Icons.gavel_outlined)),
            ],
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildScheduleList(),
                  _buildPolicyList(),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              _tabController.index == 0 ? _uploadSchedule() : _uploadPolicy(),
          icon: const Icon(Icons.upload_file),
          label: const Text('Téléverser'),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_schedules.isEmpty) {
      return _EmptyList(
        icon: Icons.schedule_outlined,
        label: 'Aucun planning disponible',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _schedules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = _schedules[i];
          return _DocumentTile(
            title: s.title,
            subtitle: '${s.weekLabel} · ${AppUtils.formatDate(s.uploadDate)}',
            icon: Icons.calendar_today,
            color: AppColors.accent,
            onDelete: () => _deleteSchedule(s),
          );
        },
      ),
    );
  }

  Widget _buildPolicyList() {
    if (_policies.isEmpty) {
      return _EmptyList(
        icon: Icons.description_outlined,
        label: 'Aucun règlement disponible',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _policies.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final f = _policies[i];
          return _DocumentTile(
            title: f.title,
            subtitle: '${f.description} · ${AppUtils.formatDate(f.uploadDate)}',
            icon: AppUtils.getFileTypeIcon(f.fileType),
            color: AppColors.gold,
            onDelete: () => _deletePolicy(f),
          );
        },
      ),
    );
  }

  Future<void> _uploadSchedule() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg'],
    );
    if (result == null || result.files.single.path == null) return;

    final title = await _promptText('Titre du planning');
    if (title == null || title.isEmpty) return;
    final weekLabel =
        await _promptText('Semaine (ex: Semaine 12 – Mars 2026)');
    if (weekLabel == null || weekLabel.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final adminId =
          context.read<AuthService>().currentFirebaseUser?.uid ?? 'unknown';
      final file = File(result.files.single.path!);
      final url = await context
          .read<StorageService>()
          .uploadSchedule(adminId, file, weekLabel);

      final schedule = ScheduleModel(
        id: '',
        title: title,
        description: '',
        fileUrl: url,
        uploadedBy: adminId,
        uploadDate: DateTime.now(),
        weekLabel: weekLabel,
      );
      await context.read<FirestoreService>().createSchedule(schedule);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Planning téléversé');
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadPolicy() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null) return;

    final title = await _promptText('Titre du règlement');
    if (title == null || title.isEmpty) return;
    final description = await _promptText('Description courte') ?? '';

    setState(() => _uploading = true);
    try {
      final adminId =
          context.read<AuthService>().currentFirebaseUser?.uid ?? 'unknown';
      final file = File(result.files.single.path!);
      final url = await context
          .read<StorageService>()
          .uploadPolicyDocument(adminId, file, title);

      final training = TrainingFileModel(
        id: '',
        title: title,
        description: description,
        fileUrl: url,
        fileType: p.extension(file.path).replaceFirst('.', ''),
        uploadedBy: adminId,
        uploadDate: DateTime.now(),
        tags: const ['policy'],
      );
      await context.read<FirestoreService>().createTrainingFile(training);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Règlement téléversé');
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteSchedule(ScheduleModel s) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Supprimer',
      content: 'Supprimer "${s.title}" ?',
    );
    if (confirm != true) return;
    try {
      await context.read<StorageService>().deleteFile(s.fileUrl);
      await context.read<FirestoreService>().deleteSchedule(s.id);
      if (mounted) AppUtils.showSnackBar(context, 'Supprimé');
      _loadData();
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur de suppression', isError: true);
      }
    }
  }

  Future<void> _deletePolicy(TrainingFileModel f) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Supprimer',
      content: 'Supprimer "${f.title}" ?',
    );
    if (confirm != true) return;
    try {
      await context.read<StorageService>().deleteFile(f.fileUrl);
      await context.read<FirestoreService>().deleteTrainingFile(f.id);
      if (mounted) AppUtils.showSnackBar(context, 'Supprimé');
      _loadData();
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur de suppression', isError: true);
      }
    }
  }

  Future<String?> _promptText(String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyList({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
