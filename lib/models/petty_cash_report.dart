import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';
import 'transaction.dart';

class PettyCashReport {
  final String id;
  final String reportNumber;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String department;
  final String custodianId;
  final String custodianName;
  final double openingBalance;
  final double closingBalance;
  final double totalDisbursements;
  final double cashOnHand;
  final double variance;
  final String status; // Store as string: 'draft', 'submitted', 'underReview', 'approved', 'closed'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? companyName;
  final String? notes;

  PettyCashReport({
    required this.id,
    required this.reportNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.department,
    required this.custodianId,
    required this.custodianName,
    required this.openingBalance,
    this.closingBalance = 0,
    this.totalDisbursements = 0,
    this.cashOnHand = 0,
    this.variance = 0,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.companyName,
    this.notes,
  });

  // Get ReportStatus enum from string
  ReportStatus get statusEnum => ReportStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => ReportStatus.draft,
      );

  // Calculate totals based on approved transactions
  PettyCashReport calculateTotals(List<Transaction> transactions) {
    final approvedTransactions = transactions.where((t) =>
        t.status == TransactionStatus.approved.name ||
        t.status == TransactionStatus.processed.name);

    final totalDisb = approvedTransactions.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    final cash = openingBalance - totalDisb;
    final closing = cash;
    final var$ = closing - openingBalance + totalDisb;

    return copyWith(
      totalDisbursements: totalDisb,
      cashOnHand: cash,
      closingBalance: closing,
      variance: var$,
      updatedAt: DateTime.now(),
    );
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportNumber': reportNumber,
      'periodStart': firestore.Timestamp.fromDate(periodStart),
      'periodEnd': firestore.Timestamp.fromDate(periodEnd),
      'department': department,
      'custodianId': custodianId,
      'custodianName': custodianName,
      'openingBalance': openingBalance,
      'closingBalance': closingBalance,
      'totalDisbursements': totalDisbursements,
      'cashOnHand': cashOnHand,
      'variance': variance,
      'status': status,
      'companyName': companyName,
      'notes': notes,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory PettyCashReport.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PettyCashReport(
      id: doc.id,
      reportNumber: data['reportNumber'] as String,
      periodStart: (data['periodStart'] as firestore.Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as firestore.Timestamp).toDate(),
      department: data['department'] as String,
      custodianId: data['custodianId'] as String,
      custodianName: data['custodianName'] as String,
      openingBalance: (data['openingBalance'] as num).toDouble(),
      closingBalance: (data['closingBalance'] as num).toDouble(),
      totalDisbursements: (data['totalDisbursements'] as num).toDouble(),
      cashOnHand: (data['cashOnHand'] as num).toDouble(),
      variance: (data['variance'] as num).toDouble(),
      status: data['status'] as String,
      companyName: data['companyName'] as String?,
      notes: data['notes'] as String?,
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
      'reportNumber': reportNumber,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'department': department,
      'custodianId': custodianId,
      'custodianName': custodianName,
      'openingBalance': openingBalance,
      'closingBalance': closingBalance,
      'totalDisbursements': totalDisbursements,
      'cashOnHand': cashOnHand,
      'variance': variance,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'companyName': companyName,
      'notes': notes,
    };
  }

  factory PettyCashReport.fromJson(Map<String, dynamic> json) {
    return PettyCashReport(
      id: json['id'] as String,
      reportNumber: json['reportNumber'] as String,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      department: json['department'] as String,
      custodianId: json['custodianId'] as String,
      custodianName: json['custodianName'] as String,
      openingBalance: (json['openingBalance'] as num).toDouble(),
      closingBalance: (json['closingBalance'] as num?)?.toDouble() ?? 0,
      totalDisbursements:
          (json['totalDisbursements'] as num?)?.toDouble() ?? 0,
      cashOnHand: (json['cashOnHand'] as num?)?.toDouble() ?? 0,
      variance: (json['variance'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      companyName: json['companyName'] as String?,
      notes: json['notes'] as String?,
    );
  }

  // Helper method to create a copy with updates
  PettyCashReport copyWith({
    String? reportNumber,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? department,
    String? custodianId,
    String? custodianName,
    double? openingBalance,
    double? closingBalance,
    double? totalDisbursements,
    double? cashOnHand,
    double? variance,
    String? status,
    DateTime? updatedAt,
    String? companyName,
    String? notes,
  }) {
    return PettyCashReport(
      id: id,
      reportNumber: reportNumber ?? this.reportNumber,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      department: department ?? this.department,
      custodianId: custodianId ?? this.custodianId,
      custodianName: custodianName ?? this.custodianName,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalance: closingBalance ?? this.closingBalance,
      totalDisbursements: totalDisbursements ?? this.totalDisbursements,
      cashOnHand: cashOnHand ?? this.cashOnHand,
      variance: variance ?? this.variance,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      companyName: companyName ?? this.companyName,
      notes: notes ?? this.notes,
    );
  }
}
