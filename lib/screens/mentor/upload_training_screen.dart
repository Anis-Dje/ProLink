import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/training_file_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
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
      message: 'Uploading...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Training Materials'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomSearchBar(
                hintText: 'Search materials...',
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
          label: const Text('New'),
        ),
      ),
    );
  }

  /// Entry-point for the FloatingActionButton: lets the mentor choose
  /// between uploading a local file (with thumbnail preview) or attaching
  /// an external URL (e.g. a Google Drive / YouTube link). The two flows
  /// share `_promptInfo()` for title/description/tags and end with the
  /// same `createTrainingFile` call.
  Future<void> _upload() async {
    final source = await showModalBottomSheet<_UploadSource>(
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add a training material',
                    style: TextStyle(
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
                  'Pick a PDF, document, image or video from your device',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, _UploadSource.file),
            ),
            ListTile(
              leading:
                  const Icon(Icons.link, color: AppColors.accent),
              title: const Text('Attach a URL',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text(
                  'Paste a public link (drive, YouTube, blog post...)',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, _UploadSource.url),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (source == _UploadSource.url) {
      await _uploadFromUrl();
    } else {
      await _uploadFromFile();
    }
  }

  Future<void> _uploadFromFile() async {
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
      // Required on web (and helpful elsewhere) so the picker returns
      // raw bytes for the preview thumbnail.
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null) return;

    // Show a thumbnail preview before asking for metadata; the user
    // can confirm or cancel based on the actual file they picked.
    final confirmed = await _showFilePreview(picked);
    if (confirmed != true) return;

    final info = await _promptInfo();
    if (info == null) return;

    final xfile = _xFileFromPicked(picked);
    if (xfile == null) return;

    setState(() => _uploading = true);
    try {
      final mentorId =
          context.read<AuthService>().currentUser?.id ?? 'unknown';
      final url = await context
          .read<StorageService>()
          .uploadTrainingFile(mentorId, xfile, info.title);

      final training = TrainingFileModel(
        id: '',
        title: info.title,
        description: info.description,
        fileUrl: url,
        fileType: p.extension(picked.name).replaceFirst('.', ''),
        uploadedBy: mentorId,
        uploadDate: DateTime.now(),
        tags: info.tags,
      );
      await context.read<FirestoreService>().createTrainingFile(training);
      await NotificationService.instance
          .notifyTrainingAdded(title: info.title);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Material uploaded');
      }
      _load();
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// URL-only flow. The file URL is whatever the mentor pastes; the
  /// extension drives the icon used in the list. Title/description/tags
  /// come from the same `_promptInfo` dialog as the file flow.
  Future<void> _uploadFromUrl() async {
    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Document URL'),
        content: TextField(
          controller: urlCtrl,
          autofocus: true,
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
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      AppUtils.showSnackBar(context, 'URL must start with http(s)://',
          isError: true);
      return;
    }
    final info = await _promptInfo();
    if (info == null) return;
    setState(() => _uploading = true);
    try {
      final mentorId =
          context.read<AuthService>().currentUser?.id ?? 'unknown';
      // Strip query/fragment first — `p.extension` treats input as a fs path
      // and would otherwise return e.g. `.pdf?token=abc` from a presigned URL.
      final ext = p
          .extension(Uri.parse(url).path)
          .replaceFirst('.', '')
          .toLowerCase();
      final training = TrainingFileModel(
        id: '',
        title: info.title,
        description: info.description,
        fileUrl: url,
        fileType: ext.isEmpty ? 'link' : ext,
        uploadedBy: mentorId,
        uploadDate: DateTime.now(),
        tags: info.tags,
      );
      await context.read<FirestoreService>().createTrainingFile(training);
      await NotificationService.instance
          .notifyTrainingAdded(title: info.title);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Material added');
      }
      _load();
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(TrainingFileModel f) async {
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
      _load();
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error', isError: true);
      }
    }
  }

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

  Future<bool?> _showFilePreview(PlatformFile picked) {
    final ext = p.extension(picked.name).replaceFirst('.', '').toLowerCase();
    final isImage = const {'png', 'jpg', 'jpeg', 'gif', 'webp'}.contains(ext);
    final Uint8List? bytes = picked.bytes;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Preview'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isImage && bytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes,
                      height: 180, fit: BoxFit.cover, width: double.infinity),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Center(
                    child: Icon(
                      AppUtils.getFileTypeIcon(ext),
                      color: AppColors.accent,
                      size: 56,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                picked.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(picked.size / 1024).toStringAsFixed(1)} KB · .$ext',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<_FileInfo?> _promptInfo() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    return showDialog<_FileInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New material'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Title'),
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
                  labelText: 'Keywords (comma-separated)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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
            child: const Text('Upload'),
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

/// Distinguishes the two ways a mentor can attach a training material.
enum _UploadSource { file, url }

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
          Text('No training material uploaded',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
