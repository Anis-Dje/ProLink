import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_utils.dart';

/// Opens [url] in the device's default external app — browser for web
/// links, PDF reader for `.pdf`, gallery for images, etc. Surfaces a
/// snackbar on the [context] if the URL is invalid or no handler is
/// available so the user gets a clear failure instead of nothing.
class FileLauncher {
  FileLauncher._();

  static Future<void> open(BuildContext context, String url) async {
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
