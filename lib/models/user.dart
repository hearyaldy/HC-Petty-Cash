import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

class User {
  final String id; // Firebase Auth UID
  final String name;
  final String email;
  final String role; // Store as string: 'requester', 'manager', 'finance', 'admin'
  final String department;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    required this.createdAt,
    this.updatedAt,
  });

  // Get UserRole enum from string
  UserRole get roleEnum => UserRole.values.firstWhere(
        (e) => e.name == role,
        orElse: () => UserRole.requester,
      );

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory User.fromFirestore(firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return User(
      id: doc.id,
      name: data['name'] as String,
      email: data['email'] as String,
      role: data['role'] as String,
      department: data['department'] as String,
      createdAt: (data['createdAt'] as firestore.Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }

  // Keep existing toJson/fromJson for backward compatibility if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      department: json['department'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  // Helper method to create a copy with updates
  User copyWith({
    String? name,
    String? email,
    String? role,
    String? department,
    DateTime? updatedAt,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
