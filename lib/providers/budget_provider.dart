import 'package:flutter/foundation.dart';
import '../models/budget_year.dart';
import '../models/budget_line_item.dart';
import '../services/budget_service.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetService _service = BudgetService();

  List<BudgetYear> _years = [];
  List<BudgetLineItem> _lineItems = [];
  Map<String, double> _actuals = {};
  BudgetYear? _selectedYear;
  bool _isLoading = false;
  bool _isLoadingActuals = false;
  String? _error;
  final Set<String> _pendingAddKeys = {};

  List<BudgetYear> get years => _years;
  List<BudgetLineItem> get lineItems => _lineItems;
  Map<String, double> get actuals => _actuals;
  BudgetYear? get selectedYear => _selectedYear;
  bool get isLoading => _isLoading;
  bool get isLoadingActuals => _isLoadingActuals;
  String? get error => _error;

  String _addKey({
    required String budgetYearId,
    required String scheduleCode,
    required String sectionTitle,
    required String sectionType,
    required String name,
    required double budgetAmount,
    String? linkedTransactionCategory,
    String? linkedReportType,
  }) {
    String clean(String value) => value.trim().toLowerCase();
    return [
      budgetYearId,
      clean(scheduleCode),
      clean(sectionTitle),
      clean(sectionType),
      clean(name),
      budgetAmount.toStringAsFixed(2),
      linkedTransactionCategory ?? '',
      linkedReportType ?? '',
    ].join('|');
  }

  // ── Grouped by section ────────────────────────────────────────────────────

  List<BudgetSection> sectionsOfType(String type) {
    final filtered = _lineItems.where((i) => i.sectionType == type).toList();
    final Map<String, List<BudgetLineItem>> grouped = {};
    for (final item in filtered) {
      grouped.putIfAbsent(item.scheduleCode, () => []).add(item);
    }
    return grouped.entries.map((e) {
      final title = e.value.first.sectionTitle;
      return BudgetSection(
        code: e.key,
        title: title,
        type: type,
        items: e.value,
      );
    }).toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  // ── Summary totals ─────────────────────────────────────────────────────────
  // Appropriations are treated as income (funds received from conference/union).

  double get totalIncomeBudget => _lineItems
      .where(
        (i) => i.sectionType == 'income' || i.sectionType == 'appropriation',
      )
      .fold(0, (s, i) => s + i.budgetAmount);

  double get totalExpenseBudget => _lineItems
      .where((i) => i.sectionType == 'expense')
      .fold(0, (s, i) => s + i.budgetAmount);

  double get totalOperatingIncomeBudget => _lineItems
      .where((i) => i.sectionType == 'income')
      .fold(0, (s, i) => s + i.budgetAmount);

  double get totalAppropriationBudget => _lineItems
      .where((i) => i.sectionType == 'appropriation')
      .fold(0, (s, i) => s + i.budgetAmount);

  double get totalIncomeActual => _lineItems
      .where(
        (i) => i.sectionType == 'income' || i.sectionType == 'appropriation',
      )
      .fold(0, (s, i) => s + (_actuals[i.id] ?? 0));

  double get totalExpenseActual => _lineItems
      .where((i) => i.sectionType == 'expense')
      .fold(0, (s, i) => s + (_actuals[i.id] ?? 0));

  // ── Load ──────────────────────────────────────────────────────────────────

  void subscribeYears() {
    _service.budgetYearsStream().listen((data) {
      _years = data;
      notifyListeners();
    });
  }

  Future<void> loadYearById(String id) async {
    final year = await _service.getBudgetYear(id);
    if (year != null) await selectYear(year);
  }

  Future<void> selectYear(BudgetYear year) async {
    _selectedYear = year;
    _lineItems = [];
    _actuals = {};
    notifyListeners();

    bool firstLoad = true;
    _service.lineItemsStream(year.id).listen((data) {
      _lineItems = data;
      notifyListeners();
      if (firstLoad && data.isNotEmpty) {
        firstLoad = false;
        _refreshActuals(year);
      }
    });
  }

  Future<void> _refreshActuals(BudgetYear year) async {
    _isLoadingActuals = true;
    notifyListeners();
    try {
      _actuals = await _service.calculateActuals(_lineItems, year.year);
    } finally {
      _isLoadingActuals = false;
      notifyListeners();
    }
  }

  // ── Create / copy ─────────────────────────────────────────────────────────

  Future<BudgetYear> createYear({
    required int year,
    required String createdBy,
    String? notes,
    String? copyFromYearId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.createBudgetYear(
        year: year,
        createdBy: createdBy,
        notes: notes,
        copyFromYearId: copyFromYearId,
      );
      return result;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> updateLineItem(BudgetLineItem item) async {
    final updated = item.copyWith(updatedAt: DateTime.now());
    await _service.updateLineItem(updated);
    // Update in-memory so actuals recalculate with the new linked category
    _lineItems = _lineItems
        .map((i) => i.id == updated.id ? updated : i)
        .toList();
    await _refreshActuals(_selectedYear!);
  }

  Future<void> updateSection({
    required String currentScheduleCode,
    required String scheduleCode,
    required String sectionTitle,
    required String sectionType,
  }) async {
    if (_selectedYear == null) return;
    await _service.updateSection(
      budgetYearId: _selectedYear!.id,
      currentScheduleCode: currentScheduleCode,
      scheduleCode: scheduleCode,
      sectionTitle: sectionTitle,
      sectionType: sectionType,
    );
    _lineItems = _lineItems
        .map(
          (item) => item.scheduleCode == currentScheduleCode
              ? item.copyWith(
                  scheduleCode: scheduleCode,
                  sectionTitle: sectionTitle,
                  sectionType: sectionType,
                  updatedAt: DateTime.now(),
                )
              : item,
        )
        .toList();
    await _refreshActuals(_selectedYear!);
  }

  Future<void> addLineItem({
    required String scheduleCode,
    required String sectionTitle,
    required String sectionType,
    required String name,
    double budgetAmount = 0,
    String? linkedTransactionCategory,
    String? linkedReportType,
  }) async {
    if (_selectedYear == null) return;
    final addKey = _addKey(
      budgetYearId: _selectedYear!.id,
      scheduleCode: scheduleCode,
      sectionTitle: sectionTitle,
      sectionType: sectionType,
      name: name,
      budgetAmount: budgetAmount,
      linkedTransactionCategory: linkedTransactionCategory,
      linkedReportType: linkedReportType,
    );
    if (_pendingAddKeys.contains(addKey)) {
      return;
    }
    _pendingAddKeys.add(addKey);
    final maxOrder = _lineItems.isEmpty
        ? 0
        : _lineItems.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) +
              1;
    try {
      final item = await _service.addLineItem(
        budgetYearId: _selectedYear!.id,
        scheduleCode: scheduleCode,
        sectionTitle: sectionTitle,
        sectionType: sectionType,
        name: name,
        budgetAmount: budgetAmount,
        linkedTransactionCategory: linkedTransactionCategory,
        linkedReportType: linkedReportType,
        sortOrder: maxOrder,
      );
      if (!_lineItems.any((existing) => existing.id == item.id)) {
        _lineItems = [..._lineItems, item]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      notifyListeners();
      await _refreshActuals(_selectedYear!);
    } finally {
      _pendingAddKeys.remove(addKey);
    }
  }

  Future<void> deleteLineItem(String id) async {
    if (_selectedYear == null) return;
    await _service.deleteLineItem(id);
    _lineItems = _lineItems.where((item) => item.id != id).toList();
    _actuals.remove(id);
    notifyListeners();
    await _refreshActuals(_selectedYear!);
  }

  Future<void> deleteSection(String scheduleCode) async {
    if (_selectedYear == null) return;
    await _service.deleteSection(
      budgetYearId: _selectedYear!.id,
      scheduleCode: scheduleCode,
    );
    final deletedIds = _lineItems
        .where((item) => item.scheduleCode == scheduleCode)
        .map((item) => item.id)
        .toSet();
    _lineItems = _lineItems
        .where((item) => item.scheduleCode != scheduleCode)
        .toList();
    for (final id in deletedIds) {
      _actuals.remove(id);
    }
    notifyListeners();
    await _refreshActuals(_selectedYear!);
  }

  Future<void> approveYear(String userId) async {
    if (_selectedYear == null) return;
    final updated = _selectedYear!.copyWith(
      status: 'approved',
      approvedBy: userId,
      approvedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _service.updateBudgetYear(updated);
    _selectedYear = updated;
    notifyListeners();
  }

  Future<void> deleteYear(String id) async {
    await _service.deleteBudgetYear(id);
    if (_selectedYear?.id == id) {
      _selectedYear = null;
      _lineItems = [];
      _actuals = {};
    }
    notifyListeners();
  }

  Future<void> refreshActuals() async {
    if (_selectedYear != null) await _refreshActuals(_selectedYear!);
  }
}
