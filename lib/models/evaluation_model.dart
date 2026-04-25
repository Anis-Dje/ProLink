class EvaluationModel {
  final String id;
  final String internId;
  final String mentorId;
  final String title;
  final String description;
  final Map<String, double> criteria;
  final double overallScore;
  final String comment;
  final DateTime evaluationDate;

  const EvaluationModel({
    required this.id,
    required this.internId,
    required this.mentorId,
    required this.title,
    required this.description,
    required this.criteria,
    required this.overallScore,
    required this.comment,
    required this.evaluationDate,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['criteria'] as Map?) ?? const {};
    final criteria = <String, double>{};
    raw.forEach((k, v) {
      if (v is num) criteria[k.toString()] = v.toDouble();
    });
    return EvaluationModel(
      id: json['id'] as String,
      internId: json['internId'] as String? ?? '',
      mentorId: json['mentorId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      criteria: criteria,
      overallScore:
          (json['overallScore'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String? ?? '',
      evaluationDate:
          DateTime.tryParse(json['evaluationDate'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'internId': internId,
        'mentorId': mentorId,
        'title': title,
        'description': description,
        'criteria': criteria,
        'overallScore': overallScore,
        'comment': comment,
        'evaluationDate': evaluationDate.toUtc().toIso8601String(),
      };

  double get computedAverage {
    if (criteria.isEmpty) return 0;
    final sum = criteria.values.reduce((a, b) => a + b);
    return sum / criteria.length;
  }
}
