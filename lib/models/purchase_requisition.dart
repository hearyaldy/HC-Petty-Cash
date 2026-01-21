import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class PurchaseRequisitionItem {
  final String id;
  final String requisitionId;
  final int itemNo;
  final String description;
  final int quantity;
  final double unitPrice;
  final String? remark;
  final DateTime createdAt;
  final List<String> supportDocumentUrls;

  PurchaseRequisitionItem({
    required this.id,
    required this.requisitionId,
    required this.itemNo,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.remark,
    required this.createdAt,
    List<String>? supportDocumentUrls,
  }) : supportDocumentUrls = supportDocumentUrls ?? [];

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'requisitionId': requisitionId,
      'itemNo': itemNo,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'remark': remark,
      'createdAt': Timestamp.fromDate(createdAt),
      'supportDocumentUrls': supportDocumentUrls,
    };
  }

  factory PurchaseRequisitionItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseRequisitionItem(
      id: data['id'] ?? doc.id,
      requisitionId: data['requisitionId'] ?? '',
      itemNo: data['itemNo'] ?? 0,
      description: data['description'] ?? '',
      quantity: data['quantity'] ?? 0,
      unitPrice: (data['unitPrice'] ?? 0.0).toDouble(),
      remark: data['remark'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      supportDocumentUrls: List<String>.from(data['supportDocumentUrls'] ?? []),
    );
  }

  factory PurchaseRequisitionItem.fromMap(Map<String, dynamic> data) {
    return PurchaseRequisitionItem(
      id: data['id'] ?? '',
      requisitionId: data['requisitionId'] ?? '',
      itemNo: data['itemNo'] ?? 0,
      description: data['description'] ?? '',
      quantity: data['quantity'] ?? 0,
      unitPrice: (data['unitPrice'] ?? 0.0).toDouble(),
      remark: data['remark'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      supportDocumentUrls: List<String>.from(data['supportDocumentUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  PurchaseRequisitionItem copyWith({
    String? id,
    String? requisitionId,
    int? itemNo,
    String? description,
    int? quantity,
    double? unitPrice,
    String? remark,
    DateTime? createdAt,
    List<String>? supportDocumentUrls,
  }) {
    return PurchaseRequisitionItem(
      id: id ?? this.id,
      requisitionId: requisitionId ?? this.requisitionId,
      itemNo: itemNo ?? this.itemNo,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
    );
  }
}

class PurchaseRequisition {
  final String id;
  final String requisitionNumber; // Format: PR-YYYYMMDD-XXX
  final DateTime requisitionDate;
  final String requestedBy;
  final String idNo;
  final String chargeToDepartment;
  final double totalAmount;
  final String? notes;

  // Status and approval
  final String status; // 'draft', 'submitted', 'approved', 'rejected', 'closed'
  final DateTime createdAt;
  final DateTime? submittedAt;
  final String? submittedBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? actionNo; // For amounts more than 20,000 Baht per item
  final String? rejectionReason;
  final List<String> supportDocumentUrls;
  final DateTime? updatedAt;

  PurchaseRequisition({
    required this.id,
    required this.requisitionNumber,
    required this.requisitionDate,
    required this.requestedBy,
    required this.idNo,
    required this.chargeToDepartment,
    this.totalAmount = 0.0,
    this.notes,
    this.status = 'draft',
    required this.createdAt,
    this.submittedAt,
    this.submittedBy,
    this.approvedAt,
    this.approvedBy,
    this.actionNo,
    this.rejectionReason,
    List<String>? supportDocumentUrls,
    this.updatedAt,
  }) : supportDocumentUrls = supportDocumentUrls ?? [];

  ReportStatus get statusEnum => status.toReportStatus();

  // Check if any item exceeds 20,000 Baht threshold
  bool get requiresActionNo => totalAmount > 20000;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'requisitionNumber': requisitionNumber,
      'requisitionDate': Timestamp.fromDate(requisitionDate),
      'requestedBy': requestedBy,
      'idNo': idNo,
      'chargeToDepartment': chargeToDepartment,
      'totalAmount': totalAmount,
      'notes': notes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'submittedBy': submittedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'actionNo': actionNo,
      'rejectionReason': rejectionReason,
      'supportDocumentUrls': supportDocumentUrls,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory PurchaseRequisition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseRequisition(
      id: data['id'] ?? doc.id,
      requisitionNumber: data['requisitionNumber'] ?? '',
      requisitionDate: (data['requisitionDate'] as Timestamp).toDate(),
      requestedBy: data['requestedBy'] ?? '',
      idNo: data['idNo'] ?? '',
      chargeToDepartment: data['chargeToDepartment'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      notes: data['notes'],
      status: data['status'] ?? 'draft',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
      submittedBy: data['submittedBy'],
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      actionNo: data['actionNo'],
      rejectionReason: data['rejectionReason'],
      supportDocumentUrls:
          (data['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory PurchaseRequisition.fromJson(Map<String, dynamic> json) {
    return PurchaseRequisition(
      id: json['id'] ?? '',
      requisitionNumber: json['requisitionNumber'] ?? '',
      requisitionDate: json['requisitionDate'] is Timestamp
          ? (json['requisitionDate'] as Timestamp).toDate()
          : DateTime.parse(
              json['requisitionDate'] ?? DateTime.now().toIso8601String(),
            ),
      requestedBy: json['requestedBy'] ?? '',
      idNo: json['idNo'] ?? '',
      chargeToDepartment: json['chargeToDepartment'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      notes: json['notes'],
      status: json['status'] ?? 'draft',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
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
      actionNo: json['actionNo'],
      rejectionReason: json['rejectionReason'],
      supportDocumentUrls:
          (json['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : DateTime.parse(json['updatedAt']))
          : null,
    );
  }

  PurchaseRequisition copyWith({
    String? id,
    String? requisitionNumber,
    DateTime? requisitionDate,
    String? requestedBy,
    String? idNo,
    String? chargeToDepartment,
    double? totalAmount,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? submittedAt,
    String? submittedBy,
    DateTime? approvedAt,
    String? approvedBy,
    String? actionNo,
    String? rejectionReason,
    List<String>? supportDocumentUrls,
    DateTime? updatedAt,
  }) {
    return PurchaseRequisition(
      id: id ?? this.id,
      requisitionNumber: requisitionNumber ?? this.requisitionNumber,
      requisitionDate: requisitionDate ?? this.requisitionDate,
      requestedBy: requestedBy ?? this.requestedBy,
      idNo: idNo ?? this.idNo,
      chargeToDepartment: chargeToDepartment ?? this.chargeToDepartment,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      actionNo: actionNo ?? this.actionNo,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
