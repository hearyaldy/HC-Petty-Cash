import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_voucher.dart';

class PaymentVoucherProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<PaymentVoucher> _vouchers = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<PaymentVoucher> get vouchers => _vouchers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<PaymentVoucher> get draftVouchers =>
      _vouchers.where((v) => v.status == 'draft').toList();

  List<PaymentVoucher> get submittedVouchers =>
      _vouchers.where((v) => v.status == 'submitted').toList();

  List<PaymentVoucher> get approvedVouchers =>
      _vouchers.where((v) => v.status == 'approved').toList();

  List<PaymentVoucher> get paidVouchers =>
      _vouchers.where((v) => v.status == 'paid').toList();

  List<PaymentVoucher> get rejectedVouchers =>
      _vouchers.where((v) => v.status == 'rejected').toList();

  double get totalPaidAmount =>
      paidVouchers.fold(0.0, (acc, v) => acc + v.amount);

  double get totalPendingAmount => _vouchers
      .where((v) => v.status == 'submitted' || v.status == 'approved')
      .fold(0.0, (acc, v) => acc + v.amount);

  String _generateVoucherNumber() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final seq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'PV-$year$month$day-$seq';
  }

  Future<void> loadVouchers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('payment_vouchers')
          .orderBy('createdAt', descending: true)
          .get();

      _vouchers = snapshot.docs
          .map((doc) => PaymentVoucher.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = 'Failed to load payment vouchers: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVouchersByUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('payment_vouchers')
          .where('createdById', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _vouchers = snapshot.docs
          .map((doc) => PaymentVoucher.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = 'Failed to load payment vouchers: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentVoucher?> createVoucher({
    required List<VoucherRecipient> recipients,
    required String department,
    required String purpose,
    required double amount,
    required String paymentMethod,
    required String createdById,
    required String createdByName,
    required DateTime voucherDate,
    String? bankName,
    String? accountNumber,
    String? chequeNumber,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final docRef = _firestore.collection('payment_vouchers').doc();

      final voucher = PaymentVoucher(
        id: docRef.id,
        voucherNumber: _generateVoucherNumber(),
        voucherDate: voucherDate,
        recipients: recipients,
        department: department,
        purpose: purpose,
        amount: amount,
        paymentMethod: paymentMethod,
        bankName: bankName,
        accountNumber: accountNumber,
        chequeNumber: chequeNumber,
        status: 'draft',
        createdById: createdById,
        createdByName: createdByName,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(voucher.toFirestore());
      _vouchers.insert(0, voucher);
      notifyListeners();
      return voucher;
    } catch (e) {
      _error = 'Failed to create payment voucher: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateVoucher(PaymentVoucher voucher) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = voucher.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('payment_vouchers')
          .doc(voucher.id)
          .set(updated.toFirestore());

      final index = _vouchers.indexWhere((v) => v.id == voucher.id);
      if (index != -1) {
        _vouchers[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update payment voucher: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteVoucher(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore.collection('payment_vouchers').doc(id).delete();
      _vouchers.removeWhere((v) => v.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete payment voucher: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> revertToDraft(String id) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('payment_vouchers').doc(id).update({
        'status': 'draft',
        'approvedById': FieldValue.delete(),
        'approvedByName': FieldValue.delete(),
        'rejectionReason': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(now),
      });

      final index = _vouchers.indexWhere((v) => v.id == id);
      if (index != -1) {
        _vouchers[index] = _vouchers[index].copyWith(
          status: 'draft',
          updatedAt: now,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to revert voucher to draft: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitVoucher(String id) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('payment_vouchers').doc(id).update({
        'status': 'submitted',
        'updatedAt': Timestamp.fromDate(now),
      });

      final index = _vouchers.indexWhere((v) => v.id == id);
      if (index != -1) {
        _vouchers[index] = _vouchers[index].copyWith(
          status: 'submitted',
          updatedAt: now,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to submit payment voucher: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveVoucher(
      String id, String approverId, String approverName) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('payment_vouchers').doc(id).update({
        'status': 'approved',
        'approvedById': approverId,
        'approvedByName': approverName,
        'updatedAt': Timestamp.fromDate(now),
      });

      final index = _vouchers.indexWhere((v) => v.id == id);
      if (index != -1) {
        _vouchers[index] = _vouchers[index].copyWith(
          status: 'approved',
          approvedById: approverId,
          approvedByName: approverName,
          updatedAt: now,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to approve payment voucher: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectVoucher(String id, String reason) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('payment_vouchers').doc(id).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': Timestamp.fromDate(now),
      });

      final index = _vouchers.indexWhere((v) => v.id == id);
      if (index != -1) {
        _vouchers[index] = _vouchers[index].copyWith(
          status: 'rejected',
          rejectionReason: reason,
          updatedAt: now,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reject payment voucher: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsPaid(String id) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('payment_vouchers').doc(id).update({
        'status': 'paid',
        'paidAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final index = _vouchers.indexWhere((v) => v.id == id);
      if (index != -1) {
        _vouchers[index] = _vouchers[index].copyWith(
          status: 'paid',
          paidAt: now,
          updatedAt: now,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to mark voucher as paid: $e';
      notifyListeners();
      return false;
    }
  }

  PaymentVoucher? getVoucherById(String id) {
    try {
      return _vouchers.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
