import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetYear {
  final String id;
  final int year;
  final String status; // 'draft', 'approved'
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;

  BudgetYear({
    required this.id,
    required this.year,
    this.status = 'draft',
    this.notes,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.approvedBy,
    this.approvedAt,
  });

  bool get isApproved => status == 'approved';

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'year': year,
        'status': status,
        'notes': notes,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      };

  factory BudgetYear.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime ts(dynamic v, DateTime fb) =>
        v is Timestamp ? v.toDate() : fb;
    DateTime? tsOpt(dynamic v) => v is Timestamp ? v.toDate() : null;
    final now = DateTime.now();
    return BudgetYear(
      id: d['id'] ?? doc.id,
      year: d['year'] ?? now.year,
      status: d['status'] ?? 'draft',
      notes: d['notes'],
      createdBy: d['createdBy'] ?? '',
      createdAt: ts(d['createdAt'], now),
      updatedAt: tsOpt(d['updatedAt']),
      approvedBy: d['approvedBy'],
      approvedAt: tsOpt(d['approvedAt']),
    );
  }

  BudgetYear copyWith({
    String? status,
    String? notes,
    DateTime? updatedAt,
    String? approvedBy,
    DateTime? approvedAt,
  }) =>
      BudgetYear(
        id: id,
        year: year,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        approvedBy: approvedBy ?? this.approvedBy,
        approvedAt: approvedAt ?? this.approvedAt,
      );
}
