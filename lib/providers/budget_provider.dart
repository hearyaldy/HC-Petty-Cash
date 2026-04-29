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

  List<BudgetYear> get years => _years;
  List<BudgetLineItem> get lineItems => _lineItems;
  Map<String, double> get actuals => _actuals;
  BudgetYear? get selectedYear => _selectedYear;
  bool get isLoading => _isLoading;
  bool get isLoadingActuals => _isLoadingActuals;
  String? get error => _error;

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
          code: e.key, title: title, type: type, items: e.value);
    }).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  // ── Summary totals ────────────────────────────────────────────────────────

  double get totalIncomeBudget => _lineItems
      .where((i) => i.sectionType == 'income')
      .fold(0, (s, i) => s + i.budgetAmount);

  double get totalExpenseBudget => _lineItems
      .where((i) => i.sectionType == 'expense')
      .fold(0, (s, i) => s + i.budgetAmount);

  double get totalAppropriationBudget => _lineItems
      .where((i) => i.sectionType == 'appropriation')
      .fold(0, (s, i) => s + i.budgetAmount);

  double get totalIncomeActual =>
      _lineItems.where((i) => i.sectionType == 'income').fold(
            0,
            (s, i) => s + (_actuals[i.id] ?? 0),
          );

  double get totalExpenseActual =>
      _lineItems.where((i) => i.sectionType == 'expense').fold(
            0,
            (s, i) => s + (_actuals[i.id] ?? 0),
          );

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

    _service.lineItemsStream(year.id).listen((data) {
      _lineItems = data;
      notifyListeners();
    });

    await _refreshActuals(year);
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
    await _service.updateLineItem(
        item.copyWith(updatedAt: DateTime.now()));
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
    final maxOrder = _lineItems.isEmpty
        ? 0
        : _lineItems.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) +
            1;
    await _service.addLineItem(
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
  }

  Future<void> deleteLineItem(String id) async {
    await _service.deleteLineItem(id);
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
