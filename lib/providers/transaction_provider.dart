import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../models/transaction.dart';
import '../models/enums.dart';
import '../models/approval_record.dart';

class TransactionProvider extends ChangeNotifier {
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

    _transactions = StorageService.getAllTransactions();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTransactionsByReportId(String reportId) async {
    _isLoading = true;
    notifyListeners();

    _transactions = StorageService.getTransactionsByReportId(reportId);
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
    List<String>? attachments,
  }) async {
    final transaction = Transaction(
      id: _uuid.v4(),
      reportId: reportId,
      date: date,
      receiptNo: receiptNo,
      description: description,
      category: category,
      amount: amount,
      paymentMethod: paymentMethod,
      requestorId: requestorId,
      status: TransactionStatus.draft,
      attachments: attachments,
      createdAt: DateTime.now(),
      paidTo: paidTo,
    );

    await StorageService.saveTransaction(transaction);
    await loadTransactionsByReportId(reportId);
    return transaction;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    transaction.updatedAt = DateTime.now();
    await StorageService.saveTransaction(transaction);
    await loadTransactionsByReportId(transaction.reportId);
  }

  Future<void> deleteTransaction(String transactionId) async {
    final transaction = StorageService.getTransaction(transactionId);
    if (transaction != null) {
      await StorageService.deleteTransaction(transactionId);
      await loadTransactionsByReportId(transaction.reportId);
    }
  }

  void selectTransaction(Transaction? transaction) {
    _selectedTransaction = transaction;
    notifyListeners();
  }

  Future<void> submitForApproval(String transactionId) async {
    final transaction = StorageService.getTransaction(transactionId);
    if (transaction != null) {
      transaction.status = TransactionStatus.pendingApproval;
      await updateTransaction(transaction);
    }
  }

  Future<void> approveTransaction(
    String transactionId,
    String approverId,
    String approverName, {
    String? comments,
  }) async {
    final transaction = StorageService.getTransaction(transactionId);
    if (transaction != null) {
      transaction.status = TransactionStatus.approved;
      transaction.approverId = approverId;

      final approvalRecord = ApprovalRecord(
        approverId: approverId,
        approverName: approverName,
        timestamp: DateTime.now(),
        action: 'approved',
        comments: comments,
      );

      final history = transaction.approvalHistory;
      history.add(approvalRecord);
      transaction.approvalHistory = history;

      await updateTransaction(transaction);
    }
  }

  Future<void> rejectTransaction(
    String transactionId,
    String approverId,
    String approverName, {
    String? comments,
  }) async {
    final transaction = StorageService.getTransaction(transactionId);
    if (transaction != null) {
      transaction.status = TransactionStatus.rejected;

      final approvalRecord = ApprovalRecord(
        approverId: approverId,
        approverName: approverName,
        timestamp: DateTime.now(),
        action: 'rejected',
        comments: comments,
      );

      final history = transaction.approvalHistory;
      history.add(approvalRecord);
      transaction.approvalHistory = history;

      await updateTransaction(transaction);
    }
  }

  List<Transaction> getPendingApprovals() {
    return _transactions
        .where((t) => t.status == TransactionStatus.pendingApproval)
        .toList();
  }

  List<Transaction> getApprovedTransactions() {
    return _transactions
        .where((t) => t.status == TransactionStatus.approved)
        .toList();
  }
}
