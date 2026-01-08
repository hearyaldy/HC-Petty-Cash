import 'package:flutter/foundation.dart';
import '../services/report_service.dart';
import '../models/petty_cash_report.dart';
import '../models/user.dart';
import '../models/enums.dart';

class ReportProvider extends ChangeNotifier {
  final ReportService _reportService = ReportService();
  List<PettyCashReport> _reports = [];
  PettyCashReport? _selectedReport;
  bool _isLoading = false;

  List<PettyCashReport> get reports => _reports;
  PettyCashReport? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;

  Future<void> loadReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      _reports = await _reportService.getAllReports();
    } catch (e) {
      print('Error loading reports: $e');
      _reports = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<PettyCashReport> createReport({
    required DateTime periodStart,
    required DateTime periodEnd,
    required String department,
    required User custodian,
    required double openingBalance,
    String? companyName,
    String? notes,
  }) async {
    final report = await _reportService.createReport(
      periodStart: periodStart,
      periodEnd: periodEnd,
      department: department,
      custodian: custodian,
      openingBalance: openingBalance,
      companyName: companyName,
      notes: notes,
    );

    await loadReports();
    return report;
  }

  Future<void> updateReport(PettyCashReport report) async {
    await _reportService.updateReport(report);
    await loadReports();
  }

  Future<void> deleteReport(String reportId) async {
    await _reportService.deleteReport(reportId);
    await loadReports();
  }

  void selectReport(PettyCashReport? report) {
    _selectedReport = report;
    notifyListeners();
  }

  Future<void> submitReport(String reportId) async {
    await _reportService.submitReport(reportId);
    await loadReports();
  }

  Future<void> approveReport(String reportId) async {
    await _reportService.approveReport(reportId);
    await loadReports();
  }

  Future<void> closeReport(String reportId) async {
    await _reportService.closeReport(reportId);
    await loadReports();
  }

  Future<void> recalculateTotals(String reportId) async {
    await _reportService.recalculateTotals(reportId);
    await loadReports();
  }

  List<PettyCashReport> getReportsByStatus(ReportStatus status) {
    return _reports.where((r) => r.status == status.name).toList();
  }

  List<PettyCashReport> getReportsByCustodian(String custodianId) {
    return _reports.where((r) => r.custodianId == custodianId).toList();
  }

  Future<List<PettyCashReport>> searchReports(String query) async {
    try {
      return await _reportService.searchReports(query);
    } catch (e) {
      print('Error searching reports: $e');
      return [];
    }
  }
}
