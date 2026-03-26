import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, instructor }

enum ProfileVisibility { public, private }

class ProfileModel {
  const ProfileModel({
    required this.userId,
    required this.email,
    required this.username,
    required this.role,
    required this.visibility,
    required this.updatedAt,
    this.displayName,
    this.studentAvatarUrl,
    this.instructorAvatarUrl,
  });

  final String userId;
  final String email;
  final String username;
  final UserRole role;
  final ProfileVisibility visibility;
  final DateTime updatedAt;
  final String? displayName;
  final String? studentAvatarUrl;
  final String? instructorAvatarUrl;

  static String encodeValue(String value) => base64Encode(utf8.encode(value));

  static String decodeValue(String value) {
    try {
      return utf8.decode(base64Decode(value));
    } catch (_) {
      return value;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'userId': encodeValue(userId),
    'email': encodeValue(email),
    'username': encodeValue(username),
    'displayName': displayName != null ? encodeValue(displayName!) : null,
    'role': role.name,
    'visibility': visibility.name,
    'updatedAt': FieldValue.serverTimestamp(),
    'studentAvatarUrl': studentAvatarUrl,
    'instructorAvatarUrl': instructorAvatarUrl,
  };

  factory ProfileModel.fromFirestore(Map<String, dynamic> data) => ProfileModel(
    userId: decodeValue(data['userId'] as String? ?? ''),
    email: decodeValue(data['email'] as String? ?? ''),
    username: decodeValue(data['username'] as String? ?? ''),
    displayName: data['displayName'] != null
        ? decodeValue(data['displayName'] as String)
        : null,
    role: UserRole.values.firstWhere(
      (r) => r.name == data['role'],
      orElse: () => UserRole.student,
    ),
    visibility: ProfileVisibility.values.firstWhere(
      (v) => v.name == data['visibility'],
      orElse: () => ProfileVisibility.public,
    ),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    studentAvatarUrl: data['studentAvatarUrl'] as String?,
    instructorAvatarUrl: data['instructorAvatarUrl'] as String?,
  );

  ProfileModel copyWith({
    String? userId,
    String? email,
    String? username,
    UserRole? role,
    ProfileVisibility? visibility,
    DateTime? updatedAt,
    String? displayName,
    String? studentAvatarUrl,
    String? instructorAvatarUrl,
  }) => ProfileModel(
    userId: userId ?? this.userId,
    email: email ?? this.email,
    username: username ?? this.username,
    role: role ?? this.role,
    visibility: visibility ?? this.visibility,
    updatedAt: updatedAt ?? this.updatedAt,
    displayName: displayName ?? this.displayName,
    studentAvatarUrl: studentAvatarUrl ?? this.studentAvatarUrl,
    instructorAvatarUrl: instructorAvatarUrl ?? this.instructorAvatarUrl,
  );
}
