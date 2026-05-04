import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../screens/common/file_viewer_screen.dart';
import 'app_utils.dart';

/// Opens [url] inside the app for previewable formats (PDF, images),
/// falling back to the device's default external app for everything
/// else (.docx, .xlsx, links, etc.). Surfaces a snackbar on the
/// [context] when the URL is invalid or no handler is available so
/// the user gets a clear failure instead of nothing.
class FileLauncher {
  FileLauncher._();

  static Future<void> open(
    BuildContext context,
    String url, {
    String title = 'File',
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      AppUtils.showSnackBar(context, 'No file URL attached', isError: true);
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      AppUtils.showSnackBar(context, 'Invalid file URL: $trimmed',
          isError: true);
      return;
    }
    // Always route uploads served by our own backend through the
    // in-app viewer. The viewer downloads the bytes, sniffs the magic
    // header, and either renders inline (PDF / images) or shows a
    // "Download / Open externally" fallback. This is critical for
    // legacy uploads saved as `.bin` (when the client filename
    // derivation didn't include an extension): the URL extension lies
    // about the type, but the bytes don't.
    final isOurFile = uri.path.contains('/files/');
    if (isOurFile || FileViewerScreen.canPreview(trimmed)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FileViewerScreen(url: trimmed, title: title),
        ),
      );
      return;
    }
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        AppUtils.showSnackBar(
          context,
          'Could not open the file. Make sure you have a PDF / browser '
              'app installed.',
          isError: true,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppUtils.showSnackBar(context, 'Could not open: $e', isError: true);
      }
    }
  }
}
