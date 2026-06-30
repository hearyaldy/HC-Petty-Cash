import 'package:flutter/foundation.dart';
import '../models/expense_claim.dart';
import '../models/user.dart';
import '../services/expense_claim_service.dart';
import '../utils/logger.dart';

class ExpenseClaimProvider extends ChangeNotifier {
  final ExpenseClaimService _service = ExpenseClaimService();

  List<ExpenseClaim> _claims = [];
  ExpenseClaim? _selectedClaim;
  bool _isLoading = false;
  String? _errorMessage;

  List<ExpenseClaim> get claims => _claims;
  ExpenseClaim? get selectedClaim => _selectedClaim;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ExpenseClaim> get pendingClaims =>
      _claims.where((c) => c.status == 'pending').toList();

  List<ExpenseClaim> get approvedClaims =>
      _claims.where((c) => c.status == 'approved').toList();

  List<ExpenseClaim> get rejectedClaims =>
      _claims.where((c) => c.status == 'rejected').toList();

  int get pendingCount => pendingClaims.length;

  double get totalApprovedAmount =>
      approvedClaims.fold(0.0, (acc, c) => acc + c.totalAmount);

  Future<void> loadAllClaims() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _claims = await _service.getAllClaims();
    } catch (e) {
      _errorMessage = 'Failed to load expense claims: $e';
      AppLogger.severe('Error loading all expense claims: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadClaimsByUser(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _claims = await _service.getClaimsByRequester(userId);
    } catch (e) {
      _errorMessage = 'Failed to load expense claims: $e';
      AppLogger.severe('Error loading expense claims by user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ExpenseClaim?> loadClaim(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedClaim = await _service.getClaim(id);
      return _selectedClaim;
    } catch (e) {
      _errorMessage = 'Failed to load expense claim: $e';
      AppLogger.severe('Error loading expense claim: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ExpenseClaim?> createClaim({
    required User requester,
    required String title,
    required String purpose,
    required String department,
    required List<ExpenseLineItem> items,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final claim = await _service.createClaim(
        requester: requester,
        title: title,
        purpose: purpose,
        department: department,
        items: items,
        notes: notes,
      );
      _claims.insert(0, claim);
      return claim;
    } catch (e) {
      _errorMessage = 'Failed to create expense claim: $e';
      AppLogger.severe('Error creating expense claim: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteClaim(String id) async {
    try {
      await _service.deleteClaim(id);
      _claims.removeWhere((c) => c.id == id);
      if (_selectedClaim?.id == id) _selectedClaim = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete expense claim: $e';
      AppLogger.severe('Error deleting expense claim: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveClaim(
    String id,
    String approvedBy,
    String approverName,
  ) async {
    try {
      await _service.approveClaim(id, approvedBy, approverName);
      await _refreshClaim(id);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve expense claim: $e';
      AppLogger.severe('Error approving expense claim: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectClaim(String id, String reason) async {
    try {
      await _service.rejectClaim(id, reason);
      await _refreshClaim(id);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject expense claim: $e';
      AppLogger.severe('Error rejecting expense claim: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> _refreshClaim(String id) async {
    final updated = await _service.getClaim(id);
    if (updated != null) {
      final idx = _claims.indexWhere((c) => c.id == id);
      if (idx != -1) _claims[idx] = updated;
      if (_selectedClaim?.id == id) _selectedClaim = updated;
    }
    notifyListeners();
  }

  void setSelectedClaim(ExpenseClaim? claim) {
    _selectedClaim = claim;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clear() {
    _claims = [];
    _selectedClaim = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
