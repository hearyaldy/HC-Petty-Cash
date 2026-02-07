import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

/// Inventory permission settings for a user
class InventoryPermissions {
  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  final bool canCheckout;

  const InventoryPermissions({
    this.canView = false,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canCheckout = false,
  });

  factory InventoryPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const InventoryPermissions();
    return InventoryPermissions(
      canView: map['canView'] as bool? ?? false,
      canAdd: map['canAdd'] as bool? ?? false,
      canEdit: map['canEdit'] as bool? ?? false,
      canDelete: map['canDelete'] as bool? ?? false,
      canCheckout: map['canCheckout'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canView': canView,
      'canAdd': canAdd,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'canCheckout': canCheckout,
    };
  }

  InventoryPermissions copyWith({
    bool? canView,
    bool? canAdd,
    bool? canEdit,
    bool? canDelete,
    bool? canCheckout,
  }) {
    return InventoryPermissions(
      canView: canView ?? this.canView,
      canAdd: canAdd ?? this.canAdd,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      canCheckout: canCheckout ?? this.canCheckout,
    );
  }

  /// Returns full permissions (admin-level)
  static InventoryPermissions get full => const InventoryPermissions(
        canView: true,
        canAdd: true,
        canEdit: true,
        canDelete: true,
        canCheckout: true,
      );

  /// Returns view-only permissions
  static InventoryPermissions get viewOnly => const InventoryPermissions(
        canView: true,
        canAdd: false,
        canEdit: false,
        canDelete: false,
        canCheckout: false,
      );

  /// Returns no permissions
  static InventoryPermissions get none => const InventoryPermissions();
}

class User {
  final String id; // Firebase Auth UID
  final String name;
  final String email;
  final String role; // Store as string: 'requester', 'manager', 'finance', 'admin'
  final String department;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final InventoryPermissions inventoryPermissions;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
    this.inventoryPermissions = const InventoryPermissions(),
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
      'inventoryPermissions': inventoryPermissions.toMap(),
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
      inventoryPermissions: InventoryPermissions.fromMap(
        data['inventoryPermissions'] as Map<String, dynamic>?,
      ),
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
      'inventoryPermissions': inventoryPermissions.toMap(),
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
      inventoryPermissions: InventoryPermissions.fromMap(
        json['inventoryPermissions'] as Map<String, dynamic>?,
      ),
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
    InventoryPermissions? inventoryPermissions,
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
      inventoryPermissions: inventoryPermissions ?? this.inventoryPermissions,
    );
  }
}
