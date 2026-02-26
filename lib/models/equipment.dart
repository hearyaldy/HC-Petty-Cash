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
  final String name; // Asset Name
  final String? description;
  final String category; // e.g., Camera, Audio, Lighting, Computer, etc.
  final String? brand;
  final String? model;
  final String? serialNumber; // Asset Details/Serial Number
  final String? assetTag; // Internal asset tracking number (legacy)
  final String? assetCode; // Asset Code (e.g., ASSET-001)
  final String? accountingPeriod; // Accounting period (e.g., "2024/001")
  final String? location; // Storage location
  final EquipmentStatus status;
  final EquipmentCondition condition;
  final double? purchasePrice; // Total purchase price
  final DateTime? purchaseDate;
  final int? purchaseYear; // Year of purchase
  final String? supplier;
  final DateTime? warrantyExpiry;
  final String? photoUrl; // Image/Photo of Product
  final String? notes;
  // Organization
  final String? organizationId; // Organization ID for inventory separation
  final String? organizationName; // Organization name for display
  // Assignment (permanent, different from checkout)
  final String? assignedToId; // User ID of assigned person
  final String? assignedToName; // Name of assigned person
  // Checkout tracking
  final String? currentCheckoutId; // Reference to current checkout if checked out
  final String? currentHolderId; // User ID of current holder
  final String? currentHolderName;
  // Depreciation fields
  final int quantity; // Quantity (default 1)
  final double? unitCost; // Cost per unit
  final double? depreciationPercentage; // Annual depreciation rate (e.g., 20 for 20%)
  final int? monthsDepreciated; // Number of months depreciation has been applied
  // Timestamps
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
    this.assetCode,
    this.accountingPeriod,
    this.location,
    required this.status,
    required this.condition,
    this.purchasePrice,
    this.purchaseDate,
    this.purchaseYear,
    this.supplier,
    this.warrantyExpiry,
    this.photoUrl,
    this.notes,
    this.organizationId,
    this.organizationName,
    this.assignedToId,
    this.assignedToName,
    this.currentCheckoutId,
    this.currentHolderId,
    this.currentHolderName,
    this.quantity = 1,
    this.unitCost,
    this.depreciationPercentage,
    this.monthsDepreciated,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  bool get isAvailable => status == EquipmentStatus.available;
  bool get isCheckedOut => status == EquipmentStatus.checkedOut;

  /// Calculate asset age in years from purchase date or purchase year
  int? get assetAgeYears {
    if (purchaseDate != null) {
      return DateTime.now().difference(purchaseDate!).inDays ~/ 365;
    }
    if (purchaseYear != null) {
      return DateTime.now().year - purchaseYear!;
    }
    return null;
  }

  /// Calculate asset age in months from purchase date
  int? get assetAgeMonths {
    if (purchaseDate != null) {
      final now = DateTime.now();
      return (now.year - purchaseDate!.year) * 12 +
          (now.month - purchaseDate!.month);
    }
    return null;
  }

  /// Calculate monthly depreciation amount
  double? get monthlyDepreciation {
    if (purchasePrice != null && depreciationPercentage != null) {
      return (purchasePrice! * depreciationPercentage! / 100) / 12;
    }
    return null;
  }

  /// Calculate total depreciation to date
  double? get totalDepreciation {
    final monthly = monthlyDepreciation;
    final months = monthsDepreciated ?? assetAgeMonths;
    if (monthly != null && months != null) {
      return monthly * months;
    }
    return null;
  }

  /// Calculate current book value after depreciation
  double? get currentBookValue {
    if (purchasePrice != null) {
      final depreciation = totalDepreciation ?? 0;
      final value = purchasePrice! - depreciation;
      return value > 0 ? value : 0;
    }
    return null;
  }

  /// Get the effective unit cost (stored or calculated)
  double? get effectiveUnitCost {
    if (unitCost != null) return unitCost;
    if (purchasePrice != null && quantity > 0) {
      return purchasePrice! / quantity;
    }
    return null;
  }

  /// Auto-generated sticker tag: AssetCode-LOCATION-YYYY
  String? get itemStickerTag => buildStickerTag(
        assetCode: assetCode,
        location: location,
        purchaseDate: purchaseDate,
        purchaseYear: purchaseYear,
      );

  static String? buildStickerTag({
    String? assetCode,
    String? location,
    DateTime? purchaseDate,
    int? purchaseYear,
  }) {
    final code = assetCode?.trim();
    final loc = location?.trim();
    final year = purchaseDate?.year ?? purchaseYear;

    if (code == null || code.isEmpty) return null;
    if (loc == null || loc.isEmpty) return null;
    if (year == null) return null;

    final normalizedLocation = _abbreviateLocation(loc);
    return '$code-$normalizedLocation-$year';
  }

  static String _abbreviateLocation(String location) {
    final firstWordMatch = RegExp(r'[A-Za-z]+').firstMatch(location);
    final numberMatches = RegExp(r'\d+').allMatches(location);

    final firstWord = firstWordMatch?.group(0);
    if (firstWord == null || firstWord.isEmpty) {
      return location.toUpperCase();
    }

    final prefix = firstWord.substring(0, firstWord.length < 3 ? firstWord.length : 3).toUpperCase();
    final numberSuffix = numberMatches.isNotEmpty
        ? numberMatches.last.group(0)
        : null;

    if (numberSuffix != null && numberSuffix.isNotEmpty) {
      return '$prefix-$numberSuffix';
    }
    return prefix;
  }

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
      assetCode: _parseString(data['assetCode']),
      accountingPeriod: _parseString(data['accountingPeriod']),
      location: _parseString(data['location']),
      status: EquipmentStatus.fromString(data['status']),
      condition: EquipmentCondition.fromString(data['condition']),
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble(),
      purchaseDate: _parseDateTime(data['purchaseDate']),
      purchaseYear: (data['purchaseYear'] as num?)?.toInt(),
      supplier: _parseString(data['supplier']),
      warrantyExpiry: _parseDateTime(data['warrantyExpiry']),
      photoUrl: _parseString(data['photoUrl']),
      notes: _parseString(data['notes']),
      organizationId: _parseString(data['organizationId']),
      organizationName: _parseString(data['organizationName']),
      assignedToId: _parseString(data['assignedToId']),
      assignedToName: _parseString(data['assignedToName']),
      currentCheckoutId: _parseString(data['currentCheckoutId']),
      currentHolderId: _parseString(data['currentHolderId']),
      currentHolderName: _parseString(data['currentHolderName']),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitCost: (data['unitCost'] as num?)?.toDouble(),
      depreciationPercentage:
          (data['depreciationPercentage'] as num?)?.toDouble(),
      monthsDepreciated: (data['monthsDepreciated'] as num?)?.toInt(),
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
      'assetCode': assetCode,
      'accountingPeriod': accountingPeriod,
      'location': location,
      'status': status.name,
      'condition': condition.name,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate != null
          ? firestore.Timestamp.fromDate(purchaseDate!)
          : null,
      'purchaseYear': purchaseYear,
      'supplier': supplier,
      'warrantyExpiry': warrantyExpiry != null
          ? firestore.Timestamp.fromDate(warrantyExpiry!)
          : null,
      'photoUrl': photoUrl,
      'notes': notes,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'assignedToId': assignedToId,
      'assignedToName': assignedToName,
      'currentCheckoutId': currentCheckoutId,
      'currentHolderId': currentHolderId,
      'currentHolderName': currentHolderName,
      'quantity': quantity,
      'unitCost': unitCost,
      'depreciationPercentage': depreciationPercentage,
      'monthsDepreciated': monthsDepreciated,
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
    String? assetCode,
    String? accountingPeriod,
    String? location,
    EquipmentStatus? status,
    EquipmentCondition? condition,
    double? purchasePrice,
    DateTime? purchaseDate,
    int? purchaseYear,
    String? supplier,
    DateTime? warrantyExpiry,
    String? photoUrl,
    String? notes,
    String? organizationId,
    String? organizationName,
    String? assignedToId,
    String? assignedToName,
    String? currentCheckoutId,
    String? currentHolderId,
    String? currentHolderName,
    int? quantity,
    double? unitCost,
    double? depreciationPercentage,
    int? monthsDepreciated,
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
      assetCode: assetCode ?? this.assetCode,
      accountingPeriod: accountingPeriod ?? this.accountingPeriod,
      location: location ?? this.location,
      status: status ?? this.status,
      condition: condition ?? this.condition,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseYear: purchaseYear ?? this.purchaseYear,
      supplier: supplier ?? this.supplier,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      currentCheckoutId: currentCheckoutId ?? this.currentCheckoutId,
      currentHolderId: currentHolderId ?? this.currentHolderId,
      currentHolderName: currentHolderName ?? this.currentHolderName,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      depreciationPercentage:
          depreciationPercentage ?? this.depreciationPercentage,
      monthsDepreciated: monthsDepreciated ?? this.monthsDepreciated,
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
