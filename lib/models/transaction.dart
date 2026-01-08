import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';
import 'approval_record.dart';

class Transaction {
  final String id;
  final String reportId;
  final String? projectId; // Optional project ID for linking to Project/Production reports
  final DateTime date;
  final String receiptNo;
  final String description;
  final String category; // Store as string: 'office', 'travel', etc.
  final double amount;
  final String paymentMethod; // Store as string: 'cash', 'card', etc.
  final String requestorId;
  final String? approverId;
  final String status; // Store as string: 'draft', 'pendingApproval', etc.
  final String? paidTo;
  final List<String> attachmentUrls; // Firebase Storage URLs
  final List<Map<String, dynamic>> approvalHistory;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Transaction({
    required this.id,
    required this.reportId,
    this.projectId,
    required this.date,
    required this.receiptNo,
    required this.description,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.requestorId,
    this.approverId,
    required this.status,
    this.paidTo,
    List<String>? attachmentUrls,
    List<Map<String, dynamic>>? approvalHistory,
    required this.createdAt,
    this.updatedAt,
  })  : attachmentUrls = attachmentUrls ?? [],
        approvalHistory = approvalHistory ?? [];

  // Get enum values from strings
  ExpenseCategory get categoryEnum => ExpenseCategory.values.firstWhere(
        (e) => e.name == category,
        orElse: () => ExpenseCategory.other,
      );

  PaymentMethod get paymentMethodEnum => PaymentMethod.values.firstWhere(
        (e) => e.name == paymentMethod,
        orElse: () => PaymentMethod.cash,
      );

  TransactionStatus get statusEnum => TransactionStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => TransactionStatus.draft,
      );

  // Get approval records from JSON
  List<ApprovalRecord> get approvalRecords =>
      approvalHistory.map((e) => ApprovalRecord.fromJson(e)).toList();

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportId': reportId,
      'projectId': projectId,
      'date': firestore.Timestamp.fromDate(date),
      'receiptNo': receiptNo,
      'description': description,
      'category': category,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'requestorId': requestorId,
      'approverId': approverId,
      'status': status,
      'paidTo': paidTo,
      'attachmentUrls': attachmentUrls,
      'approvalHistory': approvalHistory.map((record) {
        return {
          'approverId': record['approverId'],
          'approverName': record['approverName'],
          'timestamp': record['timestamp'] is DateTime
              ? firestore.Timestamp.fromDate(record['timestamp'] as DateTime)
              : record['timestamp'] is String
                  ? firestore.Timestamp.fromDate(
                      DateTime.parse(record['timestamp'] as String))
                  : record['timestamp'],
          'action': record['action'],
          'comments': record['comments'],
        };
      }).toList(),
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt':
          updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Transaction.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Transaction(
      id: doc.id,
      reportId: data['reportId'] as String,
      projectId: data['projectId'] as String?,
      date: (data['date'] as firestore.Timestamp).toDate(),
      receiptNo: data['receiptNo'] as String,
      description: data['description'] as String,
      category: data['category'] as String,
      amount: (data['amount'] as num).toDouble(),
      paymentMethod: data['paymentMethod'] as String,
      requestorId: data['requestorId'] as String,
      approverId: data['approverId'] as String?,
      status: data['status'] as String,
      paidTo: data['paidTo'] as String?,
      attachmentUrls:
          (data['attachmentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      approvalHistory: (data['approvalHistory'] as List<dynamic>?)
              ?.map((e) => {
                    'approverId': e['approverId'],
                    'approverName': e['approverName'],
                    'timestamp':
                        (e['timestamp'] as firestore.Timestamp).toDate(),
                    'action': e['action'],
                    'comments': e['comments'],
                  })
              .toList() ??
          [],
      createdAt: (data['createdAt'] as firestore.Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }

  // Keep existing toJson/fromJson for backward compatibility
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportId': reportId,
      'projectId': projectId,
      'date': date.toIso8601String(),
      'receiptNo': receiptNo,
      'description': description,
      'category': category,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'requestorId': requestorId,
      'approverId': approverId,
      'status': status,
      'attachmentUrls': attachmentUrls,
      'approvalHistory': approvalHistory,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'paidTo': paidTo,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      reportId: json['reportId'] as String,
      projectId: json['projectId'] as String?,
      date: DateTime.parse(json['date'] as String),
      receiptNo: json['receiptNo'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      requestorId: json['requestorId'] as String,
      approverId: json['approverId'] as String?,
      status: json['status'] as String,
      paidTo: json['paidTo'] as String?,
      attachmentUrls:
          (json['attachmentUrls'] as List?)?.cast<String>() ??
              (json['attachments'] as List?)?.cast<String>() ??
              [],
      approvalHistory:
          (json['approvalHistory'] as List?)?.cast<Map<String, dynamic>>() ??
              [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  // Helper method to create a copy with updates
  Transaction copyWith({
    String? reportId,
    String? projectId,
    DateTime? date,
    String? receiptNo,
    String? description,
    String? category,
    double? amount,
    String? paymentMethod,
    String? approverId,
    String? status,
    String? paidTo,
    List<String>? attachmentUrls,
    List<Map<String, dynamic>>? approvalHistory,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id,
      reportId: reportId ?? this.reportId,
      projectId: projectId ?? this.projectId,
      date: date ?? this.date,
      receiptNo: receiptNo ?? this.receiptNo,
      description: description ?? this.description,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      requestorId: requestorId,
      approverId: approverId ?? this.approverId,
      status: status ?? this.status,
      paidTo: paidTo ?? this.paidTo,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
