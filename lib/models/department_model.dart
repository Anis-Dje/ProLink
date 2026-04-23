import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentModel {
  final String id;
  final String name;
  final String description;
  final String headMentorId;
  final List<String> internIds;
  final List<String> mentorIds;

  const DepartmentModel({
    required this.id,
    required this.name,
    required this.description,
    required this.headMentorId,
    required this.internIds,
    required this.mentorIds,
  });

  factory DepartmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DepartmentModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      headMentorId: data['headMentorId'] ?? '',
      internIds: List<String>.from(data['internIds'] ?? []),
      mentorIds: List<String>.from(data['mentorIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'headMentorId': headMentorId,
      'internIds': internIds,
      'mentorIds': mentorIds,
    };
  }

  DepartmentModel copyWith({
    String? id,
    String? name,
    String? description,
    String? headMentorId,
    List<String>? internIds,
    List<String>? mentorIds,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      headMentorId: headMentorId ?? this.headMentorId,
      internIds: internIds ?? this.internIds,
      mentorIds: mentorIds ?? this.mentorIds,
    );
  }
}
