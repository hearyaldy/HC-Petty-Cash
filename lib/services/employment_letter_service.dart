import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employment_letter.dart';

class EmploymentLetterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String templatesCollectionName = 'employment_letter_templates';
  static const String lettersCollectionName = 'employment_letters';

  // Template Operations

  // Create a new template
  Future<String> createTemplate(EmploymentLetterTemplate template) async {
    try {
      final docRef = await _firestore
          .collection(templatesCollectionName)
          .add(template.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create employment letter template: $e');
    }
  }

  // Update existing template
  Future<void> updateTemplate(EmploymentLetterTemplate template) async {
    try {
      await _firestore
          .collection(templatesCollectionName)
          .doc(template.id)
          .update(template.toFirestore());
    } catch (e) {
      throw Exception('Failed to update employment letter template: $e');
    }
  }

  // Delete template
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _firestore
          .collection(templatesCollectionName)
          .doc(templateId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete employment letter template: $e');
    }
  }

  // Get template by ID
  Future<EmploymentLetterTemplate?> getTemplateById(String templateId) async {
    try {
      final doc = await _firestore
          .collection(templatesCollectionName)
          .doc(templateId)
          .get();
      if (doc.exists) {
        return EmploymentLetterTemplate.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get employment letter template: $e');
    }
  }

  // Get all templates
  Stream<List<EmploymentLetterTemplate>> getAllTemplates() {
    return _firestore
        .collection(templatesCollectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('Debug: Got ${snapshot.docs.length} template documents from Firestore');
          final List<EmploymentLetterTemplate> templates = [];
          for (final doc in snapshot.docs) {
            try {
              final template = EmploymentLetterTemplate.fromFirestore(doc);
              templates.add(template);
            } catch (e) {
              print('Debug: Error parsing template document ${doc.id}: $e');
              print('Debug: Document data: ${doc.data()}');
              // Continue processing other documents
            }
          }
          print('Debug: Successfully parsed ${templates.length} templates');
          return templates;
        });
  }

  // Get active templates only
  Stream<List<EmploymentLetterTemplate>> getActiveTemplates() {
    // Note: This query requires a composite index on (isActive, createdAt)
    // If the index doesn't exist, fall back to filtering in memory
    return _firestore
        .collection(templatesCollectionName)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final templates = snapshot.docs
              .map((doc) => EmploymentLetterTemplate.fromFirestore(doc))
              .toList();
          // Sort in memory since orderBy with where requires composite index
          templates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return templates;
        });
  }

  // Letter Operations

  // Create a new employment letter
  Future<String> createLetter(EmploymentLetter letter) async {
    try {
      final docRef = await _firestore
          .collection(lettersCollectionName)
          .add(letter.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create employment letter: $e');
    }
  }

  // Update existing letter
  Future<void> updateLetter(EmploymentLetter letter) async {
    try {
      await _firestore
          .collection(lettersCollectionName)
          .doc(letter.id)
          .update(letter.toFirestore());
    } catch (e) {
      throw Exception('Failed to update employment letter: $e');
    }
  }

  // Delete letter
  Future<void> deleteLetter(String letterId) async {
    try {
      await _firestore.collection(lettersCollectionName).doc(letterId).delete();
    } catch (e) {
      throw Exception('Failed to delete employment letter: $e');
    }
  }

  // Get letter by ID
  Future<EmploymentLetter?> getLetterById(String letterId) async {
    try {
      final doc = await _firestore
          .collection(lettersCollectionName)
          .doc(letterId)
          .get();
      if (doc.exists) {
        return EmploymentLetter.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get employment letter: $e');
    }
  }

  // Get all letters for a specific staff member
  Stream<List<EmploymentLetter>> getLettersForStaff(String staffId) {
    return _firestore
        .collection(lettersCollectionName)
        .where('staffId', isEqualTo: staffId)
        .orderBy('issuedDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmploymentLetter.fromFirestore(doc))
              .toList(),
        );
  }

  // Get all letters
  Stream<List<EmploymentLetter>> getAllLetters() {
    return _firestore
        .collection(lettersCollectionName)
        .orderBy('issuedDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmploymentLetter.fromFirestore(doc))
              .toList(),
        );
  }

  // Get letters by template
  Stream<List<EmploymentLetter>> getLettersByTemplate(String templateId) {
    return _firestore
        .collection(lettersCollectionName)
        .where('templateId', isEqualTo: templateId)
        .orderBy('issuedDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmploymentLetter.fromFirestore(doc))
              .toList(),
        );
  }

  // Get the default/active template
  Future<EmploymentLetterTemplate?> getDefaultTemplate() async {
    try {
      final querySnapshot = await _firestore
          .collection(templatesCollectionName)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return EmploymentLetterTemplate.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get default template: $e');
    }
  }
}
