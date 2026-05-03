import 'api_client.dart';

/// One of the two legal documents the admin has uploaded (Privacy
/// Policy or Terms & Conditions). Backed by the most recent
/// training_files row whose title matches the corresponding keyword
/// on the server.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.fileUrl,
  });

  final String id;
  final String title;
  final String fileUrl;

  static LegalDocument? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    final url = (raw['fileUrl'] ?? '') as String;
    if (url.isEmpty) return null;
    return LegalDocument(
      id: (raw['id'] ?? '') as String,
      title: (raw['title'] ?? '') as String,
      fileUrl: url,
    );
  }
}

/// Pair returned by `GET /api/legal-documents`.
class LegalDocuments {
  const LegalDocuments({this.privacy, this.terms});
  final LegalDocument? privacy;
  final LegalDocument? terms;
}

/// Reads the current Privacy Policy + Terms & Conditions documents
/// from the public, un-authenticated `/api/legal-documents` endpoint.
/// Used by the registration / login screens to render hyperlinks
/// before a session token exists.
class LegalDocumentsService {
  LegalDocumentsService(this._api);
  final ApiClient _api;

  Future<LegalDocuments> fetch() async {
    final res = await _api.get('/legal-documents');
    return LegalDocuments(
      privacy: LegalDocument.fromJsonOrNull(res['privacy']),
      terms: LegalDocument.fromJsonOrNull(res['terms']),
    );
  }
}
