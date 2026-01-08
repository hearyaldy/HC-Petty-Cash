import 'package:flutter/foundation.dart';
import '../services/report_service.dart';
import '../models/petty_cash_report.dart';
import '../models/user.dart';
import '../models/enums.dart';
import '../utils/logger.dart';

class ReportProvider extends ChangeNotifier {
  final ReportService _reportService = ReportService();
  List<PettyCashReport> _reports = [];
  PettyCashReport? _selectedReport;
  bool _isLoading = false;
  String? _errorMessage;

  List<PettyCashReport> get reports => _reports;
  PettyCashReport? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      _reports = await _reportService.getAllReports();
    } catch (e) {
      AppLogger.severe('Error loading reports: $e');
      _reports = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<PettyCashReport> createReport({
    required DateTime periodStart,
    required DateTime periodEnd,
    required String reportName,
    required User custodian,
    required double openingBalance,
    String? companyName,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final report = await _reportService.createReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        department: reportName, // Using reportName as department for backward compatibility
        custodian: custodian,
        openingBalance: openingBalance,
        companyName: companyName,
        notes: notes,
      );

      await loadReports();
      _isLoading = false;
      notifyListeners();
      return report;
    } catch (e) {
      _errorMessage = 'Failed to create report: ${e.toString()}';
      AppLogger.severe('Error creating report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateReport(PettyCashReport report) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reportService.updateReport(report);
      await loadReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update report: ${e.toString()}';
      AppLogger.severe('Error updating report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteReport(String reportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reportService.deleteReport(reportId);
      await loadReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete report: ${e.toString()}';
      AppLogger.severe('Error deleting report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void selectReport(PettyCashReport? report) {
    _selectedReport = report;
    notifyListeners();
  }

  Future<void> submitReport(String reportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reportService.submitReport(reportId);
      await loadReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to submit report: ${e.toString()}';
      AppLogger.severe('Error submitting report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> approveReport(String reportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reportService.approveReport(reportId);
      await loadReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to approve report: ${e.toString()}';
      AppLogger.severe('Error approving report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> closeReport(String reportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reportService.closeReport(reportId);
      await loadReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to close report: ${e.toString()}';
      AppLogger.severe('Error closing report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> recalculateTotals(String reportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reportService.recalculateTotals(reportId);
      await loadReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to recalculate totals: ${e.toString()}';
      AppLogger.severe('Error recalculating totals: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  List<PettyCashReport> getReportsByStatus(ReportStatus status) {
    return _reports.where((r) => r.status == status.name).toList();
  }

  List<PettyCashReport> getReportsByCustodian(String custodianId) {
    return _reports.where((r) => r.custodianId == custodianId).toList();
  }

  Future<List<PettyCashReport>> searchReports(String query) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _reportService.searchReports(query);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Failed to search reports: ${e.toString()}';
      AppLogger.severe('Error searching reports: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Expose the reports list for other screens to access
  Future<List<PettyCashReport>> getAllReports() async {
    return _reports;
  }
}
