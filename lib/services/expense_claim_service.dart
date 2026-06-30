import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_claim.dart';
import '../models/user.dart';
import '../utils/logger.dart';

class ExpenseClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('expense_claims');

  String _generateClaimNumber(String id) {
    final dateStr = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final suffix = id.replaceAll('-', '').substring(0, 6).toUpperCase();
    return 'EXP-$dateStr-$suffix';
  }

  Future<List<ExpenseClaim>> getAllClaims() async {
    try {
      final snapshot = await _collection
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(ExpenseClaim.fromFirestore).toList();
    } catch (e) {
      AppLogger.severe('Error getting all expense claims: $e');
      rethrow;
    }
  }

  Future<List<ExpenseClaim>> getClaimsByRequester(String requesterId) async {
    try {
      final snapshot = await _collection
          .where('requesterId', isEqualTo: requesterId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(ExpenseClaim.fromFirestore).toList();
    } catch (e) {
      AppLogger.severe('Error getting expense claims by requester: $e');
      rethrow;
    }
  }

  Future<ExpenseClaim?> getClaim(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      return doc.exists ? ExpenseClaim.fromFirestore(doc) : null;
    } catch (e) {
      AppLogger.severe('Error getting expense claim: $e');
      rethrow;
    }
  }

  Future<ExpenseClaim> createClaim({
    required User requester,
    required String title,
    required String purpose,
    required String department,
    required List<ExpenseLineItem> items,
    String? notes,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();
      final claim = ExpenseClaim(
        id: id,
        claimNumber: _generateClaimNumber(id),
        title: title,
        purpose: purpose,
        requesterId: requester.id,
        requesterName: requester.name,
        department: department,
        items: items,
        status: 'pending',
        createdAt: now,
        notes: notes,
      );
      await _collection.doc(id).set(claim.toFirestore());
      return claim;
    } catch (e) {
      AppLogger.severe('Error creating expense claim: $e');
      rethrow;
    }
  }

  Future<void> updateClaim(ExpenseClaim claim) async {
    try {
      await _collection.doc(claim.id).update(
        claim.copyWith(updatedAt: DateTime.now()).toFirestore(),
      );
    } catch (e) {
      AppLogger.severe('Error updating expense claim: $e');
      rethrow;
    }
  }

  Future<void> deleteClaim(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      AppLogger.severe('Error deleting expense claim: $e');
      rethrow;
    }
  }

  Future<void> approveClaim(
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
        'rejectionReason': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      AppLogger.severe('Error approving expense claim: $e');
      rethrow;
    }
  }

  Future<void> rejectClaim(String id, String reason) async {
    try {
      await _collection.doc(id).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      AppLogger.severe('Error rejecting expense claim: $e');
      rethrow;
    }
  }
}
