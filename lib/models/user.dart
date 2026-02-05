import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

class User {
  final String id; // Firebase Auth UID
  final String name;
  final String email;
  final String role; // Store as string: 'requester', 'manager', 'finance', 'admin'
  final String department;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.photoUrl,
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
      'photoUrl': photoUrl,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory User.fromFirestore(firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('User document ${doc.id} has no data');
    }

    // Parse createdAt with fallback to current time
    DateTime createdAt;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is firestore.Timestamp) {
        createdAt = (data['createdAt'] as firestore.Timestamp).toDate();
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    // Parse updatedAt
    DateTime? updatedAt;
    if (data['updatedAt'] != null && data['updatedAt'] is firestore.Timestamp) {
      updatedAt = (data['updatedAt'] as firestore.Timestamp).toDate();
    }

    return User(
      id: doc.id,
      name: data['name'] as String? ?? 'Unknown',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'requester',
      department: data['department'] as String? ?? 'Unknown',
      photoUrl: data['photoUrl'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
      'photoUrl': photoUrl,
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
      photoUrl: json['photoUrl'] as String?,
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
    String? photoUrl,
    DateTime? updatedAt,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
