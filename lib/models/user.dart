import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

/// Media production permission settings for a user
class MediaPermissions {
  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  final List<String> assignedLanguages; // Language codes: ['en', 'th', 'km', etc.]

  const MediaPermissions({
    this.canView = false,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
    this.assignedLanguages = const [],
  });

  factory MediaPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MediaPermissions();
    return MediaPermissions(
      canView: map['canView'] as bool? ?? false,
      canAdd: map['canAdd'] as bool? ?? false,
      canEdit: map['canEdit'] as bool? ?? false,
      canDelete: map['canDelete'] as bool? ?? false,
      assignedLanguages: (map['assignedLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canView': canView,
      'canAdd': canAdd,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'assignedLanguages': assignedLanguages,
    };
  }

  MediaPermissions copyWith({
    bool? canView,
    bool? canAdd,
    bool? canEdit,
    bool? canDelete,
    List<String>? assignedLanguages,
  }) {
    return MediaPermissions(
      canView: canView ?? this.canView,
      canAdd: canAdd ?? this.canAdd,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      assignedLanguages: assignedLanguages ?? this.assignedLanguages,
    );
  }

  /// Returns full permissions with all languages
  static MediaPermissions get full => const MediaPermissions(
        canView: true,
        canAdd: true,
        canEdit: true,
        canDelete: true,
        assignedLanguages: ['en', 'ms', 'th', 'km', 'lo', 'zh', 'vi'],
      );

  /// Returns view-only permissions with all languages
  static MediaPermissions get viewOnly => const MediaPermissions(
        canView: true,
        canAdd: false,
        canEdit: false,
        canDelete: false,
        assignedLanguages: ['en', 'ms', 'th', 'km', 'lo', 'zh', 'vi'],
      );

  /// Returns no permissions
  static MediaPermissions get none => const MediaPermissions();

  /// Check if user can manage a specific language
  bool canManageLanguage(String languageCode) {
    return assignedLanguages.contains(languageCode);
  }
}

/// Section-level access permissions for app modules.
/// Each section has independent view (read) and edit (create/modify/delete) flags.
class SectionPermissions {
  // Finance: cash advance, petty cash, purchase requisitions, income reports
  final bool financeView;
  final bool financeEdit;

  // Meetings: meetings list, ADCOM agenda, minutes
  final bool meetingsView;
  final bool meetingsEdit;

  // HR: staff directory, salary/benefits, employment letters, annual leave
  final bool hrView;
  final bool hrEdit;

  // Reports: traveling reports, project reports
  final bool reportsView;
  final bool reportsEdit;

  // Student: student management, timesheets
  final bool studentView;
  final bool studentEdit;

  const SectionPermissions({
    this.financeView = false,
    this.financeEdit = false,
    this.meetingsView = false,
    this.meetingsEdit = false,
    this.hrView = false,
    this.hrEdit = false,
    this.reportsView = false,
    this.reportsEdit = false,
    this.studentView = false,
    this.studentEdit = false,
  });

  factory SectionPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SectionPermissions();
    return SectionPermissions(
      financeView: map['financeView'] as bool? ?? false,
      financeEdit: map['financeEdit'] as bool? ?? false,
      meetingsView: map['meetingsView'] as bool? ?? false,
      meetingsEdit: map['meetingsEdit'] as bool? ?? false,
      hrView: map['hrView'] as bool? ?? false,
      hrEdit: map['hrEdit'] as bool? ?? false,
      reportsView: map['reportsView'] as bool? ?? false,
      reportsEdit: map['reportsEdit'] as bool? ?? false,
      studentView: map['studentView'] as bool? ?? false,
      studentEdit: map['studentEdit'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'financeView': financeView,
        'financeEdit': financeEdit,
        'meetingsView': meetingsView,
        'meetingsEdit': meetingsEdit,
        'hrView': hrView,
        'hrEdit': hrEdit,
        'reportsView': reportsView,
        'reportsEdit': reportsEdit,
        'studentView': studentView,
        'studentEdit': studentEdit,
      };

  SectionPermissions copyWith({
    bool? financeView,
    bool? financeEdit,
    bool? meetingsView,
    bool? meetingsEdit,
    bool? hrView,
    bool? hrEdit,
    bool? reportsView,
    bool? reportsEdit,
    bool? studentView,
    bool? studentEdit,
  }) =>
      SectionPermissions(
        financeView: financeView ?? this.financeView,
        financeEdit: financeEdit ?? this.financeEdit,
        meetingsView: meetingsView ?? this.meetingsView,
        meetingsEdit: meetingsEdit ?? this.meetingsEdit,
        hrView: hrView ?? this.hrView,
        hrEdit: hrEdit ?? this.hrEdit,
        reportsView: reportsView ?? this.reportsView,
        reportsEdit: reportsEdit ?? this.reportsEdit,
        studentView: studentView ?? this.studentView,
        studentEdit: studentEdit ?? this.studentEdit,
      );

  /// Returns full access to all sections.
  static SectionPermissions get full => const SectionPermissions(
        financeView: true,
        financeEdit: true,
        meetingsView: true,
        meetingsEdit: true,
        hrView: true,
        hrEdit: true,
        reportsView: true,
        reportsEdit: true,
        studentView: true,
        studentEdit: true,
      );

  /// Returns view-only access to all sections.
  static SectionPermissions get viewOnly => const SectionPermissions(
        financeView: true,
        meetingsView: true,
        hrView: true,
        reportsView: true,
        studentView: true,
      );

  /// Returns no section permissions.
  static SectionPermissions get none => const SectionPermissions();

  bool get hasAny =>
      financeView ||
      financeEdit ||
      meetingsView ||
      meetingsEdit ||
      hrView ||
      hrEdit ||
      reportsView ||
      reportsEdit ||
      studentView ||
      studentEdit;

  int get enabledCount => [
        financeView, financeEdit,
        meetingsView, meetingsEdit,
        hrView, hrEdit,
        reportsView, reportsEdit,
        studentView, studentEdit,
      ].where((b) => b).length;
}

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
  final String? organizationId; // Organization ID for inventory access
  final String? organizationName; // Organization name for display
  final DateTime createdAt;
  final DateTime? updatedAt;
  final InventoryPermissions inventoryPermissions;
  final MediaPermissions mediaPermissions;
  final SectionPermissions sectionPermissions;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.photoUrl,
    this.organizationId,
    this.organizationName,
    required this.createdAt,
    this.updatedAt,
    this.inventoryPermissions = const InventoryPermissions(),
    this.mediaPermissions = const MediaPermissions(),
    this.sectionPermissions = const SectionPermissions(),
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
      'organizationId': organizationId,
      'organizationName': organizationName,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
      'inventoryPermissions': inventoryPermissions.toMap(),
      'mediaPermissions': mediaPermissions.toMap(),
      'sectionPermissions': sectionPermissions.toMap(),
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
      organizationId: data['organizationId'] as String?,
      organizationName: data['organizationName'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      inventoryPermissions: InventoryPermissions.fromMap(
        data['inventoryPermissions'] as Map<String, dynamic>?,
      ),
      mediaPermissions: MediaPermissions.fromMap(
        data['mediaPermissions'] as Map<String, dynamic>?,
      ),
      sectionPermissions: SectionPermissions.fromMap(
        data['sectionPermissions'] as Map<String, dynamic>?,
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
      'organizationId': organizationId,
      'organizationName': organizationName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'inventoryPermissions': inventoryPermissions.toMap(),
      'mediaPermissions': mediaPermissions.toMap(),
      'sectionPermissions': sectionPermissions.toMap(),
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
      organizationId: json['organizationId'] as String?,
      organizationName: json['organizationName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      inventoryPermissions: InventoryPermissions.fromMap(
        json['inventoryPermissions'] as Map<String, dynamic>?,
      ),
      mediaPermissions: MediaPermissions.fromMap(
        json['mediaPermissions'] as Map<String, dynamic>?,
      ),
      sectionPermissions: SectionPermissions.fromMap(
        json['sectionPermissions'] as Map<String, dynamic>?,
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
    String? organizationId,
    String? organizationName,
    DateTime? updatedAt,
    InventoryPermissions? inventoryPermissions,
    MediaPermissions? mediaPermissions,
    SectionPermissions? sectionPermissions,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      photoUrl: photoUrl ?? this.photoUrl,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      inventoryPermissions: inventoryPermissions ?? this.inventoryPermissions,
      mediaPermissions: mediaPermissions ?? this.mediaPermissions,
      sectionPermissions: sectionPermissions ?? this.sectionPermissions,
    );
  }
}
