import 'package:flutter/foundation.dart';
import '../models/income_report.dart';
import '../services/firestore_service.dart';

class IncomeReportProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<IncomeReport> _incomeReports = [];
  List<IncomeEntry> _currentEntries = [];
  IncomeReport? _currentReport;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<IncomeReport> get incomeReports => _incomeReports;
  List<IncomeEntry> get currentEntries => _currentEntries;
  IncomeReport? get currentReport => _currentReport;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get reports by status
  List<IncomeReport> get draftReports =>
      _incomeReports.where((r) => r.status == 'draft').toList();

  List<IncomeReport> get submittedReports =>
      _incomeReports.where((r) => r.status == 'submitted').toList();

  List<IncomeReport> get approvedReports =>
      _incomeReports.where((r) => r.status == 'approved').toList();

  List<IncomeReport> get closedReports =>
      _incomeReports.where((r) => r.status == 'closed').toList();

  // Total income calculations
  double get totalIncomeAllReports =>
      _incomeReports.fold(0.0, (sum, r) => sum + r.totalIncome);

  double get totalIncomeApproved => approvedReports.fold(
        0.0,
        (sum, r) => sum + r.totalIncome,
      );

  // Load all income reports
  Future<void> loadIncomeReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _incomeReports = await _firestoreService.getAllIncomeReports();
    } catch (e) {
      _error = 'Failed to load income reports: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load income reports by user
  Future<void> loadIncomeReportsByUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _incomeReports = await _firestoreService.getIncomeReportsByUser(userId);
    } catch (e) {
      _error = 'Failed to load income reports: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load a single report with its entries
  Future<void> loadReportWithEntries(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentReport = await _firestoreService.getIncomeReport(reportId);
      if (_currentReport != null) {
        _currentEntries =
            await _firestoreService.getIncomeEntriesByReport(reportId);
      }
    } catch (e) {
      _error = 'Failed to load report: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new income report
  Future<IncomeReport?> createIncomeReport({
    required String reportName,
    required String department,
    required String createdById,
    required String createdByName,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? description,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final report = await _firestoreService.createIncomeReport(
        reportName: reportName,
        department: department,
        createdById: createdById,
        createdByName: createdByName,
        periodStart: periodStart,
        periodEnd: periodEnd,
        description: description,
      );
      _incomeReports.insert(0, report);
      _currentReport = report;
      notifyListeners();
      return report;
    } catch (e) {
      _error = 'Failed to create income report: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update an income report
  Future<bool> updateIncomeReport(IncomeReport report) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.updateIncomeReport(report);
      final index = _incomeReports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _incomeReports[index] = report;
      }
      if (_currentReport?.id == report.id) {
        _currentReport = report;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update income report: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete an income report
  Future<bool> deleteIncomeReport(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.deleteIncomeReport(reportId);
      _incomeReports.removeWhere((r) => r.id == reportId);
      if (_currentReport?.id == reportId) {
        _currentReport = null;
        _currentEntries = [];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete income report: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit an income report
  Future<bool> submitIncomeReport(String reportId) async {
    try {
      await _firestoreService.submitIncomeReport(reportId);
      final index = _incomeReports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        _incomeReports[index] = _incomeReports[index].copyWith(
          status: 'submitted',
          submittedAt: DateTime.now(),
        );
      }
      if (_currentReport?.id == reportId) {
        _currentReport = _currentReport!.copyWith(
          status: 'submitted',
          submittedAt: DateTime.now(),
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to submit income report: $e';
      notifyListeners();
      return false;
    }
  }

  // Approve an income report
  Future<bool> approveIncomeReport(
      String reportId, String approverName) async {
    try {
      await _firestoreService.approveIncomeReport(reportId, approverName);
      final index = _incomeReports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        _incomeReports[index] = _incomeReports[index].copyWith(
          status: 'approved',
          approvedAt: DateTime.now(),
          approvedBy: approverName,
        );
      }
      if (_currentReport?.id == reportId) {
        _currentReport = _currentReport!.copyWith(
          status: 'approved',
          approvedAt: DateTime.now(),
          approvedBy: approverName,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to approve income report: $e';
      notifyListeners();
      return false;
    }
  }

  // Close an income report
  Future<bool> closeIncomeReport(String reportId) async {
    try {
      await _firestoreService.closeIncomeReport(reportId);
      final index = _incomeReports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        _incomeReports[index] = _incomeReports[index].copyWith(
          status: 'closed',
        );
      }
      if (_currentReport?.id == reportId) {
        _currentReport = _currentReport!.copyWith(status: 'closed');
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to close income report: $e';
      notifyListeners();
      return false;
    }
  }

  // Add an income entry
  Future<IncomeEntry?> addIncomeEntry({
    required String reportId,
    required DateTime dateReceived,
    required String category,
    required String sourceName,
    required String description,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    List<String>? supportDocumentUrls,
  }) async {
    try {
      final entry = await _firestoreService.addIncomeEntry(
        reportId: reportId,
        dateReceived: dateReceived,
        category: category,
        sourceName: sourceName,
        description: description,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        supportDocumentUrls: supportDocumentUrls,
      );
      _currentEntries.insert(0, entry);

      // Update total in current report
      if (_currentReport?.id == reportId) {
        final newTotal = _currentEntries.fold<double>(
          0.0,
          (sum, e) => sum + e.amount,
        );
        _currentReport = _currentReport!.copyWith(totalIncome: newTotal);
      }

      // Update in list
      final index = _incomeReports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        final newTotal = _incomeReports[index].totalIncome + amount;
        _incomeReports[index] = _incomeReports[index].copyWith(
          totalIncome: newTotal,
        );
      }

      notifyListeners();
      return entry;
    } catch (e) {
      _error = 'Failed to add income entry: $e';
      notifyListeners();
      return null;
    }
  }

  // Update an income entry
  Future<bool> updateIncomeEntry(IncomeEntry entry) async {
    try {
      await _firestoreService.updateIncomeEntry(entry);
      final index = _currentEntries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _currentEntries[index] = entry;
      }
      // Reload entries to get correct totals
      await loadReportWithEntries(entry.reportId);
      return true;
    } catch (e) {
      _error = 'Failed to update income entry: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete an income entry
  Future<bool> deleteIncomeEntry(String entryId, String reportId) async {
    try {
      await _firestoreService.deleteIncomeEntry(entryId, reportId);
      _currentEntries.removeWhere((e) => e.id == entryId);

      // Reload to get correct totals
      await loadReportWithEntries(reportId);
      return true;
    } catch (e) {
      _error = 'Failed to delete income entry: $e';
      notifyListeners();
      return false;
    }
  }

  // Clear current report
  void clearCurrentReport() {
    _currentReport = null;
    _currentEntries = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
