import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, mentor, intern }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.mentor:
        return 'mentor';
      case UserRole.intern:
        return 'intern';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'mentor':
        return UserRole.mentor;
      case 'intern':
        return UserRole.intern;
      default:
        return UserRole.intern;
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? profilePhotoUrl;
  final DateTime createdAt;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.profilePhotoUrl,
    required this.createdAt,
    required this.isActive,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      role: UserRoleExtension.fromString(data['role'] ?? 'intern'),
      profilePhotoUrl: data['profilePhotoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.value,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    String? profilePhotoUrl,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
