import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/petty_cash_report.dart';
import '../models/project_report.dart';
import '../models/transaction.dart' as app;
import '../models/traveling_report.dart';
import '../models/traveling_per_diem_entry.dart';
import '../models/income_report.dart';
import '../models/purchase_requisition.dart';
import '../utils/logger.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection('reports');
  CollectionReference<Map<String, dynamic>> get _projectReportsCollection =>
      _firestore.collection('project_reports');
  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _firestore.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _travelingReportsCollection =>
      _firestore.collection('traveling_reports');
  CollectionReference<Map<String, dynamic>>
  get _travelingPerDiemEntriesCollection =>
      _firestore.collection('traveling_per_diem_entries');
  CollectionReference<Map<String, dynamic>> get _incomeReportsCollection =>
      _firestore.collection('income_reports');
  CollectionReference<Map<String, dynamic>> get _incomeEntriesCollection =>
      _firestore.collection('income_entries');
  CollectionReference<Map<String, dynamic>>
  get _purchaseRequisitionsCollection =>
      _firestore.collection('purchase_requisitions');
  CollectionReference<Map<String, dynamic>>
  get _purchaseRequisitionItemsCollection =>
      _firestore.collection('purchase_requisition_items');

  // ===== USER OPERATIONS =====

  Future<User?> getUser(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      return doc.exists ? User.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting user: $e');
      rethrow;
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      final snapshot = await _usersCollection.get();
      return snapshot.docs.map((doc) => User.fromFirestore(doc)).toList();
    } catch (e) {
      AppLogger.severe('Error getting all users: $e');
      rethrow;
    }
  }

  Future<void> saveUser(User user) async {
    try {
      await _usersCollection.doc(user.id).set(user.toFirestore());
    } catch (e) {
      AppLogger.severe('Error saving user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      final updated = user.copyWith(updatedAt: DateTime.now());
      await _usersCollection.doc(user.id).update(updated.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _usersCollection.doc(userId).delete();
    } catch (e) {
      AppLogger.severe('Error deleting user: $e');
      rethrow;
    }
  }

  // ===== REPORT OPERATIONS =====

  Future<PettyCashReport?> getReport(String reportId) async {
    try {
      final doc = await _reportsCollection.doc(reportId).get();
      return doc.exists ? PettyCashReport.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting report: $e');
      rethrow;
    }
  }

  Future<List<PettyCashReport>> getAllReports() async {
    try {
      final snapshot = await _reportsCollection
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PettyCashReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting all reports: $e');
      rethrow;
    }
  }

  Future<List<PettyCashReport>> getReportsByStatus(String status) async {
    try {
      final snapshot = await _reportsCollection
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PettyCashReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting reports by status: $e');
      rethrow;
    }
  }

  Future<List<PettyCashReport>> getReportsByCustodian(
    String custodianId,
  ) async {
    try {
      final snapshot = await _reportsCollection
          .where('custodianId', isEqualTo: custodianId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PettyCashReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting reports by custodian: $e');
      rethrow;
    }
  }

  Future<List<PettyCashReport>> getReportsByDepartment(
    String department,
  ) async {
    try {
      final snapshot = await _reportsCollection
          .where('department', isEqualTo: department)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PettyCashReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting reports by department: $e');
      rethrow;
    }
  }

  Future<void> saveReport(PettyCashReport report) async {
    try {
      await _reportsCollection.doc(report.id).set(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error saving report: $e');
      rethrow;
    }
  }

  Future<void> updateReport(PettyCashReport report) async {
    try {
      await _reportsCollection.doc(report.id).update(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating report: $e');
      rethrow;
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      // Get and delete associated transactions first
      final transactions = await getTransactionsByReportId(reportId);
      for (var transaction in transactions) {
        await deleteTransaction(transaction.id);
      }
      // Then delete the report
      await _reportsCollection.doc(reportId).delete();
    } catch (e) {
      AppLogger.severe('Error deleting report: $e');
      rethrow;
    }
  }

  // Stream for real-time updates
  Stream<List<PettyCashReport>> reportsStream() {
    return _reportsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PettyCashReport.fromFirestore(doc))
              .toList(),
        );
  }

  // ===== TRANSACTION OPERATIONS =====

  Future<app.Transaction?> getTransaction(String transactionId) async {
    try {
      final doc = await _transactionsCollection.doc(transactionId).get();
      return doc.exists ? app.Transaction.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting transaction: $e');
      rethrow;
    }
  }

  Future<List<app.Transaction>> getAllTransactions() async {
    try {
      final snapshot = await _transactionsCollection
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => app.Transaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting all transactions: $e');
      rethrow;
    }
  }

  Future<List<app.Transaction>> getTransactionsByReportId(
    String reportId,
  ) async {
    try {
      final snapshot = await _transactionsCollection
          .where('reportId', isEqualTo: reportId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => app.Transaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting transactions by report: $e');
      rethrow;
    }
  }

  Future<List<app.Transaction>> getTransactionsByStatus(String status) async {
    try {
      final snapshot = await _transactionsCollection
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => app.Transaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting transactions by status: $e');
      rethrow;
    }
  }

  Future<void> saveTransaction(app.Transaction transaction) async {
    try {
      await _transactionsCollection
          .doc(transaction.id)
          .set(transaction.toFirestore());
    } catch (e) {
      AppLogger.severe('Error saving transaction: $e');
      rethrow;
    }
  }

  Future<void> updateTransaction(app.Transaction transaction) async {
    try {
      await _transactionsCollection
          .doc(transaction.id)
          .update(transaction.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _transactionsCollection.doc(transactionId).delete();
    } catch (e) {
      AppLogger.severe('Error deleting transaction: $e');
      rethrow;
    }
  }

  // Stream for real-time updates
  Stream<List<app.Transaction>> transactionsByReportStream(String reportId) {
    return _transactionsCollection
        .where('reportId', isEqualTo: reportId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => app.Transaction.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<app.Transaction>> allTransactionsStream() {
    return _transactionsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => app.Transaction.fromFirestore(doc))
              .toList(),
        );
  }

  // ===== SEARCH OPERATIONS =====

  Future<List<PettyCashReport>> searchReports(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      final allReports = await getAllReports();

      // Client-side filtering (Firestore doesn't support full-text search)
      return allReports.where((report) {
        return report.reportNumber.toLowerCase().contains(lowerQuery) ||
            report.department.toLowerCase().contains(lowerQuery) ||
            report.custodianName.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      AppLogger.severe('Error searching reports: $e');
      rethrow;
    }
  }

  // ===== BATCH OPERATIONS =====

  Future<void> batchUpdateReports(List<PettyCashReport> reports) async {
    try {
      final batch = _firestore.batch();
      for (var report in reports) {
        batch.update(_reportsCollection.doc(report.id), report.toFirestore());
      }
      await batch.commit();
    } catch (e) {
      AppLogger.severe('Error batch updating reports: $e');
      rethrow;
    }
  }

  Future<void> batchUpdateTransactions(
    List<app.Transaction> transactions,
  ) async {
    try {
      final batch = _firestore.batch();
      for (var transaction in transactions) {
        batch.update(
          _transactionsCollection.doc(transaction.id),
          transaction.toFirestore(),
        );
      }
      await batch.commit();
    } catch (e) {
      AppLogger.severe('Error batch updating transactions: $e');
      rethrow;
    }
  }

  // ===== PROJECT REPORT OPERATIONS =====

  Future<ProjectReport?> getProjectReport(String reportId) async {
    try {
      final doc = await _projectReportsCollection.doc(reportId).get();
      return doc.exists ? ProjectReport.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting project report: $e');
      rethrow;
    }
  }

  Future<List<ProjectReport>> getAllProjectReports() async {
    try {
      final snapshot = await _projectReportsCollection
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ProjectReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting all project reports: $e');
      rethrow;
    }
  }

  Future<List<ProjectReport>> getProjectReportsByStatus(String status) async {
    try {
      final snapshot = await _projectReportsCollection
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ProjectReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting project reports by status: $e');
      rethrow;
    }
  }

  Future<List<ProjectReport>> getProjectReportsByCustodian(
    String custodianId,
  ) async {
    try {
      final snapshot = await _projectReportsCollection
          .where('custodianId', isEqualTo: custodianId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ProjectReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting project reports by custodian: $e');
      rethrow;
    }
  }

  Future<List<ProjectReport>> getProjectReportsByProjectName(
    String projectName,
  ) async {
    try {
      final snapshot = await _projectReportsCollection
          .where('projectName', isEqualTo: projectName)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ProjectReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting project reports by project name: $e');
      rethrow;
    }
  }

  Future<ProjectReport> createProjectReport({
    required String projectName,
    required double budgetAmount,
    required DateTime startDate,
    required DateTime endDate,
    required User custodian,
    String? description,
  }) async {
    try {
      // Generate project report number
      final now = DateTime.now();
      final formatter = DateFormat('yyyyMM');
      final existingReports = await getAllProjectReports();
      final count =
          existingReports
              .where((r) => r.id.startsWith('PROJ-${formatter.format(now)}'))
              .length +
          1;
      final projectNumber =
          'PROJ-${formatter.format(now)}-${count.toString().padLeft(3, '0')}';

      final projectReport = ProjectReport(
        id: const Uuid().v4(),
        reportNumber: projectNumber,
        projectName: projectName,
        reportName: projectName, // Use project name as report name
        budget: budgetAmount,
        openingBalance: budgetAmount,
        startDate: startDate,
        endDate: endDate,
        custodianId: custodian.id,
        custodianName: custodian.name,
        status: 'draft',
        createdAt: now,
        description: description,
      );

      await _projectReportsCollection
          .doc(projectReport.id)
          .set(projectReport.toFirestore());
      return projectReport;
    } catch (e) {
      AppLogger.severe('Error creating project report: $e');
      rethrow;
    }
  }

  Future<void> saveProjectReport(ProjectReport report) async {
    try {
      await _projectReportsCollection.doc(report.id).set(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error saving project report: $e');
      rethrow;
    }
  }

  Future<void> updateProjectReport(ProjectReport report) async {
    try {
      await _projectReportsCollection
          .doc(report.id)
          .update(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating project report: $e');
      rethrow;
    }
  }

  Future<void> deleteProjectReport(String reportId) async {
    try {
      // Get and delete associated transactions first
      // Don't use orderBy to avoid needing composite index for deletion
      final snapshot = await _transactionsCollection
          .where('projectId', isEqualTo: reportId)
          .get();

      for (var doc in snapshot.docs) {
        await deleteTransaction(doc.id);
      }
      // Then delete the report
      await _projectReportsCollection.doc(reportId).delete();
    } catch (e) {
      AppLogger.severe('Error deleting project report: $e');
      rethrow;
    }
  }

  // Stream for real-time updates
  Stream<List<ProjectReport>> projectReportsStream() {
    return _projectReportsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProjectReport.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<app.Transaction>> getTransactionsByProjectId(
    String projectId,
  ) async {
    try {
      final snapshot = await _transactionsCollection
          .where('projectId', isEqualTo: projectId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => app.Transaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting transactions by project: $e');
      rethrow;
    }
  }

  Future<void> batchUpdateProjectReports(List<ProjectReport> reports) async {
    try {
      final batch = _firestore.batch();
      for (var report in reports) {
        batch.update(
          _projectReportsCollection.doc(report.id),
          report.toFirestore(),
        );
      }
      await batch.commit();
    } catch (e) {
      AppLogger.severe('Error batch updating project reports: $e');
      rethrow;
    }
  }

  // ===== TRAVELING REPORT OPERATIONS =====

  String generateTravelingReportNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final uuid = const Uuid().v4().substring(0, 3).toUpperCase();
    return 'TR-$dateStr-$uuid';
  }

  Future<TravelingReport?> getTravelingReport(String reportId) async {
    try {
      final doc = await _travelingReportsCollection.doc(reportId).get();
      return doc.exists ? TravelingReport.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting traveling report: $e');
      rethrow;
    }
  }

  Future<List<TravelingReport>> getAllTravelingReports() async {
    try {
      final snapshot = await _travelingReportsCollection.get();
      return snapshot.docs
          .map((doc) => TravelingReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting all traveling reports: $e');
      rethrow;
    }
  }

  Future<List<TravelingReport>> getTravelingReportsByReporter(
    String reporterId,
  ) async {
    try {
      final snapshot = await _travelingReportsCollection
          .where('reporterId', isEqualTo: reporterId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TravelingReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting traveling reports by reporter: $e');
      rethrow;
    }
  }

  Future<List<TravelingReport>> getTravelingReportsByStatus(
    String status,
  ) async {
    try {
      final snapshot = await _travelingReportsCollection
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TravelingReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting traveling reports by status: $e');
      rethrow;
    }
  }

  Future<List<TravelingReport>> getTravelingReportsByDepartment(
    String department,
  ) async {
    try {
      final snapshot = await _travelingReportsCollection
          .where('department', isEqualTo: department)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TravelingReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting traveling reports by department: $e');
      rethrow;
    }
  }

  Stream<List<TravelingReport>> travelingReportsStream() {
    return _travelingReportsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TravelingReport.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<TravelingReport>> travelingReportsByReporterStream(
    String reporterId,
  ) {
    return _travelingReportsCollection
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TravelingReport.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> saveTravelingReport(TravelingReport report) async {
    try {
      await _travelingReportsCollection
          .doc(report.id)
          .set(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error saving traveling report: $e');
      rethrow;
    }
  }

  Future<void> updateTravelingReport(TravelingReport report) async {
    try {
      await _travelingReportsCollection
          .doc(report.id)
          .update(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating traveling report: $e');
      rethrow;
    }
  }

  Future<void> deleteTravelingReport(String reportId) async {
    try {
      // Delete all per diem entries associated with this report
      final entriesSnapshot = await _travelingPerDiemEntriesCollection
          .where('reportId', isEqualTo: reportId)
          .get();

      final batch = _firestore.batch();
      for (var doc in entriesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_travelingReportsCollection.doc(reportId));
      await batch.commit();
    } catch (e) {
      AppLogger.severe('Error deleting traveling report: $e');
      rethrow;
    }
  }

  Future<void> submitTravelingReport(String reportId, String userId) async {
    try {
      await _travelingReportsCollection.doc(reportId).update({
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error submitting traveling report: $e');
      rethrow;
    }
  }

  Future<void> approveTravelingReport(
    String reportId,
    String approverName,
  ) async {
    try {
      await _travelingReportsCollection.doc(reportId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approverName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error approving traveling report: $e');
      rethrow;
    }
  }

  Future<void> rejectTravelingReport(
    String reportId,
    String rejectionReason,
  ) async {
    try {
      await _travelingReportsCollection.doc(reportId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error rejecting traveling report: $e');
      rethrow;
    }
  }

  Future<void> revertTravelingReportToDraft(String reportId) async {
    try {
      await _travelingReportsCollection.doc(reportId).update({
        'status': 'draft',
        'submittedAt': null,
        'submittedBy': null,
        'approvedAt': null,
        'approvedBy': null,
        'rejectionReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error reverting traveling report to draft: $e');
      rethrow;
    }
  }

  // ===== TRAVELING PER DIEM ENTRY OPERATIONS =====

  Future<TravelingPerDiemEntry?> getTravelingPerDiemEntry(
    String entryId,
  ) async {
    try {
      final doc = await _travelingPerDiemEntriesCollection.doc(entryId).get();
      return doc.exists ? TravelingPerDiemEntry.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting traveling per diem entry: $e');
      rethrow;
    }
  }

  Future<List<TravelingPerDiemEntry>> getPerDiemEntriesByReport(
    String reportId,
  ) async {
    try {
      final snapshot = await _travelingPerDiemEntriesCollection
          .where('reportId', isEqualTo: reportId)
          .orderBy('date', descending: false)
          .get();
      return snapshot.docs
          .map((doc) => TravelingPerDiemEntry.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting per diem entries by report: $e');
      rethrow;
    }
  }

  Stream<List<TravelingPerDiemEntry>> perDiemEntriesByReportStream(
    String reportId,
  ) {
    return _travelingPerDiemEntriesCollection
        .where('reportId', isEqualTo: reportId)
        .orderBy('date', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TravelingPerDiemEntry.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> saveTravelingPerDiemEntry(TravelingPerDiemEntry entry) async {
    try {
      await _travelingPerDiemEntriesCollection
          .doc(entry.id)
          .set(entry.toFirestore());

      // Recalculate report totals
      await _recalculateTravelingReportTotals(entry.reportId);
    } catch (e) {
      AppLogger.severe('Error saving traveling per diem entry: $e');
      rethrow;
    }
  }

  Future<void> updateTravelingPerDiemEntry(TravelingPerDiemEntry entry) async {
    try {
      await _travelingPerDiemEntriesCollection
          .doc(entry.id)
          .update(entry.toFirestore());

      // Recalculate report totals
      await _recalculateTravelingReportTotals(entry.reportId);
    } catch (e) {
      AppLogger.severe('Error updating traveling per diem entry: $e');
      rethrow;
    }
  }

  Future<void> deleteTravelingPerDiemEntry(String entryId) async {
    try {
      final entry = await getTravelingPerDiemEntry(entryId);
      if (entry != null) {
        await _travelingPerDiemEntriesCollection.doc(entryId).delete();
        // Recalculate report totals
        await _recalculateTravelingReportTotals(entry.reportId);
      }
    } catch (e) {
      AppLogger.severe('Error deleting traveling per diem entry: $e');
      rethrow;
    }
  }

  Future<void> _recalculateTravelingReportTotals(String reportId) async {
    try {
      final entries = await getPerDiemEntriesByReport(reportId);
      final perDiemTotal = entries.fold<double>(
        0.0,
        (total, entry) => total + entry.dailyTotalAllMembers,
      );
      final perDiemDays = entries.length;

      await _travelingReportsCollection.doc(reportId).update({
        'perDiemTotal': perDiemTotal,
        'perDiemDays': perDiemDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error recalculating traveling report totals: $e');
      rethrow;
    }
  }

  // ===== INCOME REPORT OPERATIONS =====

  /// Generate unique income report number
  Future<String> generateIncomeReportNumber() async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final prefix = 'IR-$dateStr';

    // Get existing reports with same prefix
    final snapshot = await _incomeReportsCollection
        .where('reportNumber', isGreaterThanOrEqualTo: prefix)
        .where('reportNumber', isLessThan: '$prefix\uf8ff')
        .get();

    final nextNum = snapshot.docs.length + 1;
    return '$prefix-${nextNum.toString().padLeft(3, '0')}';
  }

  /// Create a new income report
  Future<IncomeReport> createIncomeReport({
    required String reportName,
    required String department,
    required String createdById,
    required String createdByName,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? description,
  }) async {
    try {
      final reportNumber = await generateIncomeReportNumber();
      final docRef = _incomeReportsCollection.doc();

      final report = IncomeReport(
        id: docRef.id,
        reportNumber: reportNumber,
        reportName: reportName,
        department: department,
        createdById: createdById,
        createdByName: createdByName,
        periodStart: periodStart,
        periodEnd: periodEnd,
        totalIncome: 0,
        status: 'draft',
        description: description,
        createdAt: DateTime.now(),
      );

      await docRef.set(report.toFirestore());
      return report;
    } catch (e) {
      AppLogger.severe('Error creating income report: $e');
      rethrow;
    }
  }

  /// Get all income reports
  Future<List<IncomeReport>> getAllIncomeReports() async {
    try {
      final snapshot = await _incomeReportsCollection
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => IncomeReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting all income reports: $e');
      rethrow;
    }
  }

  /// Get income reports by user
  Future<List<IncomeReport>> getIncomeReportsByUser(String userId) async {
    try {
      final snapshot = await _incomeReportsCollection
          .where('createdById', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => IncomeReport.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting income reports by user: $e');
      rethrow;
    }
  }

  /// Get a single income report
  Future<IncomeReport?> getIncomeReport(String reportId) async {
    try {
      final doc = await _incomeReportsCollection.doc(reportId).get();
      return doc.exists ? IncomeReport.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting income report: $e');
      rethrow;
    }
  }

  /// Update an income report
  Future<void> updateIncomeReport(IncomeReport report) async {
    try {
      await _incomeReportsCollection.doc(report.id).update(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating income report: $e');
      rethrow;
    }
  }

  /// Delete an income report and its entries
  Future<void> deleteIncomeReport(String reportId) async {
    try {
      // Delete all entries associated with the report
      final entriesSnapshot = await _incomeEntriesCollection
          .where('reportId', isEqualTo: reportId)
          .get();

      final batch = _firestore.batch();
      for (final doc in entriesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_incomeReportsCollection.doc(reportId));
      await batch.commit();
    } catch (e) {
      AppLogger.severe('Error deleting income report: $e');
      rethrow;
    }
  }

  /// Submit an income report for approval
  Future<void> submitIncomeReport(String reportId) async {
    try {
      await _incomeReportsCollection.doc(reportId).update({
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error submitting income report: $e');
      rethrow;
    }
  }

  /// Approve an income report
  Future<void> approveIncomeReport(String reportId, String approverName) async {
    try {
      await _incomeReportsCollection.doc(reportId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approverName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error approving income report: $e');
      rethrow;
    }
  }

  /// Close an income report
  Future<void> closeIncomeReport(String reportId) async {
    try {
      await _incomeReportsCollection.doc(reportId).update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error closing income report: $e');
      rethrow;
    }
  }

  /// Stream income reports
  Stream<List<IncomeReport>> incomeReportsStream() {
    return _incomeReportsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncomeReport.fromFirestore(doc))
              .toList(),
        );
  }

  // ===== INCOME ENTRY OPERATIONS =====

  /// Add an income entry to a report
  Future<IncomeEntry> addIncomeEntry({
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
      final docRef = _incomeEntriesCollection.doc();

      final entry = IncomeEntry(
        id: docRef.id,
        reportId: reportId,
        dateReceived: dateReceived,
        category: category,
        sourceName: sourceName,
        description: description,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        supportDocumentUrls: supportDocumentUrls,
        createdAt: DateTime.now(),
      );

      await docRef.set(entry.toFirestore());
      await _recalculateIncomeReportTotal(reportId);
      return entry;
    } catch (e) {
      AppLogger.severe('Error adding income entry: $e');
      rethrow;
    }
  }

  /// Get all entries for a report
  Future<List<IncomeEntry>> getIncomeEntriesByReport(String reportId) async {
    try {
      final snapshot = await _incomeEntriesCollection
          .where('reportId', isEqualTo: reportId)
          .orderBy('dateReceived', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => IncomeEntry.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting income entries: $e');
      rethrow;
    }
  }

  /// Update an income entry
  Future<void> updateIncomeEntry(IncomeEntry entry) async {
    try {
      await _incomeEntriesCollection.doc(entry.id).update(entry.toFirestore());
      await _recalculateIncomeReportTotal(entry.reportId);
    } catch (e) {
      AppLogger.severe('Error updating income entry: $e');
      rethrow;
    }
  }

  /// Delete an income entry
  Future<void> deleteIncomeEntry(String entryId, String reportId) async {
    try {
      await _incomeEntriesCollection.doc(entryId).delete();
      await _recalculateIncomeReportTotal(reportId);
    } catch (e) {
      AppLogger.severe('Error deleting income entry: $e');
      rethrow;
    }
  }

  /// Stream income entries for a report
  Stream<List<IncomeEntry>> incomeEntriesStream(String reportId) {
    return _incomeEntriesCollection
        .where('reportId', isEqualTo: reportId)
        .orderBy('dateReceived', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IncomeEntry.fromFirestore(doc))
              .toList(),
        );
  }

  /// Recalculate and update income report total
  Future<void> _recalculateIncomeReportTotal(String reportId) async {
    try {
      final entries = await getIncomeEntriesByReport(reportId);
      final totalIncome = entries.fold<double>(
        0.0,
        (total, entry) => total + entry.amount,
      );

      await _incomeReportsCollection.doc(reportId).update({
        'totalIncome': totalIncome,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error recalculating income report total: $e');
      rethrow;
    }
  }

  // ===== PURCHASE REQUISITION OPERATIONS =====

  /// Generate unique purchase requisition number
  String generatePurchaseRequisitionNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final uuid = const Uuid().v4().substring(0, 3).toUpperCase();
    return 'PR-$dateStr-$uuid';
  }

  /// Get a single purchase requisition
  Future<PurchaseRequisition?> getPurchaseRequisition(
    String requisitionId,
  ) async {
    try {
      final doc =
          await _purchaseRequisitionsCollection.doc(requisitionId).get();
      return doc.exists ? PurchaseRequisition.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting purchase requisition: $e');
      rethrow;
    }
  }

  /// Get all purchase requisitions
  Future<List<PurchaseRequisition>> getAllPurchaseRequisitions() async {
    try {
      final snapshot = await _purchaseRequisitionsCollection
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PurchaseRequisition.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting all purchase requisitions: $e');
      rethrow;
    }
  }

  /// Get purchase requisitions by requester
  Future<List<PurchaseRequisition>> getPurchaseRequisitionsByRequester(
    String requestedBy,
  ) async {
    try {
      final snapshot = await _purchaseRequisitionsCollection
          .where('requestedBy', isEqualTo: requestedBy)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PurchaseRequisition.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting purchase requisitions by requester: $e');
      rethrow;
    }
  }

  /// Get purchase requisitions by status
  Future<List<PurchaseRequisition>> getPurchaseRequisitionsByStatus(
    String status,
  ) async {
    try {
      final snapshot = await _purchaseRequisitionsCollection
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PurchaseRequisition.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting purchase requisitions by status: $e');
      rethrow;
    }
  }

  /// Get purchase requisitions by department
  Future<List<PurchaseRequisition>> getPurchaseRequisitionsByDepartment(
    String department,
  ) async {
    try {
      final snapshot = await _purchaseRequisitionsCollection
          .where('chargeToDepartment', isEqualTo: department)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PurchaseRequisition.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe(
        'Error getting purchase requisitions by department: $e',
      );
      rethrow;
    }
  }

  /// Stream purchase requisitions
  Stream<List<PurchaseRequisition>> purchaseRequisitionsStream() {
    return _purchaseRequisitionsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PurchaseRequisition.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream purchase requisitions by requester
  Stream<List<PurchaseRequisition>> purchaseRequisitionsByRequesterStream(
    String requestedBy,
  ) {
    return _purchaseRequisitionsCollection
        .where('requestedBy', isEqualTo: requestedBy)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PurchaseRequisition.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream a single purchase requisition by ID
  Stream<PurchaseRequisition?> purchaseRequisitionStream(String requisitionId) {
    return _purchaseRequisitionsCollection
        .doc(requisitionId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return PurchaseRequisition.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Save a new purchase requisition
  Future<void> savePurchaseRequisition(PurchaseRequisition requisition) async {
    try {
      await _purchaseRequisitionsCollection
          .doc(requisition.id)
          .set(requisition.toFirestore());
    } catch (e) {
      AppLogger.severe('Error saving purchase requisition: $e');
      rethrow;
    }
  }

  /// Update an existing purchase requisition
  Future<void> updatePurchaseRequisition(
    PurchaseRequisition requisition,
  ) async {
    try {
      await _purchaseRequisitionsCollection
          .doc(requisition.id)
          .update(requisition.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating purchase requisition: $e');
      rethrow;
    }
  }

  /// Delete a purchase requisition and its items
  Future<void> deletePurchaseRequisition(String requisitionId) async {
    try {
      // Delete all items associated with the requisition
      final itemsSnapshot = await _purchaseRequisitionItemsCollection
          .where('requisitionId', isEqualTo: requisitionId)
          .get();

      final batch = _firestore.batch();
      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_purchaseRequisitionsCollection.doc(requisitionId));
      await batch.commit();
    } catch (e) {
      AppLogger.severe('Error deleting purchase requisition: $e');
      rethrow;
    }
  }

  /// Submit a purchase requisition for approval
  Future<void> submitPurchaseRequisition(
    String requisitionId,
    String userId,
  ) async {
    try {
      await _purchaseRequisitionsCollection.doc(requisitionId).update({
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error submitting purchase requisition: $e');
      rethrow;
    }
  }

  /// Approve a purchase requisition
  Future<void> approvePurchaseRequisition(
    String requisitionId,
    String approverName, {
    String? actionNo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': approverName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (actionNo != null) {
        updateData['actionNo'] = actionNo;
      }
      await _purchaseRequisitionsCollection.doc(requisitionId).update(
        updateData,
      );
    } catch (e) {
      AppLogger.severe('Error approving purchase requisition: $e');
      rethrow;
    }
  }

  /// Reject a purchase requisition
  Future<void> rejectPurchaseRequisition(
    String requisitionId,
    String rejectionReason,
  ) async {
    try {
      await _purchaseRequisitionsCollection.doc(requisitionId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error rejecting purchase requisition: $e');
      rethrow;
    }
  }

  /// Revert a purchase requisition to draft
  Future<void> revertPurchaseRequisitionToDraft(String requisitionId) async {
    try {
      await _purchaseRequisitionsCollection.doc(requisitionId).update({
        'status': 'draft',
        'submittedAt': null,
        'submittedBy': null,
        'approvedAt': null,
        'approvedBy': null,
        'actionNo': null,
        'rejectionReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error reverting purchase requisition to draft: $e');
      rethrow;
    }
  }

  // ===== PURCHASE REQUISITION ITEM OPERATIONS =====

  /// Get a single purchase requisition item
  Future<PurchaseRequisitionItem?> getPurchaseRequisitionItem(
    String itemId,
  ) async {
    try {
      final doc =
          await _purchaseRequisitionItemsCollection.doc(itemId).get();
      return doc.exists ? PurchaseRequisitionItem.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting purchase requisition item: $e');
      rethrow;
    }
  }

  /// Get all items for a purchase requisition
  Future<List<PurchaseRequisitionItem>> getPurchaseRequisitionItems(
    String requisitionId,
  ) async {
    try {
      final snapshot = await _purchaseRequisitionItemsCollection
          .where('requisitionId', isEqualTo: requisitionId)
          .orderBy('itemNo', descending: false)
          .get();
      return snapshot.docs
          .map((doc) => PurchaseRequisitionItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting purchase requisition items: $e');
      rethrow;
    }
  }

  /// Stream purchase requisition items
  Stream<List<PurchaseRequisitionItem>> purchaseRequisitionItemsStream(
    String requisitionId,
  ) {
    return _purchaseRequisitionItemsCollection
        .where('requisitionId', isEqualTo: requisitionId)
        .orderBy('itemNo', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PurchaseRequisitionItem.fromFirestore(doc))
              .toList(),
        );
  }

  /// Save a new purchase requisition item
  Future<void> savePurchaseRequisitionItem(
    PurchaseRequisitionItem item,
  ) async {
    try {
      await _purchaseRequisitionItemsCollection
          .doc(item.id)
          .set(item.toFirestore());

      // Recalculate requisition total
      await _recalculatePurchaseRequisitionTotal(item.requisitionId);
    } catch (e) {
      AppLogger.severe('Error saving purchase requisition item: $e');
      rethrow;
    }
  }

  /// Update a purchase requisition item
  Future<void> updatePurchaseRequisitionItem(
    PurchaseRequisitionItem item,
  ) async {
    try {
      await _purchaseRequisitionItemsCollection
          .doc(item.id)
          .update(item.toFirestore());

      // Recalculate requisition total
      await _recalculatePurchaseRequisitionTotal(item.requisitionId);
    } catch (e) {
      AppLogger.severe('Error updating purchase requisition item: $e');
      rethrow;
    }
  }

  /// Delete a purchase requisition item
  Future<void> deletePurchaseRequisitionItem(String itemId) async {
    try {
      final item = await getPurchaseRequisitionItem(itemId);
      if (item != null) {
        await _purchaseRequisitionItemsCollection.doc(itemId).delete();
        // Recalculate requisition total
        await _recalculatePurchaseRequisitionTotal(item.requisitionId);
      }
    } catch (e) {
      AppLogger.severe('Error deleting purchase requisition item: $e');
      rethrow;
    }
  }

  /// Recalculate and update purchase requisition total
  Future<void> _recalculatePurchaseRequisitionTotal(
    String requisitionId,
  ) async {
    try {
      final items = await getPurchaseRequisitionItems(requisitionId);
      final totalAmount = items.fold<double>(
        0.0,
        (total, item) => total + item.totalPrice,
      );

      await _purchaseRequisitionsCollection.doc(requisitionId).update({
        'totalAmount': totalAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.severe('Error recalculating purchase requisition total: $e');
      rethrow;
    }
  }
}
