import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/file_launcher.dart';
import '../../services/legal_documents_service.dart';

/// Loads the current Privacy Policy + Terms & Conditions documents
/// and renders the [builder] with the resolved URLs (null if the
/// admin hasn't published a matching document yet).
class LegalDocumentsLoader extends StatefulWidget {
  const LegalDocumentsLoader({super.key, required this.builder});

  final Widget Function(BuildContext context, LegalDocuments docs) builder;

  @override
  State<LegalDocumentsLoader> createState() => _LegalDocumentsLoaderState();
}

class _LegalDocumentsLoaderState extends State<LegalDocumentsLoader> {
  late Future<LegalDocuments> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<LegalDocumentsService>().fetch();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LegalDocuments>(
      future: _future,
      builder: (context, snap) {
        // Render even while loading or on error: the policy text falls
        // back to plain (un-linked) words so the screen never blocks on
        // the network call.
        final docs = snap.data ?? const LegalDocuments();
        return widget.builder(context, docs);
      },
    );
  }
}

/// A `RichText` line saying e.g. "By logging in you agree to the
/// **Privacy Policy** and **Terms & Conditions**." with each phrase
/// turned into a tappable hyperlink that opens the corresponding PDF
/// inline via [FileLauncher].
class LegalLinksLine extends StatelessWidget {
  const LegalLinksLine({
    super.key,
    required this.docs,
    required this.leadingText,
  });

  final LegalDocuments docs;
  final String leadingText;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
        children: [
          TextSpan(text: leadingText),
          _legalSpan(
            context,
            label: 'Privacy Policy',
            doc: docs.privacy,
          ),
          const TextSpan(text: ' and '),
          _legalSpan(
            context,
            label: 'Terms & Conditions',
            doc: docs.terms,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

InlineSpan _legalSpan(
  BuildContext context, {
  required String label,
  required LegalDocument? doc,
}) {
  if (doc == null) {
    // Admin hasn't uploaded this one yet — render as italic but inert.
    return TextSpan(
      text: label,
      style: const TextStyle(
        fontStyle: FontStyle.italic,
        color: AppColors.textSecondary,
      ),
    );
  }
  return TextSpan(
    text: label,
    style: const TextStyle(
      color: AppColors.accent,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    ),
    recognizer: TapGestureRecognizer()
      ..onTap = () =>
          FileLauncher.open(context, doc.fileUrl, title: doc.title),
  );
}
