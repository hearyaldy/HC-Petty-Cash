import 'package:hive/hive.dart';
import 'enums.dart';
import 'approval_record.dart';

part 'transaction.g.dart';

@HiveType(typeId: 2)
class Transaction extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String reportId;

  @HiveField(2)
  late DateTime date;

  @HiveField(3)
  late String receiptNo;

  @HiveField(4)
  late String description;

  @HiveField(5)
  late String categoryIndex;

  @HiveField(6)
  late double amount;

  @HiveField(7)
  late String paymentMethodIndex;

  @HiveField(8)
  late String requestorId;

  @HiveField(9)
  String? approverId;

  @HiveField(10)
  late String statusIndex;

  @HiveField(11)
  List<String> attachments = [];

  @HiveField(12)
  List<Map<String, dynamic>> approvalHistoryJson = [];

  @HiveField(13)
  late DateTime createdAt;

  @HiveField(14)
  DateTime? updatedAt;

  @HiveField(15)
  String? paidTo;

  Transaction({
    required this.id,
    required this.reportId,
    required this.date,
    required this.receiptNo,
    required this.description,
    ExpenseCategory? category,
    required this.amount,
    PaymentMethod? paymentMethod,
    required this.requestorId,
    this.approverId,
    TransactionStatus? status,
    List<String>? attachments,
    List<ApprovalRecord>? approvalHistory,
    required this.createdAt,
    this.updatedAt,
    this.paidTo,
  }) {
    if (category != null) {
      categoryIndex = category.index.toString();
    }
    if (paymentMethod != null) {
      paymentMethodIndex = paymentMethod.index.toString();
    }
    if (status != null) {
      statusIndex = status.index.toString();
    }
    if (attachments != null) {
      this.attachments = attachments;
    }
    if (approvalHistory != null) {
      approvalHistoryJson = approvalHistory.map((e) => e.toJson()).toList();
    }
  }

  ExpenseCategory get category =>
      ExpenseCategory.values[int.parse(categoryIndex)];
  set category(ExpenseCategory value) {
    categoryIndex = value.index.toString();
  }

  PaymentMethod get paymentMethod =>
      PaymentMethod.values[int.parse(paymentMethodIndex)];
  set paymentMethod(PaymentMethod value) {
    paymentMethodIndex = value.index.toString();
  }

  TransactionStatus get status =>
      TransactionStatus.values[int.parse(statusIndex)];
  set status(TransactionStatus value) {
    statusIndex = value.index.toString();
  }

  List<ApprovalRecord> get approvalHistory =>
      approvalHistoryJson.map((e) => ApprovalRecord.fromJson(e)).toList();
  set approvalHistory(List<ApprovalRecord> value) {
    approvalHistoryJson = value.map((e) => e.toJson()).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportId': reportId,
      'date': date.toIso8601String(),
      'receiptNo': receiptNo,
      'description': description,
      'category': category.name,
      'amount': amount,
      'paymentMethod': paymentMethod.name,
      'requestorId': requestorId,
      'approverId': approverId,
      'status': status.name,
      'attachments': attachments,
      'approvalHistory': approvalHistoryJson,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'paidTo': paidTo,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      reportId: json['reportId'] as String,
      date: DateTime.parse(json['date'] as String),
      receiptNo: json['receiptNo'] as String,
      description: json['description'] as String,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      requestorId: json['requestorId'] as String,
      approverId: json['approverId'] as String?,
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.draft,
      ),
      attachments: (json['attachments'] as List?)?.cast<String>(),
      approvalHistory: (json['approvalHistory'] as List?)
          ?.map((e) => ApprovalRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      paidTo: json['paidTo'] as String?,
    );
  }
}
