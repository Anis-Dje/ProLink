import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String internId;
  final String mentorId;
  final DateTime date;
  final String status;
  final String? note;

  const AttendanceModel({
    required this.id,
    required this.internId,
    required this.mentorId,
    required this.date,
    required this.status,
    this.note,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      internId: data['internId'] ?? '',
      mentorId: data['mentorId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'absent',
      note: data['note'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'internId': internId,
      'mentorId': mentorId,
      'date': Timestamp.fromDate(date),
      'status': status,
      'note': note,
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? internId,
    String? mentorId,
    DateTime? date,
    String? status,
    String? note,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      internId: internId ?? this.internId,
      mentorId: mentorId ?? this.mentorId,
      date: date ?? this.date,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}
