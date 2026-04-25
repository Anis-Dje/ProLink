import 'dart:io';

import 'api_client.dart';

/// Uploads files to the Pro-Link backend. The backend stores them on local
/// disk and serves them at `/files/...`. The returned URL is the public URL
/// pointing at the served file.
class StorageService {
  StorageService(this._api);
  final ApiClient _api;

  Future<String> uploadProfilePhoto(String userId, File image) {
    return _api.uploadFile(image);
  }

  Future<String> uploadTrainingFile(
    String mentorId,
    File file,
    String title,
  ) {
    return _api.uploadFile(file);
  }

  Future<String> uploadSchedule(
    String adminId,
    File file,
    String weekLabel,
  ) {
    return _api.uploadFile(file);
  }

  Future<String> uploadPolicyDocument(
    String adminId,
    File file,
    String title,
  ) {
    return _api.uploadFile(file);
  }

  /// File deletion is not yet supported by the new backend. No-op so callers
  /// don't break.
  Future<void> deleteFile(String fileUrl) async {}
}
