import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/petty_cash_report.dart';
import '../models/transaction.dart';
import '../models/enums.dart';
import '../models/user.dart';
import 'storage_service.dart';

class ReportService {
  final _uuid = const Uuid();

  /// Generate a unique report number
  String generateReportNumber() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd');
    final count = StorageService.getAllReports()
            .where((r) => r.reportNumber.startsWith('PCR-${formatter.format(now)}'))
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
    final report = PettyCashReport(
      id: _uuid.v4(),
      reportNumber: generateReportNumber(),
      periodStart: periodStart,
      periodEnd: periodEnd,
      department: department,
      custodianId: custodian.id,
      custodianName: custodian.name,
      openingBalance: openingBalance,
      status: ReportStatus.draft,
      createdAt: DateTime.now(),
      companyName: companyName,
      notes: notes,
    );

    await StorageService.saveReport(report);
    return report;
  }

  /// Update an existing report
  Future<void> updateReport(PettyCashReport report) async {
    report.updatedAt = DateTime.now();
    await StorageService.saveReport(report);
  }

  /// Delete a report and all its transactions
  Future<void> deleteReport(String reportId) async {
    // Delete all transactions associated with this report
    final transactions = StorageService.getTransactionsByReportId(reportId);
    for (var transaction in transactions) {
      await StorageService.deleteTransaction(transaction.id);
    }

    // Delete the report
    await StorageService.deleteReport(reportId);
  }

  /// Get all reports
  List<PettyCashReport> getAllReports() {
    return StorageService.getAllReports();
  }

  /// Get reports by status
  List<PettyCashReport> getReportsByStatus(ReportStatus status) {
    return StorageService.getAllReports()
        .where((r) => r.status == status)
        .toList();
  }

  /// Get reports by custodian
  List<PettyCashReport> getReportsByCustodian(String custodianId) {
    return StorageService.getAllReports()
        .where((r) => r.custodianId == custodianId)
        .toList();
  }

  /// Get reports by department
  List<PettyCashReport> getReportsByDepartment(String department) {
    return StorageService.getAllReports()
        .where((r) => r.department == department)
        .toList();
  }

  /// Submit a report for approval
  Future<void> submitReport(String reportId) async {
    final report = StorageService.getReport(reportId);
    if (report != null) {
      report.status = ReportStatus.submitted;
      await updateReport(report);
    }
  }

  /// Approve a report
  Future<void> approveReport(String reportId) async {
    final report = StorageService.getReport(reportId);
    if (report != null) {
      report.status = ReportStatus.approved;
      await updateReport(report);
    }
  }

  /// Close a report
  Future<void> closeReport(String reportId) async {
    final report = StorageService.getReport(reportId);
    if (report != null) {
      report.status = ReportStatus.closed;
      await updateReport(report);
    }
  }

  /// Recalculate report totals
  Future<void> recalculateTotals(String reportId) async {
    final report = StorageService.getReport(reportId);
    if (report != null) {
      final transactions = StorageService.getTransactionsByReportId(reportId);
      report.calculateTotals(transactions);
      await updateReport(report);
    }
  }

  /// Get report with its transactions
  ReportWithTransactions? getReportWithTransactions(String reportId) {
    final report = StorageService.getReport(reportId);
    if (report == null) return null;

    final transactions = StorageService.getTransactionsByReportId(reportId);
    return ReportWithTransactions(report: report, transactions: transactions);
  }

  /// Search reports
  List<PettyCashReport> searchReports(String query) {
    final lowerQuery = query.toLowerCase();
    return StorageService.getAllReports().where((r) {
      return r.reportNumber.toLowerCase().contains(lowerQuery) ||
          r.department.toLowerCase().contains(lowerQuery) ||
          r.custodianName.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

class ReportWithTransactions {
  final PettyCashReport report;
  final List<Transaction> transactions;

  ReportWithTransactions({
    required this.report,
    required this.transactions,
  });
}
