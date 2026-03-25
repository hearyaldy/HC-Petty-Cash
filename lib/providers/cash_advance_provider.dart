import 'package:flutter/foundation.dart';
import '../models/cash_advance.dart';
import '../models/enums.dart';
import '../models/user.dart';
import '../services/cash_advance_service.dart';
import '../utils/logger.dart';

class CashAdvanceProvider extends ChangeNotifier {
  final CashAdvanceService _service = CashAdvanceService();

  List<CashAdvance> _advances = [];
  CashAdvance? _selectedAdvance;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<CashAdvance> get advances => _advances;
  CashAdvance? get selectedAdvance => _selectedAdvance;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Filter helpers
  List<CashAdvance> get draftAdvances =>
      _advances.where((a) => a.status == CashAdvanceStatus.draft.name).toList();

  List<CashAdvance> get submittedAdvances =>
      _advances.where((a) => a.status == CashAdvanceStatus.submitted.name).toList();

  List<CashAdvance> get approvedAdvances =>
      _advances.where((a) => a.status == CashAdvanceStatus.approved.name).toList();

  List<CashAdvance> get disbursedAdvances =>
      _advances.where((a) => a.status == CashAdvanceStatus.disbursed.name).toList();

  List<CashAdvance> get settledAdvances =>
      _advances.where((a) => a.status == CashAdvanceStatus.settled.name).toList();

  List<CashAdvance> get pendingApprovalAdvances => submittedAdvances;

  List<CashAdvance> get pendingSettlementAdvances =>
      _advances.where((a) => a.isPendingSettlement).toList();

  // Statistics
  double get totalRequestedAmount =>
      _advances.fold(0, (sum, a) => sum + a.requestedAmount);

  double get totalDisbursedAmount =>
      _advances.fold(0, (sum, a) => sum + (a.disbursedAmount ?? 0));

  double get totalOutstandingAmount =>
      pendingSettlementAdvances.fold(0, (sum, a) => sum + a.outstandingAmount);

  int get pendingApprovalCount => submittedAdvances.length;

  int get pendingSettlementCount => pendingSettlementAdvances.length;

  /// Load all cash advances
  Future<void> loadAdvances() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _advances = await _service.getAllAdvances();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load cash advances: $e';
      _isLoading = false;
      AppLogger.severe('Error loading cash advances: $e');
      notifyListeners();
    }
  }

  /// Load cash advances by user
  Future<void> loadAdvancesByUser(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _advances = await _service.getAdvancesByRequester(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load cash advances: $e';
      _isLoading = false;
      AppLogger.severe('Error loading cash advances by user: $e');
      notifyListeners();
    }
  }

  /// Load a single cash advance
  Future<CashAdvance?> loadAdvance(String advanceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedAdvance = await _service.getAdvance(advanceId);
      _isLoading = false;
      notifyListeners();
      return _selectedAdvance;
    } catch (e) {
      _errorMessage = 'Failed to load cash advance: $e';
      _isLoading = false;
      AppLogger.severe('Error loading cash advance: $e');
      notifyListeners();
      return null;
    }
  }

  /// Create a new cash advance
  Future<CashAdvance?> createAdvance({
    required String purpose,
    required double requestedAmount,
    required String department,
    required User requester,
    DateTime? requestDate,
    DateTime? requiredByDate,
    String? idNo,
    String? companyName,
    String? notes,
    List<String>? supportDocumentUrls,
    List<CashAdvanceItem>? items,
    String? purchaseRequisitionId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final advance = await _service.createAdvance(
        purpose: purpose,
        requestedAmount: requestedAmount,
        department: department,
        requester: requester,
        requestDate: requestDate,
        requiredByDate: requiredByDate,
        idNo: idNo,
        companyName: companyName,
        notes: notes,
        supportDocumentUrls: supportDocumentUrls,
        items: items,
        purchaseRequisitionId: purchaseRequisitionId,
      );

      _advances.insert(0, advance);
      _isLoading = false;
      notifyListeners();
      return advance;
    } catch (e) {
      _errorMessage = 'Failed to create cash advance: $e';
      _isLoading = false;
      AppLogger.severe('Error creating cash advance: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update a cash advance
  Future<bool> updateAdvance(CashAdvance advance) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.updateAdvance(advance);

      // Update local list
      final index = _advances.indexWhere((a) => a.id == advance.id);
      if (index != -1) {
        _advances[index] = advance;
      }

      if (_selectedAdvance?.id == advance.id) {
        _selectedAdvance = advance;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update cash advance: $e';
      _isLoading = false;
      AppLogger.severe('Error updating cash advance: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete a cash advance
  Future<bool> deleteAdvance(String advanceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteAdvance(advanceId);

      _advances.removeWhere((a) => a.id == advanceId);
      if (_selectedAdvance?.id == advanceId) {
        _selectedAdvance = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete cash advance: $e';
      _isLoading = false;
      AppLogger.severe('Error deleting cash advance: $e');
      notifyListeners();
      return false;
    }
  }

  /// Submit cash advance for approval
  Future<bool> submitAdvance(String advanceId, String userId) async {
    try {
      await _service.submitAdvance(advanceId, userId);
      await loadAdvances();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit cash advance: $e';
      AppLogger.severe('Error submitting cash advance: $e');
      notifyListeners();
      return false;
    }
  }

  /// Approve cash advance
  Future<bool> approveAdvance(
    String advanceId,
    String approverName, {
    String? actionNo,
  }) async {
    try {
      await _service.approveAdvance(advanceId, approverName, actionNo: actionNo);
      await loadAdvances();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve cash advance: $e';
      AppLogger.severe('Error approving cash advance: $e');
      notifyListeners();
      return false;
    }
  }

  /// Reject cash advance
  Future<bool> rejectAdvance(String advanceId, String reason) async {
    try {
      await _service.rejectAdvance(advanceId, reason);
      await loadAdvances();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject cash advance: $e';
      AppLogger.severe('Error rejecting cash advance: $e');
      notifyListeners();
      return false;
    }
  }

  /// Cancel cash advance
  Future<bool> cancelAdvance(String advanceId) async {
    try {
      await _service.cancelAdvance(advanceId);
      await loadAdvances();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel cash advance: $e';
      AppLogger.severe('Error cancelling cash advance: $e');
      notifyListeners();
      return false;
    }
  }

  /// Disburse cash advance
  Future<bool> disburseAdvance({
    required String advanceId,
    required String disbursedBy,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
  }) async {
    try {
      await _service.disburseAdvance(
        advanceId: advanceId,
        disbursedBy: disbursedBy,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
      );
      await loadAdvances();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to disburse cash advance: $e';
      AppLogger.severe('Error disbursing cash advance: $e');
      notifyListeners();
      return false;
    }
  }

  /// Link cash advance to settlement
  Future<bool> linkToSettlement({
    required String advanceId,
    required String settlementId,
    required double settledAmount,
    required double returnedAmount,
  }) async {
    try {
      await _service.linkToSettlement(
        advanceId: advanceId,
        settlementId: settlementId,
        settledAmount: settledAmount,
        returnedAmount: returnedAmount,
      );
      await loadAdvances();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to link cash advance to settlement: $e';
      AppLogger.severe('Error linking cash advance to settlement: $e');
      notifyListeners();
      return false;
    }
  }

  /// Revert cash advance to draft
  Future<bool> revertToDraft(String advanceId) async {
    try {
      await _service.revertToDraft(advanceId);
      await loadAdvances();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to revert cash advance to draft: $e';
      AppLogger.severe('Error reverting cash advance to draft: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get pending settlement advances
  Future<List<CashAdvance>> getPendingSettlementAdvances({
    String? requesterId,
  }) async {
    try {
      return await _service.getPendingSettlementAdvances(
        requesterId: requesterId,
      );
    } catch (e) {
      AppLogger.severe('Error getting pending settlement advances: $e');
      return [];
    }
  }

  /// Get advances by status
  List<CashAdvance> getAdvancesByStatus(CashAdvanceStatus status) {
    return _advances.where((a) => a.status == status.name).toList();
  }

  /// Set selected advance
  void setSelectedAdvance(CashAdvance? advance) {
    _selectedAdvance = advance;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _advances = [];
    _selectedAdvance = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
