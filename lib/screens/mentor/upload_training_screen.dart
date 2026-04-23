import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/training_file_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/custom_search_bar.dart';
import '../../widgets/common/loading_overlay.dart';

/// Lets mentors upload training modules/resources and manage their list.
class UploadTrainingScreen extends StatefulWidget {
  const UploadTrainingScreen({super.key});

  @override
  State<UploadTrainingScreen> createState() => _UploadTrainingScreenState();
}

class _UploadTrainingScreenState extends State<UploadTrainingScreen> {
  List<TrainingFileModel> _files = [];
  String _query = '';
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fs = context.read<FirestoreService>();
      final files = await fs.getTrainingFiles();
      if (mounted) {
        setState(() {
          _files = files.where((f) => !f.tags.contains('policy')).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TrainingFileModel> get _filtered {
    if (_query.isEmpty) return _files;
    final q = _query.toLowerCase();
    return _files
        .where((f) =>
            f.title.toLowerCase().contains(q) ||
            f.description.toLowerCase().contains(q) ||
            f.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _uploading,
      message: 'Téléversement...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Supports de Formation'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.go('/mentor/dashboard'),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomSearchBar(
                hintText: 'Rechercher un support...',
                onChanged: (q) => setState(() => _query = q),
                suggestions: _files.map((f) => f.title).toList(),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.accent,
                      child: _filtered.isEmpty
                          ? const _Empty()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) =>
                                  _FileTile(
                                    file: _filtered[i],
                                    onDelete: () => _delete(_filtered[i]),
                                  ),
                            ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _upload,
          icon: const Icon(Icons.upload_file),
          label: const Text('Nouveau'),
        ),
      ),
    );
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'mp4',
        'png',
        'jpg',
      ],
    );
    if (result == null || result.files.single.path == null) return;

    final info = await _promptInfo();
    if (info == null) return;

    setState(() => _uploading = true);
    try {
      final mentorId =
          context.read<AuthService>().currentFirebaseUser?.uid ?? 'unknown';
      final file = File(result.files.single.path!);
      final url = await context
          .read<StorageService>()
          .uploadTrainingFile(mentorId, file, info.title);

      final training = TrainingFileModel(
        id: '',
        title: info.title,
        description: info.description,
        fileUrl: url,
        fileType: p.extension(file.path).replaceFirst('.', ''),
        uploadedBy: mentorId,
        uploadDate: DateTime.now(),
        tags: info.tags,
      );
      await context.read<FirestoreService>().createTrainingFile(training);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Support téléversé');
      }
      _load();
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(TrainingFileModel f) async {
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
      _load();
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur', isError: true);
      }
    }
  }

  Future<_FileInfo?> _promptInfo() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    return showDialog<_FileInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau support'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagsCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Mots-clés (séparés par ,)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                _FileInfo(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  tags: tagsCtrl.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList(),
                ),
              );
            },
            child: const Text('Téléverser'),
          ),
        ],
      ),
    );
  }
}

class _FileInfo {
  final String title;
  final String description;
  final List<String> tags;
  _FileInfo(
      {required this.title, required this.description, required this.tags});
}

class _FileTile extends StatelessWidget {
  final TrainingFileModel file;
  final VoidCallback onDelete;
  const _FileTile({required this.file, required this.onDelete});

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
              color: AppColors.accent.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(AppUtils.getFileTypeIcon(file.fileType),
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                if (file.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(file.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: file.tags
                      .take(3)
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(t,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.accent)),
                        ),
                      )
                      .toList(),
                ),
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Aucun support téléversé',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
