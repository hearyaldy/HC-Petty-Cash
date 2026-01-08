import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/petty_cash_report.dart';
import '../models/project_report.dart';
import '../models/transaction.dart' as app;
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
      String custodianId) async {
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
      String department) async {
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
        .map((snapshot) => snapshot.docs
            .map((doc) => PettyCashReport.fromFirestore(doc))
            .toList());
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
      String reportId) async {
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
        .map((snapshot) => snapshot.docs
            .map((doc) => app.Transaction.fromFirestore(doc))
            .toList());
  }

  Stream<List<app.Transaction>> allTransactionsStream() {
    return _transactionsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app.Transaction.fromFirestore(doc))
            .toList());
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
        batch.update(
          _reportsCollection.doc(report.id),
          report.toFirestore(),
        );
      }
      await batch.commit();
    } catch (e) {
      AppLogger.severe('Error batch updating reports: $e');
      rethrow;
    }
  }

  Future<void> batchUpdateTransactions(
      List<app.Transaction> transactions) async {
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
      String custodianId) async {
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
      String projectName) async {
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
      await _projectReportsCollection.doc(report.id).update(report.toFirestore());
    } catch (e) {
      AppLogger.severe('Error updating project report: $e');
      rethrow;
    }
  }

  Future<void> deleteProjectReport(String reportId) async {
    try {
      // Get and delete associated transactions first
      final transactions = await getTransactionsByProjectId(reportId);
      for (var transaction in transactions) {
        await deleteTransaction(transaction.id);
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
        .map((snapshot) => snapshot.docs
            .map((doc) => ProjectReport.fromFirestore(doc))
            .toList());
  }

  Future<List<app.Transaction>> getTransactionsByProjectId(String projectId) async {
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
}
