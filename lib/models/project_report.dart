import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';
import 'transaction.dart' as app;

class ProjectReport {
  final String id;
  final String reportNumber;
  final String projectName;
  final String reportName; // Formerly department
  final String custodianId;
  final String custodianName;
  final double budget;
  final double openingBalance;
  final double totalExpenses;
  final double remainingBudget;
  final String status; // Store as string: 'draft', 'submitted', 'underReview', 'approved', 'closed'
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? description;

  ProjectReport({
    required this.id,
    required this.reportNumber,
    required this.projectName,
    required this.reportName,
    required this.custodianId,
    required this.custodianName,
    required this.budget,
    required this.openingBalance,
    this.totalExpenses = 0,
    this.remainingBudget = 0,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.updatedAt,
    this.description,
  });

  // Get ReportStatus enum from string
  ReportStatus get statusEnum => ReportStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => ReportStatus.draft,
      );

  // Calculate totals based on approved transactions
  ProjectReport calculateTotals(List<app.Transaction> transactions) {
    final approvedTransactions = transactions.where((t) =>
        t.status == TransactionStatus.approved.name ||
        t.status == TransactionStatus.processed.name);

    final totalExpenses = approvedTransactions.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    final remaining = budget - totalExpenses;

    return copyWith(
      totalExpenses: totalExpenses,
      remainingBudget: remaining,
      updatedAt: DateTime.now(),
    );
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportNumber': reportNumber,
      'projectName': projectName,
      'reportName': reportName,
      'custodianId': custodianId,
      'custodianName': custodianName,
      'budget': budget,
      'openingBalance': openingBalance,
      'totalExpenses': totalExpenses,
      'remainingBudget': remainingBudget,
      'status': status,
      'startDate': firestore.Timestamp.fromDate(startDate),
      'endDate': firestore.Timestamp.fromDate(endDate),
      'description': description,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory ProjectReport.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProjectReport(
      id: doc.id,
      reportNumber: data['reportNumber'] as String,
      projectName: data['projectName'] as String,
      reportName: data['reportName'] as String,
      custodianId: data['custodianId'] as String,
      custodianName: data['custodianName'] as String,
      budget: (data['budget'] as num).toDouble(),
      openingBalance: (data['openingBalance'] as num).toDouble(),
      totalExpenses: (data['totalExpenses'] as num).toDouble(),
      remainingBudget: (data['remainingBudget'] as num).toDouble(),
      status: data['status'] as String,
      startDate: (data['startDate'] as firestore.Timestamp).toDate(),
      endDate: (data['endDate'] as firestore.Timestamp).toDate(),
      description: data['description'] as String?,
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
      'projectName': projectName,
      'reportName': reportName,
      'custodianId': custodianId,
      'custodianName': custodianName,
      'budget': budget,
      'openingBalance': openingBalance,
      'totalExpenses': totalExpenses,
      'remainingBudget': remainingBudget,
      'status': status,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'description': description,
    };
  }

  factory ProjectReport.fromJson(Map<String, dynamic> json) {
    return ProjectReport(
      id: json['id'] as String,
      reportNumber: json['reportNumber'] as String,
      projectName: json['projectName'] as String,
      reportName: json['reportName'] as String,
      custodianId: json['custodianId'] as String,
      custodianName: json['custodianName'] as String,
      budget: (json['budget'] as num).toDouble(),
      openingBalance: (json['openingBalance'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0,
      remainingBudget: (json['remainingBudget'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  // Helper method to create a copy with updates
  ProjectReport copyWith({
    String? reportNumber,
    String? projectName,
    String? reportName,
    String? custodianId,
    String? custodianName,
    double? budget,
    double? openingBalance,
    double? totalExpenses,
    double? remainingBudget,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedAt,
    String? description,
  }) {
    return ProjectReport(
      id: id,
      reportNumber: reportNumber ?? this.reportNumber,
      projectName: projectName ?? this.projectName,
      reportName: reportName ?? this.reportName,
      custodianId: custodianId ?? this.custodianId,
      custodianName: custodianName ?? this.custodianName,
      budget: budget ?? this.budget,
      openingBalance: openingBalance ?? this.openingBalance,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      remainingBudget: remainingBudget ?? this.remainingBudget,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}