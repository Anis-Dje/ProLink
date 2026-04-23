import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import '../core/constants/app_constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePhoto(String userId, File image) async {
    final ext = p.extension(image.path);
    final ref = _storage.ref().child(
          '${AppConstants.profilePhotosPath}/$userId$ext',
        );
    final task = await ref.putFile(image);
    return task.ref.getDownloadURL();
  }

  Future<String> uploadTrainingFile(
    String mentorId,
    File file,
    String title,
  ) async {
    final ext = p.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$title$ext';
    final ref = _storage.ref().child(
          '${AppConstants.trainingFilesPath}/$mentorId/$fileName',
        );
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<String> uploadSchedule(
    String adminId,
    File file,
    String weekLabel,
  ) async {
    final ext = p.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$weekLabel$ext';
    final ref = _storage.ref().child(
          '${AppConstants.schedulesPath}/$adminId/$fileName',
        );
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<String> uploadPolicyDocument(
    String adminId,
    File file,
    String title,
  ) async {
    final ext = p.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$title$ext';
    final ref = _storage.ref().child(
          '${AppConstants.policiesPath}/$adminId/$fileName',
        );
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (_) {
      // File may already be deleted or URL invalid
    }
  }

  UploadTask uploadFileWithProgress(
    String path,
    File file,
  ) {
    final ref = _storage.ref().child(path);
    return ref.putFile(file);
  }
}
