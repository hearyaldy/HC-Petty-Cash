import 'package:cloud_firestore/cloud_firestore.dart';

class DebitNoteLineItem {
  final String description;
  final double amount;

  DebitNoteLineItem({required this.description, required this.amount});

  Map<String, dynamic> toMap() => {
        'description': description,
        'amount': amount,
      };

  factory DebitNoteLineItem.fromMap(Map<String, dynamic> map) =>
      DebitNoteLineItem(
        description: (map['description'] as String?) ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      );

  DebitNoteLineItem copyWith({String? description, double? amount}) =>
      DebitNoteLineItem(
        description: description ?? this.description,
        amount: amount ?? this.amount,
      );
}

class InternalDebitNote {
  final String id;
  final String debitNoteNumber; // Format: IDN-YYYY-XXX
  final DateTime noteDate;
  final String companyName; // Issuing company
  final String issuedToCompany; // Recipient company
  final String department;
  final List<DebitNoteLineItem> lineItems;
  final String currency; // e.g. 'THB', 'USD'
  final String reasonForDebit;
  final String paymentTerms; // Payment / Settlement Terms
  final String preparedByName;
  final String? checkedByName;
  final String? approvedByName;
  final String status; // 'draft', 'issued'
  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get totalAmount =>
      lineItems.fold(0.0, (sum, item) => sum + item.amount);

  InternalDebitNote({
    required this.id,
    required this.debitNoteNumber,
    required this.noteDate,
    required this.companyName,
    required this.issuedToCompany,
    required this.department,
    List<DebitNoteLineItem>? lineItems,
    this.currency = 'THB',
    required this.reasonForDebit,
    required this.paymentTerms,
    required this.preparedByName,
    this.checkedByName,
    this.approvedByName,
    this.status = 'draft',
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  }) : lineItems = lineItems ?? [];

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'debitNoteNumber': debitNoteNumber,
      'noteDate': Timestamp.fromDate(noteDate),
      'companyName': companyName,
      'issuedToCompany': issuedToCompany,
      'department': department,
      'lineItems': lineItems.map((i) => i.toMap()).toList(),
      'currency': currency,
      'reasonForDebit': reasonForDebit,
      'paymentTerms': paymentTerms,
      'preparedByName': preparedByName,
      'checkedByName': checkedByName,
      'approvedByName': approvedByName,
      'status': status,
      'createdById': createdById,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory InternalDebitNote.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final now = DateTime.now();

    return InternalDebitNote(
      id: data['id'] as String? ?? doc.id,
      debitNoteNumber: data['debitNoteNumber'] as String? ?? '',
      noteDate: parseTimestamp(data['noteDate'], now),
      companyName: data['companyName'] as String? ?? '',
      issuedToCompany: data['issuedToCompany'] as String? ?? '',
      department: data['department'] as String? ?? '',
      lineItems: ((data['lineItems'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => DebitNoteLineItem.fromMap(m))
          .toList(),
      currency: data['currency'] as String? ?? 'THB',
      reasonForDebit: data['reasonForDebit'] as String? ?? '',
      paymentTerms: data['paymentTerms'] as String? ?? '',
      preparedByName: data['preparedByName'] as String? ?? '',
      checkedByName: data['checkedByName'] as String?,
      approvedByName: data['approvedByName'] as String?,
      status: data['status'] as String? ?? 'draft',
      createdById: data['createdById'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: parseTimestamp(data['updatedAt'], now),
    );
  }

  InternalDebitNote copyWith({
    String? id,
    String? debitNoteNumber,
    DateTime? noteDate,
    String? companyName,
    String? issuedToCompany,
    String? department,
    List<DebitNoteLineItem>? lineItems,
    String? currency,
    String? reasonForDebit,
    String? paymentTerms,
    String? preparedByName,
    String? checkedByName,
    String? approvedByName,
    String? status,
    String? createdById,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InternalDebitNote(
      id: id ?? this.id,
      debitNoteNumber: debitNoteNumber ?? this.debitNoteNumber,
      noteDate: noteDate ?? this.noteDate,
      companyName: companyName ?? this.companyName,
      issuedToCompany: issuedToCompany ?? this.issuedToCompany,
      department: department ?? this.department,
      lineItems: lineItems ?? this.lineItems,
      currency: currency ?? this.currency,
      reasonForDebit: reasonForDebit ?? this.reasonForDebit,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      preparedByName: preparedByName ?? this.preparedByName,
      checkedByName: checkedByName ?? this.checkedByName,
      approvedByName: approvedByName ?? this.approvedByName,
      status: status ?? this.status,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
