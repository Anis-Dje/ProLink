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

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      internId: json['internId'] as String? ?? '',
      mentorId: json['mentorId'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'absent',
      note: (json['notes'] ?? json['note']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'internId': internId,
        'mentorId': mentorId,
        'date': date.toUtc().toIso8601String(),
        'status': status,
        'notes': note,
      };

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
