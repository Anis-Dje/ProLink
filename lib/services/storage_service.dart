import 'package:cross_file/cross_file.dart';

import 'api_client.dart';

/// Uploads files to the Pro-Link PHP backend. The backend stores them on
/// local disk under `server/uploads/` and serves them at `/files/...`. The
/// returned URL is the public URL pointing at the served file.
///
/// Inputs are `XFile` (from `image_picker`/`file_picker`) so the uploads
/// work on every platform — including Flutter web, where `dart:io File`
/// is unavailable.
class StorageService {
  StorageService(this._api);
  final ApiClient _api;

  Future<String> uploadProfilePhoto(String userId, XFile image) {
    return _api.uploadFile(image);
  }

  Future<String> uploadTrainingFile(
    String mentorId,
    XFile file,
    String title,
  ) {
    return _api.uploadFile(file);
  }

  Future<String> uploadSchedule(
    String adminId,
    XFile file,
    String weekLabel,
  ) {
    return _api.uploadFile(file);
  }

  Future<String> uploadPolicyDocument(
    String adminId,
    XFile file,
    String title,
  ) {
    return _api.uploadFile(file);
  }

  /// File deletion is not yet supported by the new backend. No-op so callers
  /// don't break.
  Future<void> deleteFile(String fileUrl) async {}
}
