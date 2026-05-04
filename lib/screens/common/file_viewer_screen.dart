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

  /// Heuristic, URL-only check used by callers that want to decide
  /// whether to push the in-app viewer at all (vs. an external
  /// launcher) before any bytes have been downloaded. The viewer
  /// itself does a far more accurate magic-byte sniff post-download,
  /// so any URL is safe to push — for files we can't preview, the
  /// viewer renders an "open externally" fallback.
  static bool canPreview(String url) =>
      _kindFromUrl(url) != _ViewerKind.unsupported;

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

enum _ViewerKind { pdf, image, unsupported }

_ViewerKind _kindFromUrl(String url) {
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

/// Magic-byte sniffer. Mirrors `pro_link_sniff_extension` on the
/// server. Used to recover from old uploads that were saved as
/// `.bin` (back when filename derivation on the client could lose
/// the extension): even if the URL is `<uuid>.bin`, if the bytes
/// start with `%PDF-` we render it as a PDF.
_ViewerKind _kindFromBytes(Uint8List b) {
  if (b.length >= 5 &&
      b[0] == 0x25 && b[1] == 0x50 &&
      b[2] == 0x44 && b[3] == 0x46 && b[4] == 0x2D) {
    return _ViewerKind.pdf;
  }
  if (b.length >= 8 &&
      b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return _ViewerKind.image;
  }
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return _ViewerKind.image;
  }
  if (b.length >= 6 &&
      b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 &&
      b[3] == 0x38 && (b[4] == 0x37 || b[4] == 0x39) && b[5] == 0x61) {
    return _ViewerKind.image;
  }
  if (b.length >= 12 &&
      b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
    return _ViewerKind.image;
  }
  if (b.length >= 2 && b[0] == 0x42 && b[1] == 0x4D) {
    return _ViewerKind.image;
  }
  return _ViewerKind.unsupported;
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  // Initial guess from the URL, refined to the magic-byte answer once
  // the bytes have downloaded. The URL guess is used only to pick the
  // right loading skeleton; the post-download value is what actually
  // drives the renderer.
  _ViewerKind _kind = _ViewerKind.unsupported;

  bool _loading = true;
  Object? _error;
  Uint8List? _bytes;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _kind = _kindFromUrl(widget.url);
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
      // Pick the actual viewer from the bytes — the URL extension
      // can be wrong (e.g. legacy `.bin` uploads from when the
      // client filename derivation didn't sniff types).
      final detected = _kindFromBytes(bytes);
      final kind = detected != _ViewerKind.unsupported ? detected : _kind;
      // Persist under the app's cache so flutter_pdfview can mmap the
      // file (its API takes a path, not bytes).
      final dir = await getTemporaryDirectory();
      final filename = _safeFilename(kind);
      final path = p.join(dir.path, filename);
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _localPath = path;
        _kind = kind;
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

  String _safeFilename(_ViewerKind kind) {
    final tail = Uri.parse(widget.url).pathSegments.isEmpty
        ? widget.title
        : Uri.parse(widget.url).pathSegments.last;
    var cleaned = tail.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (cleaned.isEmpty) cleaned = 'file';
    // If the URL ends in `.bin` but the bytes are actually a PDF /
    // image, swap the extension so the system share sheet (and any
    // app receiving the file) gets the right MIME hint.
    final desiredExt = switch (kind) {
      _ViewerKind.pdf => '.pdf',
      _ViewerKind.image => _imageExtFromBytes(),
      _ViewerKind.unsupported => null,
    };
    if (desiredExt != null) {
      final base = cleaned.contains('.')
          ? cleaned.substring(0, cleaned.lastIndexOf('.'))
          : cleaned;
      cleaned = '$base$desiredExt';
    }
    return cleaned;
  }

  String _imageExtFromBytes() {
    final b = _bytes;
    if (b == null || b.length < 4) return '.img';
    if (b[0] == 0x89 && b[1] == 0x50) return '.png';
    if (b[0] == 0xFF && b[1] == 0xD8) return '.jpg';
    if (b[0] == 0x47 && b[1] == 0x49) return '.gif';
    if (b[0] == 0x52 && b[1] == 0x49) return '.webp';
    if (b[0] == 0x42 && b[1] == 0x4D) return '.bmp';
    return '.img';
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
        return _UnsupportedView(
          title: widget.title,
          onOpenExternal: _openExternally,
          onShare: _localPath == null ? null : _share,
        );
    }
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({
    required this.title,
    required this.onOpenExternal,
    this.onShare,
  });

  final String title;
  final VoidCallback onOpenExternal;
  final VoidCallback? onShare;

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
              'Download it or open it in another app to view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onShare != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download'),
                    onPressed: onShare,
                  ),
                OutlinedButton.icon(
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
