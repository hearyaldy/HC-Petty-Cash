import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class AppSettings {
  final String id;
  final String theme; // 'light', 'dark', 'auto'
  final String colorTheme; // 'blue', 'purple', 'green', 'orange', 'red', 'teal'
  final String language; // 'en', 'th'
  final String currency; // 'THB', 'USD', 'EUR'
  final String dateFormat; // 'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'
  final bool emailNotifications;
  final bool pushNotifications;
  final bool autoBackup;
  final String defaultExportFormat; // 'PDF', 'Excel'
  final String defaultReportType; // 'petty_cash', 'project'
  final String organizationName;
  final String organizationNameThai;
  final String organizationAddress;
  final List<String> customVendors;
  final List<String> customStaff;
  final List<String> customStudentWorkers;
  final DateTime? updatedAt;

  AppSettings({
    required this.id,
    this.theme = 'light',
    this.colorTheme = 'blue',
    this.language = 'en',
    this.currency = 'THB',
    this.dateFormat = 'dd/MM/yyyy',
    this.emailNotifications = true,
    this.pushNotifications = false,
    this.autoBackup = true,
    this.defaultExportFormat = 'PDF',
    this.defaultReportType = 'petty_cash',
    this.organizationName = 'Hope Channel Southeast Asia',
    this.organizationNameThai = 'โฮป แชนแนล เอเชียตะวันออกเฉียงใต้',
    this.organizationAddress = '123 Main Street, Bangkok, Thailand',
    List<String>? customVendors,
    List<String>? customStaff,
    List<String>? customStudentWorkers,
    this.updatedAt,
  }) : customVendors =
           customVendors ??
           [
             'Lazada',
             'Shopee',
             'Amazon',
             '7-Eleven',
             'Family Mart',
             'Big C',
             'Tesco Lotus',
             'Makro',
             'Office Mate',
           ],
       customStaff = customStaff ?? [],
       customStudentWorkers = customStudentWorkers ?? [];

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'theme': theme,
      'colorTheme': colorTheme,
      'language': language,
      'currency': currency,
      'dateFormat': dateFormat,
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
      'autoBackup': autoBackup,
      'defaultExportFormat': defaultExportFormat,
      'defaultReportType': defaultReportType,
      'organizationName': organizationName,
      'organizationNameThai': organizationNameThai,
      'organizationAddress': organizationAddress,
      'customVendors': customVendors,
      'customStaff': customStaff,
      'customStudentWorkers': customStudentWorkers,
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : firestore.Timestamp.now(),
    };
  }

  factory AppSettings.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return AppSettings(
      id: doc.id,
      theme: data['theme'] as String? ?? 'light',
      colorTheme: data['colorTheme'] as String? ?? 'blue',
      language: data['language'] as String? ?? 'en',
      currency: data['currency'] as String? ?? 'THB',
      dateFormat: data['dateFormat'] as String? ?? 'dd/MM/yyyy',
      emailNotifications: data['emailNotifications'] as bool? ?? true,
      pushNotifications: data['pushNotifications'] as bool? ?? false,
      autoBackup: data['autoBackup'] as bool? ?? true,
      defaultExportFormat: data['defaultExportFormat'] as String? ?? 'PDF',
      defaultReportType: data['defaultReportType'] as String? ?? 'petty_cash',
      organizationName:
          data['organizationName'] as String? ?? 'Hope Channel Southeast Asia',
      organizationNameThai:
          data['organizationNameThai'] as String? ??
          'โฮป แชนแนล เอเชียตะวันออกเฉียงใต้',
      organizationAddress:
          data['organizationAddress'] as String? ??
          '123 Main Street, Bangkok, Thailand',
      customVendors:
          (data['customVendors'] as List<dynamic>?)?.cast<String>() ??
          [
            'Lazada',
            'Shopee',
            'Amazon',
            '7-Eleven',
            'Family Mart',
            'Big C',
            'Tesco Lotus',
            'Makro',
            'Office Mate',
          ],
      customStaff:
          (data['customStaff'] as List<dynamic>?)?.cast<String>() ?? [],
      customStudentWorkers:
          (data['customStudentWorkers'] as List<dynamic>?)?.cast<String>() ??
          [],
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }

  AppSettings copyWith({
    String? theme,
    String? colorTheme,
    String? language,
    String? currency,
    String? dateFormat,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? autoBackup,
    String? defaultExportFormat,
    String? defaultReportType,
    String? organizationName,
    String? organizationNameThai,
    String? organizationAddress,
    List<String>? customVendors,
    List<String>? customStaff,
    List<String>? customStudentWorkers,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id,
      theme: theme ?? this.theme,
      colorTheme: colorTheme ?? this.colorTheme,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      autoBackup: autoBackup ?? this.autoBackup,
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      defaultReportType: defaultReportType ?? this.defaultReportType,
      organizationName: organizationName ?? this.organizationName,
      organizationNameThai: organizationNameThai ?? this.organizationNameThai,
      organizationAddress: organizationAddress ?? this.organizationAddress,
      customVendors: customVendors ?? this.customVendors,
      customStaff: customStaff ?? this.customStaff,
      customStudentWorkers: customStudentWorkers ?? this.customStudentWorkers,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CustomCategory {
  final String id;
  final String name;
  final String description;
  final String iconCodePoint;
  final bool enabled;
  final DateTime createdAt;

  CustomCategory({
    required this.id,
    required this.name,
    this.description = '',
    required this.iconCodePoint,
    this.enabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'enabled': enabled,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
    };
  }

  factory CustomCategory.fromMap(Map<String, dynamic> map) {
    return CustomCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      iconCodePoint: map['iconCodePoint'] as String,
      enabled: map['enabled'] as bool? ?? true,
      createdAt: (map['createdAt'] as firestore.Timestamp).toDate(),
    );
  }

  CustomCategory copyWith({
    String? name,
    String? description,
    String? iconCodePoint,
    bool? enabled,
  }) {
    return CustomCategory(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }
}
