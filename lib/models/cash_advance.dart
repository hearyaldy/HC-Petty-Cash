import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class CashAdvance {
  final String id;
  final String requestNumber; // Format: CA-YYYYMMDD-XXXXXX

  // Itemized Details (optional)
  final List<CashAdvanceItem> items;

  // Request Details
  final String purpose;
  final double requestedAmount;
  final DateTime requestDate;
  final DateTime? requiredByDate;

  // Requester Info
  final String requesterId;
  final String requesterName;
  final String department;
  final String? idNo;

  // Status Workflow
  final String status; // draft, submitted, approved, disbursed, settled, rejected, cancelled

  // Approval Tracking
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final String? submittedBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final String? actionNo; // Required for amounts > 20,000 Baht

  // Disbursement Tracking
  final DateTime? disbursedAt;
  final String? disbursedBy;
  final double? disbursedAmount;
  final String? paymentMethod; // cash, bankTransfer, card, other
  final String? referenceNumber;

  // Settlement Connection
  final String? settlementId; // Links to PettyCashReport (reportType='advance_settlement')
  final DateTime? settledAt;
  final double? settledAmount;
  final double? returnedAmount;

  // Supporting Documents
  final List<String> supportDocumentUrls;
  final String? notes;
  final String? companyName;

  CashAdvance({
    required this.id,
    required this.requestNumber,
    List<CashAdvanceItem>? items,
    required this.purpose,
    required this.requestedAmount,
    required this.requestDate,
    this.requiredByDate,
    required this.requesterId,
    required this.requesterName,
    required this.department,
    this.idNo,
    this.status = 'draft',
    required this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.submittedBy,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.actionNo,
    this.disbursedAt,
    this.disbursedBy,
    this.disbursedAmount,
    this.paymentMethod,
    this.referenceNumber,
    this.settlementId,
    this.settledAt,
    this.settledAmount,
    this.returnedAmount,
    List<String>? supportDocumentUrls,
    this.notes,
    this.companyName,
  })  : items = items ?? [],
        supportDocumentUrls = supportDocumentUrls ?? [];

  // Get status enum
  CashAdvanceStatus get statusEnum => status.toCashAdvanceStatus();

  // Check if requires action number (amount > 20,000 Baht)
  bool get requiresActionNo => requestedAmount > 20000;

  // Check if pending settlement
  bool get isPendingSettlement =>
      status == CashAdvanceStatus.disbursed.name && settlementId == null;

  // Calculate outstanding amount
  double get outstandingAmount =>
      (disbursedAmount ?? requestedAmount) - (settledAmount ?? 0);

  // Check if can be edited
  bool get canEdit => status == CashAdvanceStatus.draft.name;

  // Check if can be submitted
  bool get canSubmit => status == CashAdvanceStatus.draft.name;

  // Check if can be approved
  bool get canApprove => status == CashAdvanceStatus.submitted.name;

  // Check if can be disbursed
  bool get canDisburse => status == CashAdvanceStatus.approved.name;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'requestNumber': requestNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'purpose': purpose,
      'requestedAmount': requestedAmount,
      'requestDate': Timestamp.fromDate(requestDate),
      'requiredByDate':
          requiredByDate != null ? Timestamp.fromDate(requiredByDate!) : null,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'department': department,
      'idNo': idNo,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'submittedAt':
          submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'submittedBy': submittedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'actionNo': actionNo,
      'disbursedAt':
          disbursedAt != null ? Timestamp.fromDate(disbursedAt!) : null,
      'disbursedBy': disbursedBy,
      'disbursedAmount': disbursedAmount,
      'paymentMethod': paymentMethod,
      'referenceNumber': referenceNumber,
      'settlementId': settlementId,
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
      'settledAmount': settledAmount,
      'returnedAmount': returnedAmount,
      'supportDocumentUrls': supportDocumentUrls,
      'notes': notes,
      'companyName': companyName,
    };
  }

  factory CashAdvance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    DateTime? parseTimestampOptional(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      return null;
    }

    final now = DateTime.now();

    return CashAdvance(
      id: data['id'] ?? doc.id,
      requestNumber: data['requestNumber'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => CashAdvanceItem.fromMap(item))
              .toList() ??
          [],
      purpose: data['purpose'] ?? '',
      requestedAmount: (data['requestedAmount'] ?? 0.0).toDouble(),
      requestDate: parseTimestamp(data['requestDate'], now),
      requiredByDate: parseTimestampOptional(data['requiredByDate']),
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      department: data['department'] ?? '',
      idNo: data['idNo'],
      status: data['status'] ?? 'draft',
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: parseTimestampOptional(data['updatedAt']),
      submittedAt: parseTimestampOptional(data['submittedAt']),
      submittedBy: data['submittedBy'],
      approvedAt: parseTimestampOptional(data['approvedAt']),
      approvedBy: data['approvedBy'],
      rejectionReason: data['rejectionReason'],
      actionNo: data['actionNo'],
      disbursedAt: parseTimestampOptional(data['disbursedAt']),
      disbursedBy: data['disbursedBy'],
      disbursedAmount: (data['disbursedAmount'] as num?)?.toDouble(),
      paymentMethod: data['paymentMethod'],
      referenceNumber: data['referenceNumber'],
      settlementId: data['settlementId'],
      settledAt: parseTimestampOptional(data['settledAt']),
      settledAmount: (data['settledAmount'] as num?)?.toDouble(),
      returnedAmount: (data['returnedAmount'] as num?)?.toDouble(),
      supportDocumentUrls:
          (data['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      notes: data['notes'],
      companyName: data['companyName'],
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory CashAdvance.fromJson(Map<String, dynamic> json) {
    return CashAdvance(
      id: json['id'] ?? '',
      requestNumber: json['requestNumber'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CashAdvanceItem.fromMap(item))
              .toList() ??
          [],
      purpose: json['purpose'] ?? '',
      requestedAmount: (json['requestedAmount'] ?? 0.0).toDouble(),
      requestDate: json['requestDate'] is Timestamp
          ? (json['requestDate'] as Timestamp).toDate()
          : DateTime.parse(
              json['requestDate'] ?? DateTime.now().toIso8601String()),
      requiredByDate: json['requiredByDate'] != null
          ? (json['requiredByDate'] is Timestamp
              ? (json['requiredByDate'] as Timestamp).toDate()
              : DateTime.parse(json['requiredByDate']))
          : null,
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      department: json['department'] ?? '',
      idNo: json['idNo'],
      status: json['status'] ?? 'draft',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(json['updatedAt']))
          : null,
      submittedAt: json['submittedAt'] != null
          ? (json['submittedAt'] is Timestamp
              ? (json['submittedAt'] as Timestamp).toDate()
              : DateTime.parse(json['submittedAt']))
          : null,
      submittedBy: json['submittedBy'],
      approvedAt: json['approvedAt'] != null
          ? (json['approvedAt'] is Timestamp
              ? (json['approvedAt'] as Timestamp).toDate()
              : DateTime.parse(json['approvedAt']))
          : null,
      approvedBy: json['approvedBy'],
      rejectionReason: json['rejectionReason'],
      actionNo: json['actionNo'],
      disbursedAt: json['disbursedAt'] != null
          ? (json['disbursedAt'] is Timestamp
              ? (json['disbursedAt'] as Timestamp).toDate()
              : DateTime.parse(json['disbursedAt']))
          : null,
      disbursedBy: json['disbursedBy'],
      disbursedAmount: (json['disbursedAmount'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod'],
      referenceNumber: json['referenceNumber'],
      settlementId: json['settlementId'],
      settledAt: json['settledAt'] != null
          ? (json['settledAt'] is Timestamp
              ? (json['settledAt'] as Timestamp).toDate()
              : DateTime.parse(json['settledAt']))
          : null,
      settledAmount: (json['settledAmount'] as num?)?.toDouble(),
      returnedAmount: (json['returnedAmount'] as num?)?.toDouble(),
      supportDocumentUrls:
          (json['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      notes: json['notes'],
      companyName: json['companyName'],
    );
  }

  CashAdvance copyWith({
    String? id,
    String? requestNumber,
    List<CashAdvanceItem>? items,
    String? purpose,
    double? requestedAmount,
    DateTime? requestDate,
    DateTime? requiredByDate,
    String? requesterId,
    String? requesterName,
    String? department,
    String? idNo,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
    String? submittedBy,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
    String? actionNo,
    DateTime? disbursedAt,
    String? disbursedBy,
    double? disbursedAmount,
    String? paymentMethod,
    String? referenceNumber,
    String? settlementId,
    DateTime? settledAt,
    double? settledAmount,
    double? returnedAmount,
    List<String>? supportDocumentUrls,
    String? notes,
    String? companyName,
  }) {
    return CashAdvance(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      items: items ?? this.items,
      purpose: purpose ?? this.purpose,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      requestDate: requestDate ?? this.requestDate,
      requiredByDate: requiredByDate ?? this.requiredByDate,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      department: department ?? this.department,
      idNo: idNo ?? this.idNo,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      actionNo: actionNo ?? this.actionNo,
      disbursedAt: disbursedAt ?? this.disbursedAt,
      disbursedBy: disbursedBy ?? this.disbursedBy,
      disbursedAmount: disbursedAmount ?? this.disbursedAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      settlementId: settlementId ?? this.settlementId,
      settledAt: settledAt ?? this.settledAt,
      settledAmount: settledAmount ?? this.settledAmount,
      returnedAmount: returnedAmount ?? this.returnedAmount,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
      notes: notes ?? this.notes,
      companyName: companyName ?? this.companyName,
    );
  }
}

class CashAdvanceItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final String? notes;

  CashAdvanceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.notes,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'notes': notes,
    };
  }

  factory CashAdvanceItem.fromMap(dynamic raw) {
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return CashAdvanceItem(
      name: data['name'] ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'],
    );
  }
}
