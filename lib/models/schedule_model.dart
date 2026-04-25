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

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? '',
      uploadedBy: json['uploadedBy'] as String? ?? '',
      uploadDate: DateTime.tryParse(json['uploadDate'] as String? ?? '') ??
          DateTime.now(),
      departmentId: json['departmentId'] as String?,
      weekLabel: json['weekLabel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'uploadedBy': uploadedBy,
        'uploadDate': uploadDate.toUtc().toIso8601String(),
        'departmentId': departmentId,
        'weekLabel': weekLabel,
      };
}
