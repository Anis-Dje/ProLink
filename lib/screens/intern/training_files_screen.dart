import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/file_launcher.dart';
import '../../models/training_file_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/custom_search_bar.dart';

/// Shows the training catalog (modules + policy documents) available
/// to the intern with predictive search.
class TrainingFilesScreen extends StatefulWidget {
  const TrainingFilesScreen({super.key});

  @override
  State<TrainingFilesScreen> createState() => _TrainingFilesScreenState();
}

class _TrainingFilesScreenState extends State<TrainingFilesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TrainingFileModel> _all = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await context.read<FirestoreService>().getTrainingFiles();
      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TrainingFileModel> get _filtered {
    final isPolicy = _tabController.index == 1;
    Iterable<TrainingFileModel> list = _all.where((f) =>
        isPolicy ? f.tags.contains('policy') : !f.tags.contains('policy'));
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((f) =>
          f.title.toLowerCase().contains(q) ||
          f.description.toLowerCase().contains(q) ||
          f.tags.any((t) => t.toLowerCase().contains(q)));
    }
    return list.toList();
  }

  List<String> get _suggestions => _all
      .expand((f) => [f.title, ...f.tags])
      .toSet()
      .toList();

  void _open(TrainingFileModel f) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(f.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (f.description.isNotEmpty) ...[
              Text(f.description,
                  style: const TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
            ],
            const Text('File link:',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            SelectableText(
              f.fileUrl,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open / Download'),
            onPressed: () {
              Navigator.of(ctx).pop();
              FileLauncher.open(context, f.fileUrl);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Course materials'),
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
            Tab(text: 'Training', icon: Icon(Icons.school_outlined)),
            Tab(text: 'Policies', icon: Icon(Icons.gavel_outlined)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              hintText: 'Search documents...',
              onChanged: (q) => setState(() => _query = q),
              suggestions: _suggestions,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
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
                            itemBuilder: (_, i) => _Tile(
                              file: _filtered[i],
                              onOpen: () => _open(_filtered[i]),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final TrainingFileModel file;
  final VoidCallback onOpen;
  const _Tile({required this.file, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
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
              child: Icon(
                AppUtils.getFileTypeIcon(file.fileType),
                color: AppColors.accent,
                size: 22,
              ),
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
                    Text(
                      file.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    AppUtils.formatDate(file.uploadDate),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.library_books_outlined,
                  size: 56, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text('No documents',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
