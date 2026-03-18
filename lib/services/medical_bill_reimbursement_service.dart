import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/medical_bill_reimbursement.dart';
import '../models/user.dart';
import '../utils/logger.dart';

class MedicalBillReimbursementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('medical_bill_reimbursements');

  /// Generate a unique report number (MBR-YYYYMMDD-XXX)
  Future<String> _generateReportNumber() async {
    final today = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(today);
    final prefix = 'MBR-$dateStr-';

    // Get count of reports created today
    final snapshot = await _collection
        .where('reportNumber', isGreaterThanOrEqualTo: prefix)
        .where('reportNumber', isLessThan: '${prefix}Z')
        .get();

    final count = snapshot.docs.length + 1;
    return '$prefix${count.toString().padLeft(3, '0')}';
  }

  /// Get all medical bill reimbursements
  Future<List<MedicalBillReimbursement>> getAllReimbursements() async {
    try {
      final snapshot = await _collection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MedicalBillReimbursement.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting all medical bill reimbursements: $e');
      rethrow;
    }
  }

  /// Get reimbursements by requester
  Future<List<MedicalBillReimbursement>> getReimbursementsByRequester(
    String requesterId,
  ) async {
    try {
      final snapshot = await _collection
          .where('requesterId', isEqualTo: requesterId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MedicalBillReimbursement.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting reimbursements by requester: $e');
      rethrow;
    }
  }

  /// Get a single reimbursement by ID
  Future<MedicalBillReimbursement?> getReimbursement(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      return doc.exists ? MedicalBillReimbursement.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Create a new medical bill reimbursement
  Future<MedicalBillReimbursement> createReimbursement({
    required User requester,
    required String department,
    required String subject,
    required List<MedicalClaimItem> claimItems,
    DateTime? reportDate,
    String? notes,
    String? paidTo,
    List<String>? supportDocumentUrls,
  }) async {
    try {
      final id = _uuid.v4();
      final reportNumber = await _generateReportNumber();
      final now = DateTime.now();

      final reimbursement = MedicalBillReimbursement(
        id: id,
        reportNumber: reportNumber,
        requesterId: requester.id,
        requesterName: requester.name,
        department: department,
        reportDate: reportDate ?? now,
        subject: subject,
        claimItems: claimItems,
        status: 'draft',
        createdAt: now,
        notes: notes,
        paidTo: paidTo,
        supportDocumentUrls: supportDocumentUrls,
      );

      await _collection.doc(id).set(reimbursement.toFirestore());

      AppLogger.info('Created medical bill reimbursement: $reportNumber');
      return reimbursement;
    } catch (e) {
      AppLogger.severe('Error creating medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Update a medical bill reimbursement
  Future<void> updateReimbursement(MedicalBillReimbursement reimbursement) async {
    try {
      final updated = reimbursement.copyWith(updatedAt: DateTime.now());
      await _collection.doc(reimbursement.id).update(updated.toFirestore());
      AppLogger.info('Updated medical bill reimbursement: ${reimbursement.reportNumber}');
    } catch (e) {
      AppLogger.severe('Error updating medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Delete a medical bill reimbursement
  Future<void> deleteReimbursement(String id) async {
    try {
      await _collection.doc(id).delete();
      AppLogger.info('Deleted medical bill reimbursement: $id');
    } catch (e) {
      AppLogger.severe('Error deleting medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Submit for approval
  Future<void> submitReimbursement(String id, String submittedBy) async {
    try {
      await _collection.doc(id).update({
        'status': 'submitted',
        'submittedAt': Timestamp.fromDate(DateTime.now()),
        'submittedBy': submittedBy,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      AppLogger.info('Submitted medical bill reimbursement: $id');
    } catch (e) {
      AppLogger.severe('Error submitting medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Approve reimbursement
  Future<void> approveReimbursement(
    String id,
    String approvedBy,
    String approverName,
  ) async {
    try {
      await _collection.doc(id).update({
        'status': 'approved',
        'approvedAt': Timestamp.fromDate(DateTime.now()),
        'approvedBy': approvedBy,
        'approverName': approverName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      AppLogger.info('Approved medical bill reimbursement: $id');
    } catch (e) {
      AppLogger.severe('Error approving medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Reject reimbursement
  Future<void> rejectReimbursement(String id, String reason) async {
    try {
      await _collection.doc(id).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      AppLogger.info('Rejected medical bill reimbursement: $id');
    } catch (e) {
      AppLogger.severe('Error rejecting medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Close reimbursement
  Future<void> closeReimbursement(String id) async {
    try {
      await _collection.doc(id).update({
        'status': 'closed',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      AppLogger.info('Closed medical bill reimbursement: $id');
    } catch (e) {
      AppLogger.severe('Error closing medical bill reimbursement: $e');
      rethrow;
    }
  }

  /// Revert to draft
  Future<void> revertToDraft(String id) async {
    try {
      await _collection.doc(id).update({
        'status': 'draft',
        'submittedAt': null,
        'submittedBy': null,
        'approvedAt': null,
        'approvedBy': null,
        'approverName': null,
        'rejectionReason': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      AppLogger.info('Reverted medical bill reimbursement to draft: $id');
    } catch (e) {
      AppLogger.severe('Error reverting medical bill reimbursement to draft: $e');
      rethrow;
    }
  }

  /// Get pending approval reimbursements
  Future<List<MedicalBillReimbursement>> getPendingApprovalReimbursements() async {
    try {
      final snapshot = await _collection
          .where('status', isEqualTo: 'submitted')
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MedicalBillReimbursement.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.severe('Error getting pending approval reimbursements: $e');
      rethrow;
    }
  }
}
