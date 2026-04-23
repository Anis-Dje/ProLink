import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String uploadedBy;
  final DateTime uploadDate;
  final String? departmentId;
  final String weekLabel;

  const ScheduleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadDate,
    this.departmentId,
    required this.weekLabel,
  });

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      uploadedBy: data['uploadedBy'] ?? '',
      uploadDate: (data['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      departmentId: data['departmentId'],
      weekLabel: data['weekLabel'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'uploadedBy': uploadedBy,
      'uploadDate': Timestamp.fromDate(uploadDate),
      'departmentId': departmentId,
      'weekLabel': weekLabel,
    };
  }
}
