import 'package:flutter/material.dart';

import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/schedule_model.dart';
import '../../models/training_file_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
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
      message: 'Uploading...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Documents & Schedules'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(text: 'Schedules', icon: Icon(Icons.schedule)),
              Tab(text: 'Policies', icon: Icon(Icons.gavel_outlined)),
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
          label: const Text('Upload'),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_schedules.isEmpty) {
      return _EmptyList(
        icon: Icons.schedule_outlined,
        label: 'No schedule available',
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
        label: 'No policy available',
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

  /// Bottom sheet that lets the admin pick between uploading a local
  /// file or pasting an external URL — useful when a file exceeds the
  /// upload limit or already lives on Drive / Dropbox / SharePoint.
  Future<_UploadSource?> _chooseSource(String what) {
    return showModalBottomSheet<_UploadSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add a $what',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    )),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined,
                  color: AppColors.accent),
              title: const Text('Upload from device',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text(
                  'Pick a PDF, document or image from your device',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, _UploadSource.file),
            ),
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.accent),
              title: const Text('Attach a URL',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text(
                  'Paste a public link (Drive, Dropbox, SharePoint…)',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, _UploadSource.url),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptUrl(String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadSchedule() async {
    final source = await _chooseSource('schedule');
    if (source == null) return;

    final title = await _promptText('Schedule title');
    if (title == null || title.isEmpty) return;
    final weekLabel =
        await _promptText('Week (e.g. Week 12 – March 2026)');
    if (weekLabel == null || weekLabel.isEmpty) return;

    String url;
    if (source == _UploadSource.url) {
      final pasted = await _promptUrl('Schedule file URL');
      if (pasted == null || pasted.isEmpty) return;
      url = pasted;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      final picked = result?.files.single;
      if (picked == null) return;
      final xfile = _xFileFromPicked(picked);
      if (xfile == null) return;
      setState(() => _uploading = true);
      try {
        final adminId =
            context.read<AuthService>().currentUser?.id ?? 'unknown';
        url = await context
            .read<StorageService>()
            .uploadSchedule(adminId, xfile, weekLabel);
      } catch (e) {
        if (mounted) {
          AppUtils.showSnackBar(context, 'Upload error: $e', isError: true);
        }
        if (mounted) setState(() => _uploading = false);
        return;
      }
    }

    setState(() => _uploading = true);
    try {
      final adminId =
          context.read<AuthService>().currentUser?.id ?? 'unknown';
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
      // Local notification is a UX polish; the server also fans out a
      // push-style notification to every mentor + intern via the
      // notifications table.
      await NotificationService.instance.notifyScheduleChanged(
        weekLabel: weekLabel,
      );
      if (mounted) {
        AppUtils.showSnackBar(context, 'Schedule published');
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadPolicy() async {
    final source = await _chooseSource('policy');
    if (source == null) return;

    final title = await _promptText('Policy title');
    if (title == null || title.isEmpty) return;
    final description = await _promptText('Short description') ?? '';

    String url;
    String fileType;
    if (source == _UploadSource.url) {
      final pasted = await _promptUrl('Policy document URL');
      if (pasted == null || pasted.isEmpty) return;
      url = pasted;
      // Best-effort guess at the extension from the URL itself; falls
      // back to "link" so the list shows a generic link icon.
      final guessed = p.extension(Uri.tryParse(pasted)?.path ?? '')
          .replaceFirst('.', '');
      fileType = guessed.isNotEmpty ? guessed : 'link';
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      final picked = result?.files.single;
      if (picked == null) return;
      final xfile = _xFileFromPicked(picked);
      if (xfile == null) return;
      setState(() => _uploading = true);
      try {
        final adminId =
            context.read<AuthService>().currentUser?.id ?? 'unknown';
        url = await context
            .read<StorageService>()
            .uploadPolicyDocument(adminId, xfile, title);
        fileType = p.extension(picked.name).replaceFirst('.', '');
      } catch (e) {
        if (mounted) {
          AppUtils.showSnackBar(context, 'Upload error: $e', isError: true);
        }
        if (mounted) setState(() => _uploading = false);
        return;
      }
    }

    setState(() => _uploading = true);
    try {
      final adminId =
          context.read<AuthService>().currentUser?.id ?? 'unknown';
      final training = TrainingFileModel(
        id: '',
        title: title,
        description: description,
        fileUrl: url,
        fileType: fileType,
        uploadedBy: adminId,
        uploadDate: DateTime.now(),
        tags: const ['policy'],
      );
      await context.read<FirestoreService>().createTrainingFile(training);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Policy published');
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteSchedule(ScheduleModel s) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Delete',
      content: 'Delete "${s.title}" ?',
    );
    if (confirm != true) return;
    try {
      await context.read<StorageService>().deleteFile(s.fileUrl);
      await context.read<FirestoreService>().deleteSchedule(s.id);
      if (mounted) AppUtils.showSnackBar(context, 'Deleted');
      _loadData();
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Delete error', isError: true);
      }
    }
  }

  Future<void> _deletePolicy(TrainingFileModel f) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Delete',
      content: 'Delete "${f.title}" ?',
    );
    if (confirm != true) return;
    try {
      await context.read<StorageService>().deleteFile(f.fileUrl);
      await context.read<FirestoreService>().deleteTrainingFile(f.id);
      if (mounted) AppUtils.showSnackBar(context, 'Deleted');
      _loadData();
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Delete error', isError: true);
      }
    }
  }

  /// Builds an `XFile` from the `file_picker` result. Uses bytes when
  /// running on Flutter web (where `path` is empty) and the file path
  /// otherwise, so the same upload code works on every platform.
  XFile? _xFileFromPicked(PlatformFile picked) {
    if (picked.bytes != null) {
      return XFile.fromData(
        picked.bytes!,
        name: picked.name,
        length: picked.size,
      );
    }
    if (picked.path != null) {
      return XFile(picked.path!, name: picked.name);
    }
    return null;
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Submit'),
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

enum _UploadSource { file, url }

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
