import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/firestore_service.dart';
import '../services/firebase_storage_service.dart';
import '../models/transaction.dart';
import '../models/enums.dart';
import '../models/approval_record.dart';

class TransactionProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final _uuid = const Uuid();
  List<Transaction> _transactions = [];
  Transaction? _selectedTransaction;
  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  Transaction? get selectedTransaction => _selectedTransaction;
  bool get isLoading => _isLoading;

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _firestoreService.getAllTransactions();
    } catch (e) {
      print('Error loading transactions: $e');
      _transactions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTransactionsByReportId(String reportId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _firestoreService.getTransactionsByReportId(reportId);
    } catch (e) {
      print('Error loading transactions for report: $e');
      _transactions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Transaction> createTransaction({
    required String reportId,
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
        print('Error uploading attachments: $e');
        // Continue without attachments if upload fails
      }
    }

    final transaction = Transaction(
      id: _uuid.v4(),
      reportId: reportId,
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
    } catch (e) {
      print('Error saving transaction: $e');
      // Clean up uploaded files if transaction save fails
      if (attachmentUrls.isNotEmpty) {
        await _storageService.deleteMultipleAttachments(attachmentUrls);
      }
      rethrow;
    }

    return transaction;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    try {
      final updated = transaction.copyWith(updatedAt: DateTime.now());
      await _firestoreService.updateTransaction(updated);
      await loadTransactionsByReportId(transaction.reportId);
    } catch (e) {
      print('Error updating transaction: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
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
      }
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }

  void selectTransaction(Transaction? transaction) {
    _selectedTransaction = transaction;
    notifyListeners();
  }

  Future<void> submitForApproval(String transactionId) async {
    try {
      final transaction = await _firestoreService.getTransaction(transactionId);
      if (transaction != null) {
        final updated = transaction.copyWith(
          status: TransactionStatus.pendingApproval.name,
          updatedAt: DateTime.now(),
        );
        await _firestoreService.updateTransaction(updated);
        await loadTransactionsByReportId(transaction.reportId);
      }
    } catch (e) {
      print('Error submitting for approval: $e');
      rethrow;
    }
  }

  Future<void> approveTransaction(
    String transactionId,
    String approverId,
    String approverName, {
    String? comments,
  }) async {
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

        final updatedHistory = [...transaction.approvalHistory, approvalRecord.toMap()];

        final updated = transaction.copyWith(
          status: TransactionStatus.approved.name,
          approverId: approverId,
          approvalHistory: updatedHistory,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updateTransaction(updated);
        await loadTransactionsByReportId(transaction.reportId);
      }
    } catch (e) {
      print('Error approving transaction: $e');
      rethrow;
    }
  }

  Future<void> rejectTransaction(
    String transactionId,
    String approverId,
    String approverName, {
    String? comments,
  }) async {
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

        final updatedHistory = [...transaction.approvalHistory, approvalRecord.toMap()];

        final updated = transaction.copyWith(
          status: TransactionStatus.rejected.name,
          approvalHistory: updatedHistory,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updateTransaction(updated);
        await loadTransactionsByReportId(transaction.reportId);
      }
    } catch (e) {
      print('Error rejecting transaction: $e');
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
}
