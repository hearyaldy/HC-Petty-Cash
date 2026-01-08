import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/petty_cash_report.dart';
import '../models/transaction.dart' as app;
import '../models/enums.dart';
import '../models/user.dart';
import 'firestore_service.dart';

class ReportService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  /// Generate a unique report number
  Future<String> generateReportNumber() async {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd');
    final allReports = await _firestoreService.getAllReports();
    final count = allReports
            .where((r) =>
                r.reportNumber.startsWith('PCR-${formatter.format(now)}'))
            .length +
        1;
    return 'PCR-${formatter.format(now)}-${count.toString().padLeft(3, '0')}';
  }

  /// Create a new petty cash report
  Future<PettyCashReport> createReport({
    required DateTime periodStart,
    required DateTime periodEnd,
    required String department,
    required User custodian,
    required double openingBalance,
    String? companyName,
    String? notes,
  }) async {
    final reportNumber = await generateReportNumber();

    final report = PettyCashReport(
      id: _uuid.v4(),
      reportNumber: reportNumber,
      periodStart: periodStart,
      periodEnd: periodEnd,
      department: department,
      custodianId: custodian.id,
      custodianName: custodian.name,
      openingBalance: openingBalance,
      status: ReportStatus.draft.name,
      createdAt: DateTime.now(),
      companyName: companyName,
      notes: notes,
    );

    await _firestoreService.saveReport(report);
    return report;
  }

  /// Update an existing report
  Future<void> updateReport(PettyCashReport report) async {
    final updated = report.copyWith(updatedAt: DateTime.now());
    await _firestoreService.updateReport(updated);
  }

  /// Delete a report and all its transactions
  Future<void> deleteReport(String reportId) async {
    await _firestoreService.deleteReport(reportId);
  }

  /// Get all reports
  Future<List<PettyCashReport>> getAllReports() async {
    return await _firestoreService.getAllReports();
  }

  /// Get reports by status
  Future<List<PettyCashReport>> getReportsByStatus(ReportStatus status) async {
    return await _firestoreService.getReportsByStatus(status.name);
  }

  /// Get reports by custodian
  Future<List<PettyCashReport>> getReportsByCustodian(
      String custodianId) async {
    return await _firestoreService.getReportsByCustodian(custodianId);
  }

  /// Get reports by department
  Future<List<PettyCashReport>> getReportsByDepartment(
      String department) async {
    return await _firestoreService.getReportsByDepartment(department);
  }

  /// Get a single report
  Future<PettyCashReport?> getReport(String reportId) async {
    return await _firestoreService.getReport(reportId);
  }

  /// Submit a report for approval
  Future<void> submitReport(String reportId) async {
    final report = await _firestoreService.getReport(reportId);
    if (report != null) {
      final updated =
          report.copyWith(status: ReportStatus.submitted.name, updatedAt: DateTime.now());
      await _firestoreService.updateReport(updated);
    }
  }

  /// Approve a report
  Future<void> approveReport(String reportId) async {
    final report = await _firestoreService.getReport(reportId);
    if (report != null) {
      final updated =
          report.copyWith(status: ReportStatus.approved.name, updatedAt: DateTime.now());
      await _firestoreService.updateReport(updated);
    }
  }

  /// Close a report
  Future<void> closeReport(String reportId) async {
    final report = await _firestoreService.getReport(reportId);
    if (report != null) {
      final updated =
          report.copyWith(status: ReportStatus.closed.name, updatedAt: DateTime.now());
      await _firestoreService.updateReport(updated);
    }
  }

  /// Recalculate report totals
  Future<void> recalculateTotals(String reportId) async {
    final report = await _firestoreService.getReport(reportId);
    if (report != null) {
      final transactions =
          await _firestoreService.getTransactionsByReportId(reportId);
      final updated = report.calculateTotals(transactions);
      await _firestoreService.updateReport(updated);
    }
  }

  /// Get report with its transactions
  Future<ReportWithTransactions?> getReportWithTransactions(
      String reportId) async {
    final report = await _firestoreService.getReport(reportId);
    if (report == null) return null;

    final transactions =
        await _firestoreService.getTransactionsByReportId(reportId);
    return ReportWithTransactions(report: report, transactions: transactions);
  }

  /// Search reports
  Future<List<PettyCashReport>> searchReports(String query) async {
    return await _firestoreService.searchReports(query);
  }
}

class ReportWithTransactions {
  final PettyCashReport report;
  final List<app.Transaction> transactions;

  ReportWithTransactions({
    required this.report,
    required this.transactions,
  });
}
