import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/internal_debit_note.dart';

class InternalDebitNoteProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<InternalDebitNote> _notes = [];
  bool _isLoading = false;
  String? _error;

  List<InternalDebitNote> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<InternalDebitNote> get draftNotes =>
      _notes.where((n) => n.status == 'draft').toList();

  List<InternalDebitNote> get issuedNotes =>
      _notes.where((n) => n.status == 'issued').toList();

  String _generateDebitNoteNumber() {
    final year = DateTime.now().year;
    final countThisYear = _notes
        .where((n) => n.debitNoteNumber.startsWith('IDN-$year-'))
        .length;
    final seq = (countThisYear + 1).toString().padLeft(3, '0');
    return 'IDN-$year-$seq';
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('internal_debit_notes')
          .orderBy('createdAt', descending: true)
          .get();

      _notes = snapshot.docs
          .map((doc) => InternalDebitNote.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = 'Failed to load internal debit notes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNotesByUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('internal_debit_notes')
          .where('createdById', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _notes = snapshot.docs
          .map((doc) => InternalDebitNote.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = 'Failed to load internal debit notes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InternalDebitNote?> createNote({
    required DateTime noteDate,
    required String companyName,
    required String issuedToCompany,
    required String department,
    required List<DebitNoteLineItem> lineItems,
    required String currency,
    required String reasonForDebit,
    required String paymentTerms,
    required String createdById,
    required String createdByName,
    String? checkedByName,
    String? approvedByName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final docRef = _firestore.collection('internal_debit_notes').doc();

      final note = InternalDebitNote(
        id: docRef.id,
        debitNoteNumber: _generateDebitNoteNumber(),
        noteDate: noteDate,
        companyName: companyName,
        issuedToCompany: issuedToCompany,
        department: department,
        lineItems: lineItems,
        currency: currency,
        reasonForDebit: reasonForDebit,
        paymentTerms: paymentTerms,
        preparedByName: createdByName,
        checkedByName: checkedByName,
        approvedByName: approvedByName,
        status: 'draft',
        createdById: createdById,
        createdByName: createdByName,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(note.toFirestore());
      _notes.insert(0, note);
      notifyListeners();
      return note;
    } catch (e) {
      _error = 'Failed to create internal debit note: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateNote(InternalDebitNote note) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = note.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('internal_debit_notes')
          .doc(note.id)
          .set(updated.toFirestore());

      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update internal debit note: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteNote(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore.collection('internal_debit_notes').doc(id).delete();
      _notes.removeWhere((n) => n.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete internal debit note: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> issueNote(String id) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('internal_debit_notes').doc(id).update({
        'status': 'issued',
        'updatedAt': Timestamp.fromDate(now),
      });

      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notes[index] = _notes[index].copyWith(
          status: 'issued',
          updatedAt: now,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to issue internal debit note: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> revertToDraft(String id) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('internal_debit_notes').doc(id).update({
        'status': 'draft',
        'updatedAt': Timestamp.fromDate(now),
      });

      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notes[index] = _notes[index].copyWith(
          status: 'draft',
          updatedAt: now,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to revert internal debit note to draft: $e';
      notifyListeners();
      return false;
    }
  }

  InternalDebitNote? getNoteById(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
