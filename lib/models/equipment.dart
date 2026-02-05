import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

/// Equipment status enum
enum EquipmentStatus {
  available,
  checkedOut,
  maintenance,
  retired;

  String get displayName {
    switch (this) {
      case EquipmentStatus.available:
        return 'Available';
      case EquipmentStatus.checkedOut:
        return 'Checked Out';
      case EquipmentStatus.maintenance:
        return 'Under Maintenance';
      case EquipmentStatus.retired:
        return 'Retired';
    }
  }

  static EquipmentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'available':
        return EquipmentStatus.available;
      case 'checkedout':
      case 'checked_out':
        return EquipmentStatus.checkedOut;
      case 'maintenance':
      case 'under_maintenance':
        return EquipmentStatus.maintenance;
      case 'retired':
        return EquipmentStatus.retired;
      default:
        return EquipmentStatus.available;
    }
  }
}

/// Equipment condition enum
enum EquipmentCondition {
  excellent,
  good,
  fair,
  poor;

  String get displayName {
    switch (this) {
      case EquipmentCondition.excellent:
        return 'Excellent';
      case EquipmentCondition.good:
        return 'Good';
      case EquipmentCondition.fair:
        return 'Fair';
      case EquipmentCondition.poor:
        return 'Poor';
    }
  }

  static EquipmentCondition fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'excellent':
        return EquipmentCondition.excellent;
      case 'good':
        return EquipmentCondition.good;
      case 'fair':
        return EquipmentCondition.fair;
      case 'poor':
        return EquipmentCondition.poor;
      default:
        return EquipmentCondition.good;
    }
  }
}

/// Equipment checkout record
class EquipmentCheckout {
  final String id;
  final String equipmentId;
  final String checkedOutBy; // User ID
  final String checkedOutByName;
  final DateTime checkedOutAt;
  final DateTime? expectedReturnDate;
  final DateTime? returnedAt;
  final String? returnedBy; // User ID
  final String? returnedByName;
  final String? purpose;
  final String? notes;
  final EquipmentCondition conditionAtCheckout;
  final EquipmentCondition? conditionAtReturn;

  EquipmentCheckout({
    required this.id,
    required this.equipmentId,
    required this.checkedOutBy,
    required this.checkedOutByName,
    required this.checkedOutAt,
    this.expectedReturnDate,
    this.returnedAt,
    this.returnedBy,
    this.returnedByName,
    this.purpose,
    this.notes,
    required this.conditionAtCheckout,
    this.conditionAtReturn,
  });

  bool get isReturned => returnedAt != null;

  factory EquipmentCheckout.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return EquipmentCheckout(
      id: doc.id,
      equipmentId: data['equipmentId'] ?? '',
      checkedOutBy: data['checkedOutBy'] ?? '',
      checkedOutByName: data['checkedOutByName'] ?? '',
      checkedOutAt:
          _parseCheckoutDateTime(data['checkedOutAt']) ?? DateTime.now(),
      expectedReturnDate: _parseCheckoutDateTime(data['expectedReturnDate']),
      returnedAt: _parseCheckoutDateTime(data['returnedAt']),
      returnedBy: data['returnedBy'],
      returnedByName: data['returnedByName'],
      purpose: data['purpose'],
      notes: data['notes'],
      conditionAtCheckout: EquipmentCondition.fromString(
        data['conditionAtCheckout'],
      ),
      conditionAtReturn: data['conditionAtReturn'] != null
          ? EquipmentCondition.fromString(data['conditionAtReturn'])
          : null,
    );
  }

  /// Helper to parse DateTime from Firestore (can be Timestamp, String, or null)
  static DateTime? _parseCheckoutDateTime(dynamic value) {
    if (value == null) return null;
    if (value is firestore.Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'equipmentId': equipmentId,
      'checkedOutBy': checkedOutBy,
      'checkedOutByName': checkedOutByName,
      'checkedOutAt': firestore.Timestamp.fromDate(checkedOutAt),
      'expectedReturnDate': expectedReturnDate != null
          ? firestore.Timestamp.fromDate(expectedReturnDate!)
          : null,
      'returnedAt': returnedAt != null
          ? firestore.Timestamp.fromDate(returnedAt!)
          : null,
      'returnedBy': returnedBy,
      'returnedByName': returnedByName,
      'purpose': purpose,
      'notes': notes,
      'conditionAtCheckout': conditionAtCheckout.name,
      'conditionAtReturn': conditionAtReturn?.name,
    };
  }
}

/// Main Equipment model
class Equipment {
  final String id;
  final String name;
  final String? description;
  final String category; // e.g., Camera, Audio, Lighting, Computer, etc.
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? assetTag; // Internal asset tracking number
  final String? location; // Storage location
  final EquipmentStatus status;
  final EquipmentCondition condition;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final String? supplier;
  final DateTime? warrantyExpiry;
  final String? photoUrl;
  final String? notes;
  final String?
  currentCheckoutId; // Reference to current checkout if checked out
  final String? currentHolderId; // User ID of current holder
  final String? currentHolderName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  Equipment({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.brand,
    this.model,
    this.serialNumber,
    this.assetTag,
    this.location,
    required this.status,
    required this.condition,
    this.purchasePrice,
    this.purchaseDate,
    this.supplier,
    this.warrantyExpiry,
    this.photoUrl,
    this.notes,
    this.currentCheckoutId,
    this.currentHolderId,
    this.currentHolderName,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  bool get isAvailable => status == EquipmentStatus.available;
  bool get isCheckedOut => status == EquipmentStatus.checkedOut;

  factory Equipment.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Equipment(
      id: doc.id,
      name: data['name'] ?? '',
      description: _parseString(data['description']),
      category: data['category'] ?? 'Other',
      brand: _parseString(data['brand']),
      model: _parseString(data['model']),
      serialNumber: _parseString(data['serialNumber']),
      assetTag: _parseString(data['assetTag']),
      location: _parseString(data['location']),
      status: EquipmentStatus.fromString(data['status']),
      condition: EquipmentCondition.fromString(data['condition']),
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble(),
      purchaseDate: _parseDateTime(data['purchaseDate']),
      supplier: _parseString(data['supplier']),
      warrantyExpiry: _parseDateTime(data['warrantyExpiry']),
      photoUrl: _parseString(data['photoUrl']),
      notes: _parseString(data['notes']),
      currentCheckoutId: _parseString(data['currentCheckoutId']),
      currentHolderId: _parseString(data['currentHolderId']),
      currentHolderName: _parseString(data['currentHolderName']),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']),
      createdBy: _parseString(data['createdBy']),
    );
  }

  /// Helper to parse DateTime from Firestore (can be Timestamp, String, or null)
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is firestore.Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Helper to safely convert any value to String (handles int, double, etc.)
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'brand': brand,
      'model': model,
      'serialNumber': serialNumber,
      'assetTag': assetTag,
      'location': location,
      'status': status.name,
      'condition': condition.name,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate != null
          ? firestore.Timestamp.fromDate(purchaseDate!)
          : null,
      'supplier': supplier,
      'warrantyExpiry': warrantyExpiry != null
          ? firestore.Timestamp.fromDate(warrantyExpiry!)
          : null,
      'photoUrl': photoUrl,
      'notes': notes,
      'currentCheckoutId': currentCheckoutId,
      'currentHolderId': currentHolderId,
      'currentHolderName': currentHolderName,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : firestore.FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  Equipment copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? brand,
    String? model,
    String? serialNumber,
    String? assetTag,
    String? location,
    EquipmentStatus? status,
    EquipmentCondition? condition,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? supplier,
    DateTime? warrantyExpiry,
    String? photoUrl,
    String? notes,
    String? currentCheckoutId,
    String? currentHolderId,
    String? currentHolderName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Equipment(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      assetTag: assetTag ?? this.assetTag,
      location: location ?? this.location,
      status: status ?? this.status,
      condition: condition ?? this.condition,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplier: supplier ?? this.supplier,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      currentCheckoutId: currentCheckoutId ?? this.currentCheckoutId,
      currentHolderId: currentHolderId ?? this.currentHolderId,
      currentHolderName: currentHolderName ?? this.currentHolderName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Predefined equipment categories for studio
class EquipmentCategories {
  static const List<String> categories = [
    'Camera',
    'Lens',
    'Audio',
    'Lighting',
    'Tripod & Support',
    'Computer',
    'Monitor & Display',
    'Storage & Media',
    'Cables & Accessories',
    'Grip Equipment',
    'Power & Battery',
    'Teleprompter',
    'Streaming Equipment',
    'Furniture',
    'Other',
  ];
}
