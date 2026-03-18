import 'package:flutter/foundation.dart';
import '../models/medical_bill_reimbursement.dart';
import '../models/user.dart';
import '../services/medical_bill_reimbursement_service.dart';
import '../utils/logger.dart';

class MedicalBillReimbursementProvider extends ChangeNotifier {
  final MedicalBillReimbursementService _service = MedicalBillReimbursementService();

  List<MedicalBillReimbursement> _reimbursements = [];
  MedicalBillReimbursement? _selectedReimbursement;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<MedicalBillReimbursement> get reimbursements => _reimbursements;
  MedicalBillReimbursement? get selectedReimbursement => _selectedReimbursement;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Filter helpers
  List<MedicalBillReimbursement> get draftReimbursements =>
      _reimbursements.where((r) => r.status == 'draft').toList();

  List<MedicalBillReimbursement> get submittedReimbursements =>
      _reimbursements.where((r) => r.status == 'submitted').toList();

  List<MedicalBillReimbursement> get approvedReimbursements =>
      _reimbursements.where((r) => r.status == 'approved').toList();

  List<MedicalBillReimbursement> get rejectedReimbursements =>
      _reimbursements.where((r) => r.status == 'rejected').toList();

  List<MedicalBillReimbursement> get closedReimbursements =>
      _reimbursements.where((r) => r.status == 'closed').toList();

  List<MedicalBillReimbursement> get pendingApprovalReimbursements =>
      submittedReimbursements;

  // Statistics
  double get totalReimbursementAmount =>
      _reimbursements.fold(0, (sum, r) => sum + r.totalReimbursement);

  double get approvedReimbursementAmount =>
      approvedReimbursements.fold(0, (sum, r) => sum + r.totalReimbursement);

  int get pendingApprovalCount => submittedReimbursements.length;

  /// Load all reimbursements
  Future<void> loadReimbursements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reimbursements = await _service.getAllReimbursements();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load medical bill reimbursements: $e';
      _isLoading = false;
      AppLogger.severe('Error loading medical bill reimbursements: $e');
      notifyListeners();
    }
  }

  /// Load reimbursements by user
  Future<void> loadReimbursementsByUser(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reimbursements = await _service.getReimbursementsByRequester(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load medical bill reimbursements: $e';
      _isLoading = false;
      AppLogger.severe('Error loading reimbursements by user: $e');
      notifyListeners();
    }
  }

  /// Load a single reimbursement
  Future<MedicalBillReimbursement?> loadReimbursement(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedReimbursement = await _service.getReimbursement(id);
      _isLoading = false;
      notifyListeners();
      return _selectedReimbursement;
    } catch (e) {
      _errorMessage = 'Failed to load medical bill reimbursement: $e';
      _isLoading = false;
      AppLogger.severe('Error loading medical bill reimbursement: $e');
      notifyListeners();
      return null;
    }
  }

  /// Create a new reimbursement
  Future<MedicalBillReimbursement?> createReimbursement({
    required User requester,
    required String department,
    required String subject,
    required List<MedicalClaimItem> claimItems,
    DateTime? reportDate,
    String? notes,
    String? paidTo,
    List<String>? supportDocumentUrls,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final reimbursement = await _service.createReimbursement(
        requester: requester,
        department: department,
        subject: subject,
        claimItems: claimItems,
        reportDate: reportDate,
        notes: notes,
        paidTo: paidTo,
        supportDocumentUrls: supportDocumentUrls,
      );

      _reimbursements.insert(0, reimbursement);
      _isLoading = false;
      notifyListeners();
      return reimbursement;
    } catch (e) {
      _errorMessage = 'Failed to create medical bill reimbursement: $e';
      _isLoading = false;
      AppLogger.severe('Error creating medical bill reimbursement: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update a reimbursement
  Future<bool> updateReimbursement(MedicalBillReimbursement reimbursement) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.updateReimbursement(reimbursement);

      // Update local list
      final index = _reimbursements.indexWhere((r) => r.id == reimbursement.id);
      if (index != -1) {
        _reimbursements[index] = reimbursement;
      }

      if (_selectedReimbursement?.id == reimbursement.id) {
        _selectedReimbursement = reimbursement;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update medical bill reimbursement: $e';
      _isLoading = false;
      AppLogger.severe('Error updating medical bill reimbursement: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete a reimbursement
  Future<bool> deleteReimbursement(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteReimbursement(id);

      _reimbursements.removeWhere((r) => r.id == id);
      if (_selectedReimbursement?.id == id) {
        _selectedReimbursement = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete medical bill reimbursement: $e';
      _isLoading = false;
      AppLogger.severe('Error deleting medical bill reimbursement: $e');
      notifyListeners();
      return false;
    }
  }

  /// Submit for approval
  Future<bool> submitReimbursement(String id, String submittedBy) async {
    try {
      await _service.submitReimbursement(id, submittedBy);
      await loadReimbursements();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit medical bill reimbursement: $e';
      AppLogger.severe('Error submitting medical bill reimbursement: $e');
      notifyListeners();
      return false;
    }
  }

  /// Approve reimbursement
  Future<bool> approveReimbursement(
    String id,
    String approvedBy,
    String approverName,
  ) async {
    try {
      await _service.approveReimbursement(id, approvedBy, approverName);
      await loadReimbursements();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve medical bill reimbursement: $e';
      AppLogger.severe('Error approving medical bill reimbursement: $e');
      notifyListeners();
      return false;
    }
  }

  /// Reject reimbursement
  Future<bool> rejectReimbursement(String id, String reason) async {
    try {
      await _service.rejectReimbursement(id, reason);
      await loadReimbursements();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject medical bill reimbursement: $e';
      AppLogger.severe('Error rejecting medical bill reimbursement: $e');
      notifyListeners();
      return false;
    }
  }

  /// Close reimbursement
  Future<bool> closeReimbursement(String id) async {
    try {
      await _service.closeReimbursement(id);
      await loadReimbursements();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to close medical bill reimbursement: $e';
      AppLogger.severe('Error closing medical bill reimbursement: $e');
      notifyListeners();
      return false;
    }
  }

  /// Revert to draft
  Future<bool> revertToDraft(String id) async {
    try {
      await _service.revertToDraft(id);
      await loadReimbursements();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to revert medical bill reimbursement to draft: $e';
      AppLogger.severe('Error reverting medical bill reimbursement to draft: $e');
      notifyListeners();
      return false;
    }
  }

  /// Set selected reimbursement
  void setSelectedReimbursement(MedicalBillReimbursement? reimbursement) {
    _selectedReimbursement = reimbursement;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _reimbursements = [];
    _selectedReimbursement = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
