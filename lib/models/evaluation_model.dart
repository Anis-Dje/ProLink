import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory EvaluationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawCriteria = data['criteria'] as Map<String, dynamic>? ?? {};
    return EvaluationModel(
      id: doc.id,
      internId: data['internId'] ?? '',
      mentorId: data['mentorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      criteria: rawCriteria.map((k, v) => MapEntry(k, (v as num).toDouble())),
      overallScore: (data['overallScore'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] ?? '',
      evaluationDate: (data['evaluationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'internId': internId,
      'mentorId': mentorId,
      'title': title,
      'description': description,
      'criteria': criteria,
      'overallScore': overallScore,
      'comment': comment,
      'evaluationDate': Timestamp.fromDate(evaluationDate),
    };
  }

  double get computedAverage {
    if (criteria.isEmpty) return 0;
    final sum = criteria.values.reduce((a, b) => a + b);
    return sum / criteria.length;
  }
}
