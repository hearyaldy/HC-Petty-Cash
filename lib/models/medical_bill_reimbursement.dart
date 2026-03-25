import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class MedicalClaimItem {
  final String id;
  final String description;
  final String claimType; // 'outPatient' or 'inPatient'
  final double totalBill;
  final double amountReimburse; // Calculated: 75% for OP, 90% for IP

  MedicalClaimItem({
    required this.id,
    required this.description,
    required this.claimType,
    required this.totalBill,
    double? amountReimburse,
  }) : amountReimburse = amountReimburse ?? _calculateReimbursement(claimType, totalBill);

  static double _calculateReimbursement(String claimType, double totalBill) {
    final type = claimType.toMedicalClaimType();
    return totalBill * type.reimbursementRate;
  }

  MedicalClaimType get claimTypeEnum => claimType.toMedicalClaimType();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'claimType': claimType,
      'totalBill': totalBill,
      'amountReimburse': amountReimburse,
    };
  }

  factory MedicalClaimItem.fromJson(Map<String, dynamic> json) {
    return MedicalClaimItem(
      id: json['id'] as String,
      description: json['description'] as String,
      claimType: json['claimType'] as String,
      totalBill: (json['totalBill'] as num).toDouble(),
      amountReimburse: (json['amountReimburse'] as num?)?.toDouble(),
    );
  }

  MedicalClaimItem copyWith({
    String? id,
    String? description,
    String? claimType,
    double? totalBill,
    double? amountReimburse,
  }) {
    final newClaimType = claimType ?? this.claimType;
    final newTotalBill = totalBill ?? this.totalBill;
    return MedicalClaimItem(
      id: id ?? this.id,
      description: description ?? this.description,
      claimType: newClaimType,
      totalBill: newTotalBill,
      amountReimburse: amountReimburse ?? _calculateReimbursement(newClaimType, newTotalBill),
    );
  }
}

class MedicalBillReimbursement {
  final String id;
  final String reportNumber; // Format: MBR-YYYYMMDD-XXX
  final String requesterId;
  final String requesterName;
  final String department;
  final DateTime reportDate;
  final String subject;
  final List<MedicalClaimItem> claimItems;
  final double totalBill;
  final double totalReimbursement;

  // Status and approval
  final String status; // 'draft', 'submitted', 'approved', 'rejected', 'closed'
  final DateTime createdAt;
  final DateTime? submittedAt;
  final String? submittedBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approverName;
  final String? rejectionReason;
  final String? notes;
  final String? paidTo;
  final List<String> supportDocumentUrls;
  final DateTime? updatedAt;

  MedicalBillReimbursement({
    required this.id,
    required this.reportNumber,
    required this.requesterId,
    required this.requesterName,
    required this.department,
    required this.reportDate,
    required this.subject,
    List<MedicalClaimItem>? claimItems,
    double? totalBill,
    double? totalReimbursement,
    this.status = 'draft',
    required this.createdAt,
    this.submittedAt,
    this.submittedBy,
    this.approvedAt,
    this.approvedBy,
    this.approverName,
    this.rejectionReason,
    this.notes,
    this.paidTo,
    List<String>? supportDocumentUrls,
    this.updatedAt,
  })  : claimItems = claimItems ?? [],
        supportDocumentUrls = supportDocumentUrls ?? [],
        totalBill = totalBill ?? (claimItems ?? []).fold(0.0, (acc, item) => acc + item.totalBill),
        totalReimbursement = totalReimbursement ?? (claimItems ?? []).fold(0.0, (acc, item) => acc + item.amountReimburse);

  ReportStatus get statusEnum => status.toReportStatus();

  // Calculate totals from claim items
  MedicalBillReimbursement recalculateTotals() {
    final newTotalBill = claimItems.fold(0.0, (acc, item) => acc + item.totalBill);
    final newTotalReimbursement = claimItems.fold(0.0, (acc, item) => acc + item.amountReimburse);
    return copyWith(
      totalBill: newTotalBill,
      totalReimbursement: newTotalReimbursement,
      updatedAt: DateTime.now(),
    );
  }

  // Get totals by claim type
  double getTotalBillByType(MedicalClaimType type) {
    return claimItems
        .where((item) => item.claimTypeEnum == type)
        .fold(0.0, (acc, item) => acc + item.totalBill);
  }

  double getTotalReimbursementByType(MedicalClaimType type) {
    return claimItems
        .where((item) => item.claimTypeEnum == type)
        .fold(0.0, (acc, item) => acc + item.amountReimburse);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportNumber': reportNumber,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'department': department,
      'reportDate': Timestamp.fromDate(reportDate),
      'subject': subject,
      'claimItems': claimItems.map((item) => item.toJson()).toList(),
      'totalBill': totalBill,
      'totalReimbursement': totalReimbursement,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'submittedBy': submittedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'approverName': approverName,
      'rejectionReason': rejectionReason,
      'notes': notes,
      'paidTo': paidTo,
      'supportDocumentUrls': supportDocumentUrls,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MedicalBillReimbursement.fromFirestore(DocumentSnapshot doc) {
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
    final claimItemsList = (data['claimItems'] as List<dynamic>?)
            ?.map((item) => MedicalClaimItem.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    return MedicalBillReimbursement(
      id: data['id'] ?? doc.id,
      reportNumber: data['reportNumber'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      department: data['department'] ?? '',
      reportDate: parseTimestamp(data['reportDate'], now),
      subject: data['subject'] ?? '',
      claimItems: claimItemsList,
      totalBill: (data['totalBill'] as num?)?.toDouble(),
      totalReimbursement: (data['totalReimbursement'] as num?)?.toDouble(),
      status: data['status'] ?? 'draft',
      createdAt: parseTimestamp(data['createdAt'], now),
      submittedAt: parseTimestampOptional(data['submittedAt']),
      submittedBy: data['submittedBy'],
      approvedAt: parseTimestampOptional(data['approvedAt']),
      approvedBy: data['approvedBy'],
      approverName: data['approverName'],
      rejectionReason: data['rejectionReason'],
      notes: data['notes'],
      paidTo: data['paidTo'],
      supportDocumentUrls:
          (data['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      updatedAt: parseTimestampOptional(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory MedicalBillReimbursement.fromJson(Map<String, dynamic> json) {
    final claimItemsList = (json['claimItems'] as List<dynamic>?)
            ?.map((item) => MedicalClaimItem.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    return MedicalBillReimbursement(
      id: json['id'] ?? '',
      reportNumber: json['reportNumber'] ?? '',
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      department: json['department'] ?? '',
      reportDate: json['reportDate'] is Timestamp
          ? (json['reportDate'] as Timestamp).toDate()
          : DateTime.parse(json['reportDate'] ?? DateTime.now().toIso8601String()),
      subject: json['subject'] ?? '',
      claimItems: claimItemsList,
      totalBill: (json['totalBill'] as num?)?.toDouble(),
      totalReimbursement: (json['totalReimbursement'] as num?)?.toDouble(),
      status: json['status'] ?? 'draft',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
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
      approverName: json['approverName'],
      rejectionReason: json['rejectionReason'],
      notes: json['notes'],
      paidTo: json['paidTo'],
      supportDocumentUrls:
          (json['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(json['updatedAt']))
          : null,
    );
  }

  MedicalBillReimbursement copyWith({
    String? id,
    String? reportNumber,
    String? requesterId,
    String? requesterName,
    String? department,
    DateTime? reportDate,
    String? subject,
    List<MedicalClaimItem>? claimItems,
    double? totalBill,
    double? totalReimbursement,
    String? status,
    DateTime? createdAt,
    DateTime? submittedAt,
    String? submittedBy,
    DateTime? approvedAt,
    String? approvedBy,
    String? approverName,
    String? rejectionReason,
    String? notes,
    String? paidTo,
    List<String>? supportDocumentUrls,
    DateTime? updatedAt,
  }) {
    return MedicalBillReimbursement(
      id: id ?? this.id,
      reportNumber: reportNumber ?? this.reportNumber,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      department: department ?? this.department,
      reportDate: reportDate ?? this.reportDate,
      subject: subject ?? this.subject,
      claimItems: claimItems ?? this.claimItems,
      totalBill: totalBill ?? this.totalBill,
      totalReimbursement: totalReimbursement ?? this.totalReimbursement,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approverName: approverName ?? this.approverName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      notes: notes ?? this.notes,
      paidTo: paidTo ?? this.paidTo,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
