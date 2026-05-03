import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../services/api_client.dart';

/// In-app preview screen for uploaded PDFs and images.
///
/// Downloads the bytes through [ApiClient.downloadBytes] (so the
/// `ngrok-skip-browser-warning` header is sent and free-tunnel users
/// don't get bounced to an interstitial), caches them under the app's
/// temp directory, then either renders the PDF inline with
/// `flutter_pdfview` or shows the image inside a pinch-zoom
/// `PhotoView`.
///
/// A "Download" button on the AppBar opens the system share sheet so
/// the user can save / send the file anywhere they like (Drive, email,
/// other apps, save to device storage, etc.).
class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  /// Returns true when [url]'s extension is one we can render inline.
  static bool canPreview(String url) =>
      _kindFor(url) != _ViewerKind.unsupported;

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

enum _ViewerKind { pdf, image, unsupported }

_ViewerKind _kindFor(String url) {
  final lower = url.toLowerCase();
  // Strip query / fragment so `.pdf?foo=bar` still matches.
  final clean =
      lower.split('?').first.split('#').first;
  if (clean.endsWith('.pdf')) return _ViewerKind.pdf;
  for (final ext in const [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  ]) {
    if (clean.endsWith(ext)) return _ViewerKind.image;
  }
  return _ViewerKind.unsupported;
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late final _ViewerKind _kind = _kindFor(widget.url);

  bool _loading = true;
  Object? _error;
  Uint8List? _bytes;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final raw = await api.downloadBytes(widget.url);
      final bytes = Uint8List.fromList(raw);
      // Persist under the app's cache so flutter_pdfview can mmap the
      // file (its API takes a path, not bytes).
      final dir = await getTemporaryDirectory();
      final filename = _safeFilename();
      final path = p.join(dir.path, filename);
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _localPath = path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _safeFilename() {
    final tail = Uri.parse(widget.url).pathSegments.isEmpty
        ? widget.title
        : Uri.parse(widget.url).pathSegments.last;
    final cleaned = tail.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  Future<void> _share() async {
    if (_localPath == null) {
      AppUtils.showSnackBar(context,
          'File is not ready yet — please wait for the preview to load.',
          isError: true);
      return;
    }
    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(_localPath!)],
        subject: widget.title,
      );
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Could not share file: $e',
          isError: true);
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Could not open externally: $e',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download / share',
            onPressed: (_loading || _error != null) ? null : _share,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_kind == _ViewerKind.unsupported) {
      return _UnsupportedView(
        title: widget.title,
        onOpenExternal: _openExternally,
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(
        error: _error!,
        onRetry: _download,
        onOpenExternal: _openExternally,
      );
    }
    switch (_kind) {
      case _ViewerKind.pdf:
        return PDFView(
          filePath: _localPath!,
          autoSpacing: true,
          enableSwipe: true,
          swipeHorizontal: false,
          pageSnap: true,
          fitPolicy: FitPolicy.BOTH,
        );
      case _ViewerKind.image:
        return PhotoView(
          imageProvider: MemoryImage(_bytes!),
          backgroundDecoration:
              const BoxDecoration(color: AppColors.background),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        );
      case _ViewerKind.unsupported:
        return const SizedBox.shrink();
    }
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.title, required this.onOpenExternal});

  final String title;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 72, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This file format isn\u2019t previewed in the app. '
              'Open it in another app to view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open externally'),
              onPressed: onOpenExternal,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onOpenExternal,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 72, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Could not load this file.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: onRetry,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open externally'),
                  onPressed: onOpenExternal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
