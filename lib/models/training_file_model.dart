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
      };
}
