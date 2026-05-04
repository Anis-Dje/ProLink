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

  /// True when this file was uploaded by an admin (policies, general
  /// resources). Admin uploads are visible to every intern regardless
  /// of mentor; mentor uploads are scoped to that mentor's interns.
  final bool isAdminUploaded;

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
    this.isAdminUploaded = false,
  });

  factory TrainingFileModel.fromJson(Map<String, dynamic> json) {
    final rawTags = (json['tags'] as List?) ?? const [];
    return TrainingFileModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? '',
      fileType: json['fileType'] as String? ?? 'pdf',
      uploadedBy: json['uploadedBy'] as String? ?? '',
      uploadDate: DateTime.tryParse(json['uploadDate'] as String? ?? '') ??
          DateTime.now(),
      departmentId: json['departmentId'] as String?,
      tags: rawTags.map((e) => e.toString()).toList(),
      isAdminUploaded: json['isAdminUploaded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'uploadedBy': uploadedBy,
        'uploadDate': uploadDate.toUtc().toIso8601String(),
        'departmentId': departmentId,
        'tags': tags,
        'isAdminUploaded': isAdminUploaded,
      };
}
