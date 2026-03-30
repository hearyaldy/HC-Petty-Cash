import 'package:uuid/uuid.dart';
import '../models/cash_advance.dart';
import '../models/user.dart';
import '../utils/logger.dart';
import 'firestore_service.dart';

class CashAdvanceService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  /// Create a new cash advance request
  Future<CashAdvance> createAdvance({
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
    String? linkedMinutesId,
    String? linkedMinutesLabel,
    String? linkedActionItemNumber,
    String? linkedActionItemTitle,
    String? linkedActionItemDescription,
    String? linkedActionItemAction,
  }) async {
    try {
      final requestNumber = _firestoreService.generateCashAdvanceNumber();
      final now = DateTime.now();

      final advance = CashAdvance(
        id: _uuid.v4(),
        requestNumber: requestNumber,
        items: items,
        purpose: purpose,
        requestedAmount: requestedAmount,
        requestDate: requestDate ?? now,
        requiredByDate: requiredByDate,
        requesterId: requester.id,
        requesterName: requester.name,
        department: department,
        idNo: idNo,
        status: 'draft',
        createdAt: now,
        companyName: companyName,
        notes: notes,
        supportDocumentUrls: supportDocumentUrls,
        purchaseRequisitionId: purchaseRequisitionId,
        linkedMinutesId: linkedMinutesId,
        linkedMinutesLabel: linkedMinutesLabel,
        linkedActionItemNumber: linkedActionItemNumber,
        linkedActionItemTitle: linkedActionItemTitle,
        linkedActionItemDescription: linkedActionItemDescription,
        linkedActionItemAction: linkedActionItemAction,
      );

      await _firestoreService.saveCashAdvance(advance);
      return advance;
    } catch (e) {
      AppLogger.severe('Error creating cash advance: $e');
      rethrow;
    }
  }

  /// Update an existing cash advance
  Future<void> updateAdvance(CashAdvance advance) async {
    try {
      final updated = advance.copyWith(updatedAt: DateTime.now());
      await _firestoreService.updateCashAdvance(updated);
    } catch (e) {
      AppLogger.severe('Error updating cash advance: $e');
      rethrow;
    }
  }

  /// Delete a cash advance
  Future<void> deleteAdvance(String advanceId) async {
    try {
      await _firestoreService.deleteCashAdvance(advanceId);
    } catch (e) {
      AppLogger.severe('Error deleting cash advance: $e');
      rethrow;
    }
  }

  /// Submit cash advance for approval
  Future<void> submitAdvance(String advanceId, String userId) async {
    try {
      await _firestoreService.submitCashAdvance(advanceId, userId);
    } catch (e) {
      AppLogger.severe('Error submitting cash advance: $e');
      rethrow;
    }
  }

  /// Approve cash advance
  Future<void> approveAdvance(
    String advanceId,
    String approverName, {
    String? actionNo,
  }) async {
    try {
      await _firestoreService.approveCashAdvance(
        advanceId,
        approverName,
        actionNo: actionNo,
      );
    } catch (e) {
      AppLogger.severe('Error approving cash advance: $e');
      rethrow;
    }
  }

  /// Reject cash advance
  Future<void> rejectAdvance(String advanceId, String reason) async {
    try {
      await _firestoreService.rejectCashAdvance(advanceId, reason);
    } catch (e) {
      AppLogger.severe('Error rejecting cash advance: $e');
      rethrow;
    }
  }

  /// Cancel cash advance
  Future<void> cancelAdvance(String advanceId) async {
    try {
      await _firestoreService.cancelCashAdvance(advanceId);
    } catch (e) {
      AppLogger.severe('Error cancelling cash advance: $e');
      rethrow;
    }
  }

  /// Disburse funds for cash advance
  Future<void> disburseAdvance({
    required String advanceId,
    required String disbursedBy,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
  }) async {
    try {
      await _firestoreService.disburseCashAdvance(
        advanceId: advanceId,
        disbursedBy: disbursedBy,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
      );
    } catch (e) {
      AppLogger.severe('Error disbursing cash advance: $e');
      rethrow;
    }
  }

  /// Link cash advance to settlement report
  Future<void> linkToSettlement({
    required String advanceId,
    required String settlementId,
    required double settledAmount,
    required double returnedAmount,
  }) async {
    try {
      await _firestoreService.linkCashAdvanceToSettlement(
        advanceId: advanceId,
        settlementId: settlementId,
        settledAmount: settledAmount,
        returnedAmount: returnedAmount,
      );
    } catch (e) {
      AppLogger.severe('Error linking cash advance to settlement: $e');
      rethrow;
    }
  }

  /// Revert cash advance to draft
  Future<void> revertToDraft(String advanceId) async {
    try {
      await _firestoreService.revertCashAdvanceToDraft(advanceId);
    } catch (e) {
      AppLogger.severe('Error reverting cash advance to draft: $e');
      rethrow;
    }
  }

  /// Get all cash advances
  Future<List<CashAdvance>> getAllAdvances() async {
    try {
      return await _firestoreService.getAllCashAdvances();
    } catch (e) {
      AppLogger.severe('Error getting all cash advances: $e');
      rethrow;
    }
  }

  /// Get cash advance by ID
  Future<CashAdvance?> getAdvance(String advanceId) async {
    try {
      return await _firestoreService.getCashAdvance(advanceId);
    } catch (e) {
      AppLogger.severe('Error getting cash advance: $e');
      rethrow;
    }
  }

  /// Get cash advances by requester
  Future<List<CashAdvance>> getAdvancesByRequester(String requesterId) async {
    try {
      return await _firestoreService.getCashAdvancesByRequester(requesterId);
    } catch (e) {
      AppLogger.severe('Error getting cash advances by requester: $e');
      rethrow;
    }
  }

  /// Get cash advances by status
  Future<List<CashAdvance>> getAdvancesByStatus(String status) async {
    try {
      return await _firestoreService.getCashAdvancesByStatus(status);
    } catch (e) {
      AppLogger.severe('Error getting cash advances by status: $e');
      rethrow;
    }
  }

  /// Get cash advances by department
  Future<List<CashAdvance>> getAdvancesByDepartment(String department) async {
    try {
      return await _firestoreService.getCashAdvancesByDepartment(department);
    } catch (e) {
      AppLogger.severe('Error getting cash advances by department: $e');
      rethrow;
    }
  }

  /// Get advances pending settlement
  Future<List<CashAdvance>> getPendingSettlementAdvances({
    String? requesterId,
  }) async {
    try {
      return await _firestoreService.getPendingSettlementAdvances(
        requesterId: requesterId,
      );
    } catch (e) {
      AppLogger.severe('Error getting pending settlement advances: $e');
      rethrow;
    }
  }

  /// Stream all cash advances
  Stream<List<CashAdvance>> advancesStream() {
    return _firestoreService.cashAdvancesStream();
  }

  /// Stream cash advances by requester
  Stream<List<CashAdvance>> advancesByRequesterStream(String requesterId) {
    return _firestoreService.cashAdvancesByRequesterStream(requesterId);
  }

  /// Stream a single cash advance
  Stream<CashAdvance?> advanceStream(String advanceId) {
    return _firestoreService.cashAdvanceStream(advanceId);
  }
}
