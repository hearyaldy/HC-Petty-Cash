import 'package:hive/hive.dart';
import 'enums.dart';
import 'transaction.dart';

part 'petty_cash_report.g.dart';

@HiveType(typeId: 1)
class PettyCashReport extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String reportNumber;

  @HiveField(2)
  late DateTime periodStart;

  @HiveField(3)
  late DateTime periodEnd;

  @HiveField(4)
  late String department;

  @HiveField(5)
  late String custodianId;

  @HiveField(6)
  late String custodianName;

  @HiveField(7)
  late double openingBalance;

  @HiveField(8)
  late double closingBalance;

  @HiveField(9)
  late double totalDisbursements;

  @HiveField(10)
  late double cashOnHand;

  @HiveField(11)
  late double variance;

  @HiveField(12)
  late String statusIndex;

  @HiveField(13)
  List<String> transactionIds = [];

  @HiveField(14)
  late DateTime createdAt;

  @HiveField(15)
  DateTime? updatedAt;

  @HiveField(16)
  String? companyName;

  @HiveField(17)
  String? notes;

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
    ReportStatus? status,
    List<String>? transactionIds,
    required this.createdAt,
    this.updatedAt,
    this.companyName,
    this.notes,
  }) {
    if (status != null) {
      statusIndex = status.index.toString();
    }
    if (transactionIds != null) {
      this.transactionIds = transactionIds;
    }
  }

  ReportStatus get status => ReportStatus.values[int.parse(statusIndex)];
  set status(ReportStatus value) {
    statusIndex = value.index.toString();
  }

  void calculateTotals(List<Transaction> transactions) {
    totalDisbursements = transactions
        .where((t) => t.status == TransactionStatus.approved ||
            t.status == TransactionStatus.processed)
        .fold(0, (sum, t) => sum + t.amount);

    cashOnHand = openingBalance - totalDisbursements;
    closingBalance = cashOnHand;
    variance = closingBalance - openingBalance + totalDisbursements;
  }

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
      'status': status.name,
      'transactionIds': transactionIds,
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
      status: ReportStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReportStatus.draft,
      ),
      transactionIds: (json['transactionIds'] as List?)?.cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      companyName: json['companyName'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
