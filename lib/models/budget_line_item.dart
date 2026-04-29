import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetLineItem {
  final String id;
  final String budgetYearId;
  final String scheduleCode; // e.g. 'S-15', 'S-18a'
  final String sectionTitle; // e.g. 'Tithe Income'
  final String sectionType; // 'income', 'expense', 'appropriation'
  final String name;
  final double budgetAmount;
  // Optional link to auto-sum actuals from existing app data
  final String? linkedTransactionCategory; // e.g. 'travel', 'medicalReimbursement'
  final String? linkedReportType; // 'traveling', 'income', 'student'
  final int sortOrder;
  final DateTime? updatedAt;

  BudgetLineItem({
    required this.id,
    required this.budgetYearId,
    required this.scheduleCode,
    required this.sectionTitle,
    required this.sectionType,
    required this.name,
    this.budgetAmount = 0.0,
    this.linkedTransactionCategory,
    this.linkedReportType,
    required this.sortOrder,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'budgetYearId': budgetYearId,
        'scheduleCode': scheduleCode,
        'sectionTitle': sectionTitle,
        'sectionType': sectionType,
        'name': name,
        'budgetAmount': budgetAmount,
        'linkedTransactionCategory': linkedTransactionCategory,
        'linkedReportType': linkedReportType,
        'sortOrder': sortOrder,
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      };

  factory BudgetLineItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? tsOpt(dynamic v) => v is Timestamp ? v.toDate() : null;
    return BudgetLineItem(
      id: d['id'] ?? doc.id,
      budgetYearId: d['budgetYearId'] ?? '',
      scheduleCode: d['scheduleCode'] ?? '',
      sectionTitle: d['sectionTitle'] ?? '',
      sectionType: d['sectionType'] ?? 'expense',
      name: d['name'] ?? '',
      budgetAmount: (d['budgetAmount'] ?? 0.0).toDouble(),
      linkedTransactionCategory: d['linkedTransactionCategory'],
      linkedReportType: d['linkedReportType'],
      sortOrder: d['sortOrder'] ?? 0,
      updatedAt: tsOpt(d['updatedAt']),
    );
  }

  BudgetLineItem copyWith({
    String? budgetYearId,
    double? budgetAmount,
    String? linkedTransactionCategory,
    String? linkedReportType,
    DateTime? updatedAt,
  }) =>
      BudgetLineItem(
        id: id,
        budgetYearId: budgetYearId ?? this.budgetYearId,
        scheduleCode: scheduleCode,
        sectionTitle: sectionTitle,
        sectionType: sectionType,
        name: name,
        budgetAmount: budgetAmount ?? this.budgetAmount,
        linkedTransactionCategory:
            linkedTransactionCategory ?? this.linkedTransactionCategory,
        linkedReportType: linkedReportType ?? this.linkedReportType,
        sortOrder: sortOrder,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// Section grouping helper
class BudgetSection {
  final String code;
  final String title;
  final String type;
  final List<BudgetLineItem> items;

  const BudgetSection({
    required this.code,
    required this.title,
    required this.type,
    required this.items,
  });

  double get budgetTotal => items.fold(0, (s, i) => s + i.budgetAmount);
}
