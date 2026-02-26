import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

/// Organization model for managing different entities
class Organization {
  final String id;
  final String name;
  final String code; // Short code like "HCSEA", "SEUM"
  final String? description;
  final String? address;
  final String? contactEmail;
  final String? contactPhone;
  final String? logoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  Organization({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.address,
    this.contactEmail,
    this.contactPhone,
    this.logoUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory Organization.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Organization(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      description: data['description'],
      address: data['address'],
      contactEmail: data['contactEmail'],
      contactPhone: data['contactPhone'],
      logoUrl: data['logoUrl'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']),
      createdBy: data['createdBy'],
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is firestore.Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'description': description,
      'address': address,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'logoUrl': logoUrl,
      'isActive': isActive,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : firestore.FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  Organization copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? address,
    String? contactEmail,
    String? contactPhone,
    String? logoUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      address: address ?? this.address,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() => 'Organization($code: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organization &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
