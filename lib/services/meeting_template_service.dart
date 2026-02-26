import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting_template.dart';

class MeetingTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'meetingTemplates';

  /// Get all templates
  Stream<List<MeetingTemplate>> getTemplates() {
    return _firestore
        .collection(_collection)
        .orderBy('organization')
        .orderBy('type')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetingTemplate.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get templates by organization
  Stream<List<MeetingTemplate>> getTemplatesByOrganization(String organization) {
    return _firestore
        .collection(_collection)
        .where('organization', isEqualTo: organization)
        .orderBy('type')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetingTemplate.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get templates by type
  Stream<List<MeetingTemplate>> getTemplatesByType(MeetingTemplateType type) {
    return _firestore
        .collection(_collection)
        .where('type', isEqualTo: type.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetingTemplate.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a specific template by organization and type
  Future<MeetingTemplate?> getTemplate(
    String organization,
    MeetingTemplateType type,
  ) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('organization', isEqualTo: organization)
        .where('type', isEqualTo: type.name)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return MeetingTemplate.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// Get a single template by ID
  Future<MeetingTemplate?> getTemplateById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return MeetingTemplate.fromFirestore(doc);
    }
    return null;
  }

  /// Stream a single template by ID
  Stream<MeetingTemplate?> streamTemplateById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return MeetingTemplate.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Create a new template
  Future<String> createTemplate(MeetingTemplate template) async {
    final docRef = await _firestore
        .collection(_collection)
        .add(template.toFirestore());
    return docRef.id;
  }

  /// Update an existing template
  Future<void> updateTemplate(MeetingTemplate template) async {
    if (template.id == null) {
      throw Exception('Template ID is required for update');
    }
    await _firestore
        .collection(_collection)
        .doc(template.id)
        .update(template.toFirestore());
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Create default templates for an organization if they don't exist
  Future<void> ensureDefaultTemplates(String organization) async {
    for (final type in MeetingTemplateType.values) {
      final existing = await getTemplate(organization, type);
      if (existing == null) {
        await createTemplate(
          MeetingTemplate(
            name: '$organization ${type.displayName}',
            type: type,
            organization: organization,
            content: _getDefaultContent(type, organization),
          ),
        );
      }
    }
  }

  String _getDefaultContent(MeetingTemplateType type, String organization) {
    switch (type) {
      case MeetingTemplateType.agendaIntroduction:
        return 'The {{organization}} Meeting was called to order on {{fullDate}}.';
      case MeetingTemplateType.openingPrayer:
        return 'Opening prayer was offered.';
      case MeetingTemplateType.closingPrayer:
        return 'The meeting was closed with prayer.';
      case MeetingTemplateType.minutesHeader:
        return '{{organization}} MEETING\n{{fullDate}}\n\nMINUTES';
      case MeetingTemplateType.resolutionTemplate:
        return 'VOTED to approve the recommendation as presented.';
    }
  }
}
