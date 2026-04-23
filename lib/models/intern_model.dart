import 'package:cloud_firestore/cloud_firestore.dart';

class InternModel {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String studentId;
  final String department;
  final String? mentorId;
  final String? profilePhotoUrl;
  final String status;
  final DateTime registrationDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String university;
  final String specialization;
  final String? rejectionReason;

  const InternModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.studentId,
    required this.department,
    this.mentorId,
    this.profilePhotoUrl,
    required this.status,
    required this.registrationDate,
    this.startDate,
    this.endDate,
    required this.university,
    required this.specialization,
    this.rejectionReason,
  });

  factory InternModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InternModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      studentId: data['studentId'] ?? '',
      department: data['department'] ?? '',
      mentorId: data['mentorId'],
      profilePhotoUrl: data['profilePhotoUrl'],
      status: data['status'] ?? 'pending',
      registrationDate: (data['registrationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      university: data['university'] ?? '',
      specialization: data['specialization'] ?? '',
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'studentId': studentId,
      'department': department,
      'mentorId': mentorId,
      'profilePhotoUrl': profilePhotoUrl,
      'status': status,
      'registrationDate': Timestamp.fromDate(registrationDate),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'university': university,
      'specialization': specialization,
      'rejectionReason': rejectionReason,
    };
  }

  InternModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? studentId,
    String? department,
    String? mentorId,
    String? profilePhotoUrl,
    String? status,
    DateTime? registrationDate,
    DateTime? startDate,
    DateTime? endDate,
    String? university,
    String? specialization,
    String? rejectionReason,
  }) {
    return InternModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      studentId: studentId ?? this.studentId,
      department: department ?? this.department,
      mentorId: mentorId ?? this.mentorId,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      status: status ?? this.status,
      registrationDate: registrationDate ?? this.registrationDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      university: university ?? this.university,
      specialization: specialization ?? this.specialization,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
