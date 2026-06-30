import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_year.dart';
import '../models/budget_line_item.dart';
import '../utils/logger.dart';

class BudgetService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _years => _db.collection('budgetYears');
  CollectionReference get _items => _db.collection('budgetLineItems');

  // ── Budget Years ──────────────────────────────────────────────────────────

  Stream<List<BudgetYear>> budgetYearsStream() {
    return _years
        .orderBy('year', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BudgetYear.fromFirestore(d)).toList());
  }

  Future<BudgetYear?> getBudgetYear(String id) async {
    final doc = await _years.doc(id).get();
    return doc.exists ? BudgetYear.fromFirestore(doc) : null;
  }

  Future<void> saveBudgetYear(BudgetYear year) async {
    await _years.doc(year.id).set(year.toFirestore());
  }

  Future<void> updateBudgetYear(BudgetYear year) async {
    await _years.doc(year.id).update(year.toFirestore());
  }

  Future<void> deleteBudgetYear(String id) async {
    final batch = _db.batch();
    final items = await _items.where('budgetYearId', isEqualTo: id).get();
    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_years.doc(id));
    await batch.commit();
  }

  // ── Line Items ────────────────────────────────────────────────────────────

  Stream<List<BudgetLineItem>> lineItemsStream(String budgetYearId) {
    return _items
        .where('budgetYearId', isEqualTo: budgetYearId)
        .orderBy('sortOrder')
        .snapshots()
        .map(
          (s) => s.docs.map((d) => BudgetLineItem.fromFirestore(d)).toList(),
        );
  }

  Future<List<BudgetLineItem>> getLineItems(String budgetYearId) async {
    final snap = await _items
        .where('budgetYearId', isEqualTo: budgetYearId)
        .orderBy('sortOrder')
        .get();
    return snap.docs.map((d) => BudgetLineItem.fromFirestore(d)).toList();
  }

  Future<void> updateLineItem(BudgetLineItem item) async {
    await _items.doc(item.id).update(item.toFirestore());
  }

  Future<void> updateSection({
    required String budgetYearId,
    required String currentScheduleCode,
    required String scheduleCode,
    required String sectionTitle,
    required String sectionType,
  }) async {
    final snap = await _items
        .where('budgetYearId', isEqualTo: budgetYearId)
        .where('scheduleCode', isEqualTo: currentScheduleCode)
        .get();
    final batch = _db.batch();
    final now = Timestamp.fromDate(DateTime.now());
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'scheduleCode': scheduleCode,
        'sectionTitle': sectionTitle,
        'sectionType': sectionType,
        'updatedAt': now,
      });
    }
    await batch.commit();
  }

  Future<BudgetLineItem> addLineItem({
    required String budgetYearId,
    required String scheduleCode,
    required String sectionTitle,
    required String sectionType,
    required String name,
    double budgetAmount = 0,
    String? linkedTransactionCategory,
    String? linkedReportType,
    required int sortOrder,
  }) async {
    final id = const Uuid().v4();
    final item = BudgetLineItem(
      id: id,
      budgetYearId: budgetYearId,
      scheduleCode: scheduleCode,
      sectionTitle: sectionTitle,
      sectionType: sectionType,
      name: name,
      budgetAmount: budgetAmount,
      linkedTransactionCategory: linkedTransactionCategory,
      linkedReportType: linkedReportType,
      sortOrder: sortOrder,
      updatedAt: DateTime.now(),
    );
    await _items.doc(id).set(item.toFirestore());
    return item;
  }

  Future<void> deleteLineItem(String id) async {
    await _items.doc(id).delete();
  }

  Future<void> deleteSection({
    required String budgetYearId,
    required String scheduleCode,
  }) async {
    final snap = await _items
        .where('budgetYearId', isEqualTo: budgetYearId)
        .where('scheduleCode', isEqualTo: scheduleCode)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Create new year (seeded with default HCSA schedule) ──────────────────

  Future<BudgetYear> createBudgetYear({
    required int year,
    required String createdBy,
    String? notes,
    String? copyFromYearId,
  }) async {
    final uuid = const Uuid();
    final id = uuid.v4();
    final budgetYear = BudgetYear(
      id: id,
      year: year,
      status: 'draft',
      notes: notes,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    await saveBudgetYear(budgetYear);

    if (copyFromYearId != null) {
      await _copyLineItems(copyFromYearId, id, uuid);
    } else {
      await _seedDefaultLineItems(id, uuid);
    }
    return budgetYear;
  }

  Future<void> _copyLineItems(
    String fromYearId,
    String toYearId,
    Uuid uuid,
  ) async {
    final source = await getLineItems(fromYearId);
    final batch = _db.batch();
    for (final item in source) {
      final newId = uuid.v4();
      final copied = BudgetLineItem(
        id: newId,
        budgetYearId: toYearId,
        scheduleCode: item.scheduleCode,
        sectionTitle: item.sectionTitle,
        sectionType: item.sectionType,
        name: item.name,
        budgetAmount: item.budgetAmount,
        linkedTransactionCategory: item.linkedTransactionCategory,
        linkedReportType: item.linkedReportType,
        sortOrder: item.sortOrder,
      );
      batch.set(_items.doc(newId), copied.toFirestore());
    }
    await batch.commit();
  }

  Future<void> _seedDefaultLineItems(String budgetYearId, Uuid uuid) async {
    final items = _defaultLineItems(budgetYearId, uuid);
    final batch = _db.batch();
    for (final item in items) {
      batch.set(_items.doc(item.id), item.toFirestore());
    }
    await batch.commit();
  }

  // ── Actuals Calculation ───────────────────────────────────────────────────

  /// Returns a map of lineItemId → actual amount for the given year.
  Future<Map<String, double>> calculateActuals(
    List<BudgetLineItem> items,
    int year,
  ) async {
    final result = <String, double>{};
    try {
      final start = Timestamp.fromDate(DateTime(year, 1, 1));
      final end = Timestamp.fromDate(DateTime(year, 12, 31, 23, 59, 59));

      // Query by date only — filter status in-memory to avoid composite index requirements.

      // Transactions (petty cash line items)
      final Map<String, double> txByCategory = {};
      try {
        final txSnap = await _db
            .collection('transactions')
            .where('date', isGreaterThanOrEqualTo: start)
            .where('date', isLessThanOrEqualTo: end)
            .get();
        for (final doc in txSnap.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          if (status != 'approved' && status != 'processed') continue;
          final customCat = data['customCategory'] as String?;
          final amount = (data['amount'] ?? 0.0).toDouble();
          if (customCat != null && customCat.isNotEmpty) {
            txByCategory[customCat] = (txByCategory[customCat] ?? 0.0) + amount;
          } else {
            final cat = data['category'] as String? ?? 'other';
            txByCategory[cat] = (txByCategory[cat] ?? 0.0) + amount;
          }
        }
      } catch (e) {
        AppLogger.warning('Budget actuals — transactions query failed: $e');
      }

      // Traveling reports
      double travelingTotal = 0.0;
      try {
        final trSnap = await _db
            .collection('traveling_reports')
            .where('reportDate', isGreaterThanOrEqualTo: start)
            .where('reportDate', isLessThanOrEqualTo: end)
            .get();
        for (final doc in trSnap.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          if (status != 'approved' && status != 'closed') continue;
          travelingTotal += (data['perDiemTotal'] ?? 0.0).toDouble();
          final km =
              ((data['mileageEnd'] ?? 0.0) - (data['mileageStart'] ?? 0.0))
                  .toDouble();
          travelingTotal += km * 5.0;
        }
      } catch (e) {
        AppLogger.warning(
          'Budget actuals — traveling reports query failed: $e',
        );
      }

      // Income reports
      double incomeTotal = 0.0;
      try {
        final incSnap = await _db
            .collection('income_reports')
            .where('reportDate', isGreaterThanOrEqualTo: start)
            .where('reportDate', isLessThanOrEqualTo: end)
            .get();
        for (final doc in incSnap.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          if (status != 'approved' && status != 'closed') continue;
          incomeTotal += (data['totalIncome'] ?? 0.0).toDouble();
        }
      } catch (e) {
        AppLogger.warning('Budget actuals — income reports query failed: $e');
      }

      // Petty cash reports
      double pettyCashTotal = 0.0;
      try {
        final pcSnap = await _db
            .collection('reports')
            .where('periodStart', isGreaterThanOrEqualTo: start)
            .where('periodStart', isLessThanOrEqualTo: end)
            .get();
        for (final doc in pcSnap.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          if (status != 'approved' && status != 'closed') continue;
          pettyCashTotal += (data['totalDisbursements'] ?? 0.0).toDouble();
        }
      } catch (e) {
        AppLogger.warning(
          'Budget actuals — petty cash reports query failed: $e',
        );
      }

      // Project reports
      double projectTotal = 0.0;
      try {
        final prSnap = await _db
            .collection('project_reports')
            .where('startDate', isGreaterThanOrEqualTo: start)
            .where('startDate', isLessThanOrEqualTo: end)
            .get();
        for (final doc in prSnap.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          if (status != 'approved' && status != 'closed') continue;
          projectTotal += (data['totalExpenses'] ?? 0.0).toDouble();
        }
      } catch (e) {
        AppLogger.warning('Budget actuals — project reports query failed: $e');
      }

      AppLogger.info(
        'Budget actuals $year: tx=${txByCategory.length} cats, '
        'travel=$travelingTotal, income=$incomeTotal, '
        'pettyCash=$pettyCashTotal, project=$projectTotal',
      );

      // Map each line item
      for (final item in items) {
        double actual = 0.0;

        if (item.linkedReportType == 'traveling') {
          actual += travelingTotal;
        }
        if (item.linkedReportType == 'income') {
          actual += incomeTotal;
        }
        if (item.linkedReportType == 'petty_cash') {
          actual += pettyCashTotal;
        }
        if (item.linkedReportType == 'project') {
          actual += projectTotal;
        }
        if (item.linkedTransactionCategory != null) {
          actual += txByCategory[item.linkedTransactionCategory!] ?? 0.0;
        }

        if (actual > 0) result[item.id] = actual;
      }
    } catch (e) {
      AppLogger.severe('Error calculating budget actuals: $e');
    }
    return result;
  }

  // ── Default HCSA Schedule Structure ──────────────────────────────────────

  // 2026 budget figures sourced from the HCSA Budget 2026 PDF document.
  // These are the baseline amounts used when seeding a fresh budget year.
  static const _budget2026Amounts = <String, double>{
    // S-15
    'Tithe Percentages from Mission 1.3% (0.75%)': 5587978,
    // S-16
    'Donations': 6368,
    // S-17
    "Employee's rental share": 101573,
    'House Rental (Income)': 130088,
    'Miscellaneous Income': 34,
    'Other Incomes': 9845,
    'Production Service Income': 10667,
    'Project/Funct - Alloc Income': 33333,
    'Travel Income': 30295,
    // S-18a
    'AD & D Insurance': 3370,
    'Bonus/Christmas Gift/Farewell': 93768,
    'Car Allowance (annual exp)': 11962,
    'Continue Education (Upgrading)': 87667,
    'Dental Expense': 7793,
    'EPF Contribution/Provident Fund': 350460,
    'Educational Aid': 283405,
    'Equipment Subsidy': 23500,
    'Global Life Insurance': 12200,
    'Home Base Deposit/Retirement Contribution 3%': 66000,
    "Home Owner's subsidy/Rental subsidy": 555183,
    'Intern Cost': 0,
    'Medical Expense': 57041,
    'Mobile Telephone Allow.': 15600,
    'Optical Expense': 16234,
    'Salary': 3202140,
    'Social Security': 89250,
    'Stipend': 0,
    // S-18b
    'Home Leave Expense': 60000,
    'Travel Expense': 50000,
    // S-18c
    'Evangelism Expense': 150000,
    'HC Production Expense': 300000,
    'Project/Funct Alloc Expense': 213064,
    'Software Maintenance Expense': 20000,
    // S-19
    'Entertainment Expense': 20000,
    'General Meeting': 1057,
    'Immigration Expense': 88639,
    // S-20a
    'Office Supplies': 3541,
    'Photocopy': 1309,
    'Postage': 1093,
    'Telephone Expense': 918,
    'Translation & Printing Expense': 895,
    // S-20b
    'Condolence Expenses/Wreath': 3045,
    'Internet Expense': 36594,
    'Retreat Expense': 0,
    'Software Licenses': 200000,
    'Student Labor': 54131,
    'Uncapitalized Tools & Accessories': 100000,
    'Advertisement Expense': 50000,
    // S-21
    'Building Insurance': 93638,
    'Building Maintenance Expense': 0,
    'Deprec Exp - Buildings And Fixtures': 945102,
    'Deprec Exp - Furnishings And Equipment': 900898,
    'Deprec Exp - Vehicles': 103404,
    'Diesel Fuel/Gasoline Expense': 18219,
    'Electricity': 371609,
    'Ground Expense': 13237,
    'Janitorial Expense': 53475,
    'Repair & Maintenance Expense': 15921,
    'Security Expense': 143254,
    'Tool & Equipment Accessory': 18323,
    'Vehicle Insurance': 7718,
    'Vehicle Repair/Maintenance': 12984,
    'Vehicle Road Tax': 2636,
    'Water': 25328,
    // S-22
    'Tithe Appropriation Received': 2311600,
    // S-23
    'Tithe Appropriation Disbursed': 0,
    // S-24
    'Non Tithe SEUM Appropriation Received': 0,
    'Non Tithe Special Appropriation Received': 1356000,
    'Non Tithe from SSD Special Appropriation': 0,
    // S-25
    'Non-Tithe Appropriation Disbursed': 0,
  };

  static List<BudgetLineItem> _defaultLineItems(String yearId, Uuid uuid) {
    int order = 0;
    BudgetLineItem mk(
      String code,
      String section,
      String type,
      String name, {
      String? txCat,
      String? reportType,
    }) => BudgetLineItem(
      id: uuid.v4(),
      budgetYearId: yearId,
      scheduleCode: code,
      sectionTitle: section,
      sectionType: type,
      name: name,
      budgetAmount: _budget2026Amounts[name] ?? 0.0,
      linkedTransactionCategory: txCat,
      linkedReportType: reportType,
      sortOrder: order++,
    );

    return [
      // ── Income ────────────────────────────────────────────────────────────
      mk(
        'S-15',
        'Tithe Income',
        'income',
        'Tithe Percentages from Mission 1.3% (0.75%)',
      ),
      mk('S-16', 'Offering Income & Specific Donations', 'income', 'Donations'),
      mk('S-17', 'Other Operating Income', 'income', "Employee's rental share"),
      mk('S-17', 'Other Operating Income', 'income', 'House Rental (Income)'),
      mk('S-17', 'Other Operating Income', 'income', 'Miscellaneous Income'),
      mk('S-17', 'Other Operating Income', 'income', 'Other Incomes'),
      mk(
        'S-17',
        'Other Operating Income',
        'income',
        'Production Service Income',
      ),
      mk(
        'S-17',
        'Other Operating Income',
        'income',
        'Project/Funct - Alloc Income',
      ),
      mk('S-17', 'Other Operating Income', 'income', 'Travel Income'),
      // ── Expenses ─────────────────────────────────────────────────────────
      mk('S-18a', 'Employee Related Expenses', 'expense', 'AD & D Insurance'),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'Bonus/Christmas Gift/Farewell',
      ),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'Car Allowance (annual exp)',
      ),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'Continue Education (Upgrading)',
      ),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Dental Expense'),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'EPF Contribution/Provident Fund',
      ),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Educational Aid'),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Equipment Subsidy'),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'Global Life Insurance',
      ),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'Home Base Deposit/Retirement Contribution 3%',
      ),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        "Home Owner's subsidy/Rental subsidy",
      ),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Intern Cost'),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'Medical Expense',
        txCat: 'medicalReimbursement',
      ),
      mk(
        'S-18a',
        'Employee Related Expenses',
        'expense',
        'Mobile Telephone Allow.',
      ),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Optical Expense'),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Salary'),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Social Security'),
      mk('S-18a', 'Employee Related Expenses', 'expense', 'Stipend'),
      mk(
        'S-18b',
        'Travel Expenses',
        'expense',
        'Home Leave Expense',
        txCat: 'travel',
      ),
      mk(
        'S-18b',
        'Travel Expenses',
        'expense',
        'Travel Expense',
        reportType: 'traveling',
      ),
      mk('S-18c', 'Program Specific Expenses', 'expense', 'Evangelism Expense'),
      mk(
        'S-18c',
        'Program Specific Expenses',
        'expense',
        'HC Production Expense',
      ),
      mk(
        'S-18c',
        'Program Specific Expenses',
        'expense',
        'Project/Funct Alloc Expense',
      ),
      mk(
        'S-18c',
        'Program Specific Expenses',
        'expense',
        'Software Maintenance Expense',
      ),
      mk('S-19', 'Administrative Expenses', 'expense', 'Entertainment Expense'),
      mk('S-19', 'Administrative Expenses', 'expense', 'General Meeting'),
      mk('S-19', 'Administrative Expenses', 'expense', 'Immigration Expense'),
      mk(
        'S-20a',
        'Office Expenses',
        'expense',
        'Office Supplies',
        txCat: 'supplies',
      ),
      mk('S-20a', 'Office Expenses', 'expense', 'Photocopy'),
      mk('S-20a', 'Office Expenses', 'expense', 'Postage'),
      mk('S-20a', 'Office Expenses', 'expense', 'Telephone Expense'),
      mk(
        'S-20a',
        'Office Expenses',
        'expense',
        'Translation & Printing Expense',
      ),
      mk('S-20b', 'General Expenses', 'expense', 'Condolence Expenses/Wreath'),
      mk(
        'S-20b',
        'General Expenses',
        'expense',
        'Internet Expense',
        txCat: 'utilities',
      ),
      mk('S-20b', 'General Expenses', 'expense', 'Retreat Expense'),
      mk('S-20b', 'General Expenses', 'expense', 'Software Licenses'),
      mk('S-20b', 'General Expenses', 'expense', 'Student Labor'),
      mk(
        'S-20b',
        'General Expenses',
        'expense',
        'Uncapitalized Tools & Accessories',
      ),
      mk('S-20b', 'General Expenses', 'expense', 'Advertisement Expense'),
      mk('S-21', 'Other Operating Expense', 'expense', 'Building Insurance'),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Building Maintenance Expense',
        txCat: 'maintenance',
      ),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Deprec Exp - Buildings And Fixtures',
      ),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Deprec Exp - Furnishings And Equipment',
      ),
      mk('S-21', 'Other Operating Expense', 'expense', 'Deprec Exp - Vehicles'),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Diesel Fuel/Gasoline Expense',
      ),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Electricity',
        txCat: 'utilities',
      ),
      mk('S-21', 'Other Operating Expense', 'expense', 'Ground Expense'),
      mk('S-21', 'Other Operating Expense', 'expense', 'Janitorial Expense'),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Repair & Maintenance Expense',
        txCat: 'maintenance',
      ),
      mk('S-21', 'Other Operating Expense', 'expense', 'Security Expense'),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Tool & Equipment Accessory',
      ),
      mk('S-21', 'Other Operating Expense', 'expense', 'Vehicle Insurance'),
      mk(
        'S-21',
        'Other Operating Expense',
        'expense',
        'Vehicle Repair/Maintenance',
      ),
      mk('S-21', 'Other Operating Expense', 'expense', 'Vehicle Road Tax'),
      mk('S-21', 'Other Operating Expense', 'expense', 'Water'),
      // ── Appropriations ────────────────────────────────────────────────────
      mk(
        'S-22',
        'Tithe Appropriation Received',
        'appropriation',
        'Tithe Appropriation Received',
      ),
      mk(
        'S-23',
        'Tithe Appropriation Disbursed',
        'appropriation',
        'Tithe Appropriation Disbursed',
      ),
      mk(
        'S-24',
        'Non-Tithe Appropriation Received',
        'appropriation',
        'Non Tithe SEUM Appropriation Received',
      ),
      mk(
        'S-24',
        'Non-Tithe Appropriation Received',
        'appropriation',
        'Non Tithe Special Appropriation Received',
      ),
      mk(
        'S-24',
        'Non-Tithe Appropriation Received',
        'appropriation',
        'Non Tithe from SSD Special Appropriation',
      ),
      mk(
        'S-25',
        'Non-Tithe Appropriation Disbursed',
        'appropriation',
        'Non-Tithe Appropriation Disbursed',
      ),
    ];
  }
}
