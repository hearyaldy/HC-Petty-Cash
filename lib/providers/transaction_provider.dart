import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/firestore_service.dart';
import '../services/firebase_storage_service.dart';
import '../models/transaction.dart';
import '../models/enums.dart';
import '../models/approval_record.dart';
import '../utils/logger.dart';

class TransactionProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final _uuid = const Uuid();
  List<Transaction> _transactions = [];
  Transaction? _selectedTransaction;
  bool _isLoading = false;
  String? _errorMessage;

  List<Transaction> get transactions => _transactions;
  Transaction? get selectedTransaction => _selectedTransaction;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _firestoreService.getAllTransactions();
    } catch (e) {
      _errorMessage = 'Failed to load transactions: ${e.toString()}';
      AppLogger.severe('Error loading transactions: $e');
      _transactions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTransactionsByReportId(String reportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _firestoreService.getTransactionsByReportId(reportId);
    } catch (e) {
      _errorMessage = 'Failed to load transactions for report: ${e.toString()}';
      AppLogger.severe('Error loading transactions for report: $e');
      _transactions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Transaction> createTransaction({
    required String reportId,
    String? projectId,
    required DateTime date,
    required String receiptNo,
    required String description,
    required ExpenseCategory category,
    required double amount,
    required PaymentMethod paymentMethod,
    required String requestorId,
    String? paidTo,
    List<File>? attachmentFiles,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Upload files to Firebase Storage first
    List<String> attachmentUrls = [];
    if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
      final transactionId = _uuid.v4();
      try {
        attachmentUrls = await _storageService.uploadMultipleAttachments(
          transactionId: transactionId,
          files: attachmentFiles,
        );
      } catch (e) {
        AppLogger.warning('Error uploading attachments: $e');
        // Continue without attachments if upload fails
      }
    }

    final transaction = Transaction(
      id: _uuid.v4(),
      reportId: reportId,
      projectId: projectId,
      date: date,
      receiptNo: receiptNo,
      description: description,
      category: category.name,
      amount: amount,
      paymentMethod: paymentMethod.name,
      requestorId: requestorId,
      status: TransactionStatus.draft.name,
      attachmentUrls: attachmentUrls,
      createdAt: DateTime.now(),
      paidTo: paidTo,
    );

    try {
      await _firestoreService.saveTransaction(transaction);
      await loadTransactionsByReportId(reportId);
      // Update financial summary for the report
      await _updateReportFinancialSummary(reportId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save transaction: ${e.toString()}';
      AppLogger.severe('Error saving transaction: $e');
      // Clean up uploaded files if transaction save fails
      if (attachmentUrls.isNotEmpty) {
        await _storageService.deleteMultipleAttachments(attachmentUrls);
      }
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    return transaction;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = transaction.copyWith(updatedAt: DateTime.now());
      await _firestoreService.updateTransaction(updated);
      await loadTransactionsByReportId(transaction.reportId);
      // Update financial summary for the report
      await _updateReportFinancialSummary(transaction.reportId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update transaction: ${e.toString()}';
      AppLogger.severe('Error updating transaction: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final transaction = await _firestoreService.getTransaction(transactionId);
      if (transaction != null) {
        // Delete attachments from Firebase Storage
        if (transaction.attachmentUrls.isNotEmpty) {
          await _storageService.deleteMultipleAttachments(transaction.attachmentUrls);
        }
        // Delete transaction from Firestore
        await _firestoreService.deleteTransaction(transactionId);
        await loadTransactionsByReportId(transaction.reportId);
        // Update financial summary for the report
        await _updateReportFinancialSummary(transaction.reportId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete transaction: ${e.toString()}';
      AppLogger.severe('Error deleting transaction: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void selectTransaction(Transaction? transaction) {
    _selectedTransaction = transaction;
    notifyListeners();
  }

  Future<void> submitForApproval(String transactionId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final transaction = await _firestoreService.getTransaction(transactionId);
      if (transaction != null) {
        final updated = transaction.copyWith(
          status: TransactionStatus.pendingApproval.name,
          updatedAt: DateTime.now(),
        );
        await _firestoreService.updateTransaction(updated);
        await loadTransactionsByReportId(transaction.reportId);
        // Update financial summary for the report
        await _updateReportFinancialSummary(transaction.reportId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to submit for approval: ${e.toString()}';
      AppLogger.severe('Error submitting for approval: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> approveTransaction(
    String transactionId,
    String approverId,
    String approverName, {
    String? comments,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final transaction = await _firestoreService.getTransaction(transactionId);
      if (transaction != null) {
        final approvalRecord = ApprovalRecord(
          approverId: approverId,
          approverName: approverName,
          timestamp: DateTime.now(),
          action: 'approved',
          comments: comments,
        );

        final updatedHistory = [...transaction.approvalHistory, approvalRecord.toJson()];

        final updated = transaction.copyWith(
          status: TransactionStatus.approved.name,
          approverId: approverId,
          approvalHistory: updatedHistory,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updateTransaction(updated);
        await loadTransactionsByReportId(transaction.reportId);
        // Update financial summary for the report
        await _updateReportFinancialSummary(transaction.reportId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to approve transaction: ${e.toString()}';
      AppLogger.severe('Error approving transaction: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> rejectTransaction(
    String transactionId,
    String approverId,
    String approverName, {
    String? comments,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final transaction = await _firestoreService.getTransaction(transactionId);
      if (transaction != null) {
        final approvalRecord = ApprovalRecord(
          approverId: approverId,
          approverName: approverName,
          timestamp: DateTime.now(),
          action: 'rejected',
          comments: comments,
        );

        final updatedHistory = [...transaction.approvalHistory, approvalRecord.toJson()];

        final updated = transaction.copyWith(
          status: TransactionStatus.rejected.name,
          approvalHistory: updatedHistory,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updateTransaction(updated);
        await loadTransactionsByReportId(transaction.reportId);
        // Update financial summary for the report
        await _updateReportFinancialSummary(transaction.reportId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to reject transaction: ${e.toString()}';
      AppLogger.severe('Error rejecting transaction: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  List<Transaction> getPendingApprovals() {
    return _transactions
        .where((t) => t.status == TransactionStatus.pendingApproval.name)
        .toList();
  }

  List<Transaction> getApprovedTransactions() {
    return _transactions
        .where((t) => t.status == TransactionStatus.approved.name)
        .toList();
  }

  // Update financial summary for a report after transaction changes
  Future<void> _updateReportFinancialSummary(String reportId) async {
    try {
      // Get all transactions for the report
      final transactions = await _firestoreService.getTransactionsByReportId(reportId);

      // Get the report
      final report = await _firestoreService.getReport(reportId);
      if (report != null) {
        // Calculate totals based on transactions
        final updatedReport = report.calculateTotals(transactions);

        // Update the report in Firestore
        await _firestoreService.updateReport(updatedReport);
      }
    } catch (e) {
      AppLogger.severe('Error updating report financial summary: $e');
    }
  }
}
