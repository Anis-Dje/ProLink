/// Audience scope for an admin-uploaded schedule. The admin picks one of
/// these when publishing — the backend then filters subsequent GETs so
/// each user only sees the schedules that target them.
enum ScheduleScopeType { public, specialization, intern }

extension ScheduleScopeTypeExtension on ScheduleScopeType {
  String get value {
    switch (this) {
      case ScheduleScopeType.public:
        return 'public';
      case ScheduleScopeType.specialization:
        return 'specialization';
      case ScheduleScopeType.intern:
        return 'intern';
    }
  }

  static ScheduleScopeType fromString(String? v) {
    switch (v) {
      case 'specialization':
        return ScheduleScopeType.specialization;
      case 'intern':
        return ScheduleScopeType.intern;
      case 'public':
      default:
        return ScheduleScopeType.public;
    }
  }
}

class ScheduleModel {
  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String uploadedBy;
  final DateTime uploadDate;
  final String? departmentId;
  final String weekLabel;

  /// Visibility scope picked by the admin at upload time.
  final ScheduleScopeType scopeType;

  /// Specialization label or intern user_id depending on [scopeType];
  /// empty string when [scopeType] is `public`.
  final String scopeValue;

  const ScheduleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadDate,
    this.departmentId,
    required this.weekLabel,
    this.scopeType = ScheduleScopeType.public,
    this.scopeValue = '',
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
      scopeType:
          ScheduleScopeTypeExtension.fromString(json['scopeType'] as String?),
      scopeValue: json['scopeValue'] as String? ?? '',
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
        'scopeType': scopeType.value,
        'scopeValue': scopeValue,
      };
}
