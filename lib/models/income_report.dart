import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

/// Income categories for Hope Channel
enum IncomeCategory {
  donations,
  tithesOfferings,
  sponsorships,
  advertising,
  programSales,
  merchandise,
  grants,
  events,
  subscriptions,
  interestIncome,
  rentalIncome,
  other,
}

extension IncomeCategoryExtension on IncomeCategory {
  String get displayName {
    switch (this) {
      case IncomeCategory.donations:
        return 'Donations';
      case IncomeCategory.tithesOfferings:
        return 'Tithes & Offerings';
      case IncomeCategory.sponsorships:
        return 'Sponsorships';
      case IncomeCategory.advertising:
        return 'Advertising';
      case IncomeCategory.programSales:
        return 'Program Sales';
      case IncomeCategory.merchandise:
        return 'Merchandise';
      case IncomeCategory.grants:
        return 'Grants';
      case IncomeCategory.events:
        return 'Events';
      case IncomeCategory.subscriptions:
        return 'Subscriptions';
      case IncomeCategory.interestIncome:
        return 'Interest Income';
      case IncomeCategory.rentalIncome:
        return 'Rental Income';
      case IncomeCategory.other:
        return 'Other';
    }
  }

  String get value => toString().split('.').last;
}

IncomeCategory incomeCategoryFromString(String value) {
  return IncomeCategory.values.firstWhere(
    (e) => e.value == value,
    orElse: () => IncomeCategory.other,
  );
}

/// Payment methods for income
enum PaymentMethod {
  cash,
  bankTransfer,
  check,
  online,
  creditCard,
  other,
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.check:
        return 'Check';
      case PaymentMethod.online:
        return 'Online Payment';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  String get value => toString().split('.').last;
}

PaymentMethod paymentMethodFromString(String value) {
  return PaymentMethod.values.firstWhere(
    (e) => e.value == value,
    orElse: () => PaymentMethod.other,
  );
}

/// Individual income entry within a report
class IncomeEntry {
  final String id;
  final String reportId;
  final DateTime dateReceived;
  final String category; // IncomeCategory name
  final String sourceName;
  final String description;
  final double amount;
  final String paymentMethod; // PaymentMethod name
  final String? referenceNumber;
  final List<String> supportDocumentUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  IncomeEntry({
    required this.id,
    required this.reportId,
    required this.dateReceived,
    required this.category,
    required this.sourceName,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    List<String>? supportDocumentUrls,
    required this.createdAt,
    this.updatedAt,
  }) : supportDocumentUrls = supportDocumentUrls ?? [];

  IncomeCategory get categoryEnum => incomeCategoryFromString(category);
  PaymentMethod get paymentMethodEnum => paymentMethodFromString(paymentMethod);

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportId': reportId,
      'dateReceived': Timestamp.fromDate(dateReceived),
      'category': category,
      'sourceName': sourceName,
      'description': description,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'referenceNumber': referenceNumber,
      'supportDocumentUrls': supportDocumentUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory IncomeEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return IncomeEntry(
      id: doc.id,
      reportId: data['reportId'] as String,
      dateReceived: (data['dateReceived'] as Timestamp).toDate(),
      category: data['category'] as String,
      sourceName: data['sourceName'] as String,
      description: data['description'] as String,
      amount: (data['amount'] as num).toDouble(),
      paymentMethod: data['paymentMethod'] as String,
      referenceNumber: data['referenceNumber'] as String?,
      supportDocumentUrls: List<String>.from(data['supportDocumentUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  IncomeEntry copyWith({
    String? reportId,
    DateTime? dateReceived,
    String? category,
    String? sourceName,
    String? description,
    double? amount,
    String? paymentMethod,
    String? referenceNumber,
    List<String>? supportDocumentUrls,
    DateTime? updatedAt,
  }) {
    return IncomeEntry(
      id: id,
      reportId: reportId ?? this.reportId,
      dateReceived: dateReceived ?? this.dateReceived,
      category: category ?? this.category,
      sourceName: sourceName ?? this.sourceName,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Income Report containing multiple income entries
class IncomeReport {
  final String id;
  final String reportNumber; // Format: IR-YYYYMMDD-XXX
  final String reportName;
  final String department;
  final String createdById;
  final String createdByName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalIncome;
  final String status; // 'draft', 'submitted', 'underReview', 'approved', 'closed'
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  IncomeReport({
    required this.id,
    required this.reportNumber,
    required this.reportName,
    required this.department,
    required this.createdById,
    required this.createdByName,
    required this.periodStart,
    required this.periodEnd,
    this.totalIncome = 0,
    required this.status,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.approvedAt,
    this.approvedBy,
  });

  ReportStatus get statusEnum => ReportStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => ReportStatus.draft,
      );

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportNumber': reportNumber,
      'reportName': reportName,
      'department': department,
      'createdById': createdById,
      'createdByName': createdByName,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'totalIncome': totalIncome,
      'status': status,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
    };
  }

  factory IncomeReport.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return IncomeReport(
      id: doc.id,
      reportNumber: data['reportNumber'] as String,
      reportName: data['reportName'] as String,
      department: data['department'] as String,
      createdById: data['createdById'] as String,
      createdByName: data['createdByName'] as String,
      periodStart: (data['periodStart'] as Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as Timestamp).toDate(),
      totalIncome: (data['totalIncome'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String,
      description: data['description'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'] as String?,
    );
  }

  IncomeReport copyWith({
    String? reportNumber,
    String? reportName,
    String? department,
    String? createdById,
    String? createdByName,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? totalIncome,
    String? status,
    String? description,
    DateTime? updatedAt,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? approvedBy,
  }) {
    return IncomeReport(
      id: id,
      reportNumber: reportNumber ?? this.reportNumber,
      reportName: reportName ?? this.reportName,
      department: department ?? this.department,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      totalIncome: totalIncome ?? this.totalIncome,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
    );
  }

  /// Calculate total from entries
  IncomeReport calculateTotal(List<IncomeEntry> entries) {
    final total = entries.fold<double>(0, (acc, entry) => acc + entry.amount);
    return copyWith(
      totalIncome: total,
      updatedAt: DateTime.now(),
    );
  }
}
