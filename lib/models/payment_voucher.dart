import 'package:cloud_firestore/cloud_firestore.dart';

class VoucherRecipient {
  final String name;
  final String title; // role/position, e.g. "Finance Manager"

  VoucherRecipient({required this.name, required this.title});

  Map<String, dynamic> toMap() => {'name': name, 'title': title};

  factory VoucherRecipient.fromMap(Map<String, dynamic> map) => VoucherRecipient(
        name: (map['name'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
      );

  VoucherRecipient copyWith({String? name, String? title}) => VoucherRecipient(
        name: name ?? this.name,
        title: title ?? this.title,
      );
}

class PaymentVoucher {
  final String id;
  final String voucherNumber; // Format: PV-YYYYMMDD-XXXX
  final DateTime voucherDate;
  final List<VoucherRecipient> recipients;
  final String department;
  final String purpose;
  final double amount;
  final String paymentMethod; // 'cash', 'bank_transfer', 'cheque'
  final String? bankName;
  final String? accountNumber;
  final String? chequeNumber;
  final String status; // 'draft', 'submitted', 'approved', 'paid', 'rejected'
  final String? rejectionReason;
  final String createdById;
  final String createdByName;
  final String? approvedById;
  final String? approvedByName;
  final String? notes;
  final List<String> supportDocumentUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;

  /// Computed getter — returns comma-joined recipient names for backward compat.
  String get payTo =>
      recipients.isNotEmpty ? recipients.map((r) => r.name).join(', ') : '';

  PaymentVoucher({
    required this.id,
    required this.voucherNumber,
    required this.voucherDate,
    List<VoucherRecipient>? recipients,
    required this.department,
    required this.purpose,
    required this.amount,
    required this.paymentMethod,
    this.bankName,
    this.accountNumber,
    this.chequeNumber,
    this.status = 'draft',
    this.rejectionReason,
    required this.createdById,
    required this.createdByName,
    this.approvedById,
    this.approvedByName,
    this.notes,
    List<String>? supportDocumentUrls,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
  })  : recipients = recipients ?? [],
        supportDocumentUrls = supportDocumentUrls ?? [];

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'voucherNumber': voucherNumber,
      'voucherDate': Timestamp.fromDate(voucherDate),
      'recipients': recipients.map((r) => r.toMap()).toList(),
      'department': department,
      'purpose': purpose,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'chequeNumber': chequeNumber,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdById': createdById,
      'createdByName': createdByName,
      'approvedById': approvedById,
      'approvedByName': approvedByName,
      'notes': notes,
      'supportDocumentUrls': supportDocumentUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    };
  }

  factory PaymentVoucher.fromFirestore(DocumentSnapshot doc) {
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

    // Parse recipients list; fall back to legacy 'payTo' string field.
    List<VoucherRecipient> parsedRecipients = [];
    final rawRecipients = data['recipients'];
    if (rawRecipients is List && rawRecipients.isNotEmpty) {
      parsedRecipients = rawRecipients
          .whereType<Map<String, dynamic>>()
          .map((m) => VoucherRecipient.fromMap(m))
          .toList();
    } else {
      // Legacy fallback: if 'payTo' string exists, create a single recipient.
      final legacyPayTo = data['payTo'] as String?;
      if (legacyPayTo != null && legacyPayTo.isNotEmpty) {
        parsedRecipients = [VoucherRecipient(name: legacyPayTo, title: '')];
      }
    }

    return PaymentVoucher(
      id: data['id'] as String? ?? doc.id,
      voucherNumber: data['voucherNumber'] as String? ?? '',
      voucherDate: parseTimestamp(data['voucherDate'], now),
      recipients: parsedRecipients,
      department: data['department'] as String? ?? '',
      purpose: data['purpose'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      bankName: data['bankName'] as String?,
      accountNumber: data['accountNumber'] as String?,
      chequeNumber: data['chequeNumber'] as String?,
      status: data['status'] as String? ?? 'draft',
      rejectionReason: data['rejectionReason'] as String?,
      createdById: data['createdById'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      approvedById: data['approvedById'] as String?,
      approvedByName: data['approvedByName'] as String?,
      notes: data['notes'] as String?,
      supportDocumentUrls:
          (data['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: parseTimestamp(data['updatedAt'], now),
      paidAt: parseTimestampOptional(data['paidAt']),
    );
  }

  PaymentVoucher copyWith({
    String? id,
    String? voucherNumber,
    DateTime? voucherDate,
    List<VoucherRecipient>? recipients,
    String? department,
    String? purpose,
    double? amount,
    String? paymentMethod,
    String? bankName,
    String? accountNumber,
    String? chequeNumber,
    String? status,
    String? rejectionReason,
    String? createdById,
    String? createdByName,
    String? approvedById,
    String? approvedByName,
    String? notes,
    List<String>? supportDocumentUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
  }) {
    return PaymentVoucher(
      id: id ?? this.id,
      voucherNumber: voucherNumber ?? this.voucherNumber,
      voucherDate: voucherDate ?? this.voucherDate,
      recipients: recipients ?? this.recipients,
      department: department ?? this.department,
      purpose: purpose ?? this.purpose,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      approvedById: approvedById ?? this.approvedById,
      approvedByName: approvedByName ?? this.approvedByName,
      notes: notes ?? this.notes,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
