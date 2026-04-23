import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingFileModel {
  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String fileType;
  final String uploadedBy;
  final DateTime uploadDate;
  final String? departmentId;
  final List<String> tags;

  const TrainingFileModel({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.fileType,
    required this.uploadedBy,
    required this.uploadDate,
    this.departmentId,
    required this.tags,
  });

  factory TrainingFileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingFileModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileType: data['fileType'] ?? 'pdf',
      uploadedBy: data['uploadedBy'] ?? '',
      uploadDate: (data['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      departmentId: data['departmentId'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'uploadedBy': uploadedBy,
      'uploadDate': Timestamp.fromDate(uploadDate),
      'departmentId': departmentId,
      'tags': tags,
    };
  }
}
