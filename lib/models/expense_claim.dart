import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class ExpenseClaim {
  final String id;
  final String claimNumber; // Format: EXP-YYYYMMDD-XXXXXX

  // Header
  final String title;
  final String purpose;
  final String requesterId;
  final String requesterName;
  final String department;

  // Line items
  final List<ExpenseLineItem> items;

  // Computed total (sum of items)
  double get totalAmount =>
      items.fold(0.0, (acc, item) => acc + item.amount);

  // Status workflow: pending → approved / rejected
  final String status;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Approval tracking
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approverName;
  final String? rejectionReason;

  final String? notes;

  ExpenseClaim({
    required this.id,
    required this.claimNumber,
    required this.title,
    required this.purpose,
    required this.requesterId,
    required this.requesterName,
    required this.department,
    List<ExpenseLineItem>? items,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedBy,
    this.approverName,
    this.rejectionReason,
    this.notes,
  }) : items = items ?? [];

  ExpenseClaimStatus get statusEnum => status.toExpenseClaimStatus();

  bool get canApprove => status == ExpenseClaimStatus.pending.name;
  bool get canDelete => status == ExpenseClaimStatus.pending.name;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'claimNumber': claimNumber,
      'title': title,
      'purpose': purpose,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'department': department,
      'items': items.map((i) => i.toMap()).toList(),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'approverName': approverName,
      'rejectionReason': rejectionReason,
      'notes': notes,
    };
  }

  factory ExpenseClaim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTs(dynamic v, DateTime fallback) {
      if (v is Timestamp) return v.toDate();
      return fallback;
    }

    DateTime? parseTsOpt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final now = DateTime.now();

    return ExpenseClaim(
      id: data['id'] ?? doc.id,
      claimNumber: data['claimNumber'] ?? '',
      title: data['title'] ?? '',
      purpose: data['purpose'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      department: data['department'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => ExpenseLineItem.fromMap(e))
              .toList() ??
          [],
      status: data['status'] ?? 'pending',
      createdAt: parseTs(data['createdAt'], now),
      updatedAt: parseTsOpt(data['updatedAt']),
      approvedAt: parseTsOpt(data['approvedAt']),
      approvedBy: data['approvedBy'],
      approverName: data['approverName'],
      rejectionReason: data['rejectionReason'],
      notes: data['notes'],
    );
  }

  ExpenseClaim copyWith({
    String? id,
    String? claimNumber,
    String? title,
    String? purpose,
    String? requesterId,
    String? requesterName,
    String? department,
    List<ExpenseLineItem>? items,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? approverName,
    String? rejectionReason,
    String? notes,
  }) {
    return ExpenseClaim(
      id: id ?? this.id,
      claimNumber: claimNumber ?? this.claimNumber,
      title: title ?? this.title,
      purpose: purpose ?? this.purpose,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      department: department ?? this.department,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approverName: approverName ?? this.approverName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      notes: notes ?? this.notes,
    );
  }
}

class ExpenseLineItem {
  final DateTime date;
  final String category; // ExpenseLineCategory.name or custom string
  final String description;
  final String? receiptRef;
  final double amount;
  final List<String> supportDocumentUrls;

  ExpenseLineItem({
    required this.date,
    required this.category,
    required this.description,
    this.receiptRef,
    required this.amount,
    List<String>? supportDocumentUrls,
  }) : supportDocumentUrls = supportDocumentUrls ?? [];

  ExpenseLineCategory get categoryEnum => category.toExpenseLineCategory();

  String get categoryDisplayName {
    // Try known enum first; if it matches 'other' but the stored value is
    // a custom string, show that string instead.
    final known = ExpenseLineCategory.values.firstWhere(
      (e) => e.name == category,
      orElse: () => ExpenseLineCategory.other,
    );
    if (known != ExpenseLineCategory.other) return known.displayName;
    if (category != ExpenseLineCategory.other.name) return category;
    return known.displayName;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'category': category,
      'description': description,
      'receiptRef': receiptRef,
      'amount': amount,
      'supportDocumentUrls': supportDocumentUrls,
    };
  }

  factory ExpenseLineItem.fromMap(dynamic raw) {
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final dateRaw = data['date'];
    final date = dateRaw is Timestamp ? dateRaw.toDate() : DateTime.now();
    return ExpenseLineItem(
      date: date,
      category: data['category'] ?? 'other',
      description: data['description'] ?? '',
      receiptRef: data['receiptRef'],
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      supportDocumentUrls:
          (data['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
