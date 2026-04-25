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

  factory InternModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v is String ? DateTime.tryParse(v) : null;
    return InternModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      department: json['department'] as String? ?? '',
      mentorId: json['mentorId'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      status: json['status'] as String? ?? 'pending',
      registrationDate:
          parse(json['registrationDate']) ?? DateTime.now(),
      startDate: parse(json['startDate']),
      endDate: parse(json['endDate']),
      university: json['university'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'studentId': studentId,
        'department': department,
        'mentorId': mentorId,
        'profilePhotoUrl': profilePhotoUrl,
        'status': status,
        'registrationDate': registrationDate.toUtc().toIso8601String(),
        'startDate': startDate?.toUtc().toIso8601String(),
        'endDate': endDate?.toUtc().toIso8601String(),
        'university': university,
        'specialization': specialization,
        'rejectionReason': rejectionReason,
      };

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
