import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/adcom_agenda.dart';

class AdcomAgendaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'adcom_agendas';

  /// Get all agendas
  Stream<List<AdcomAgenda>> getAgendas() {
    return _firestore
        .collection(_collection)
        .orderBy('meetingDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdcomAgenda.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a single agenda by ID
  Future<AdcomAgenda?> getAgendaById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return AdcomAgenda.fromFirestore(doc);
    }
    return null;
  }

  /// Stream a single agenda by ID
  Stream<AdcomAgenda?> streamAgendaById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return AdcomAgenda.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Create a new agenda
  Future<String> createAgenda(AdcomAgenda agenda) async {
    final docRef = await _firestore.collection(_collection).add(agenda.toMap());
    return docRef.id;
  }

  /// Update an existing agenda
  Future<void> updateAgenda(AdcomAgenda agenda) async {
    await _firestore.collection(_collection).doc(agenda.id).update({
      ...agenda.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete an agenda
  Future<void> deleteAgenda(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Get next item number for a meeting date
  Future<int> getNextItemSequence(String agendaId) async {
    final doc = await _firestore.collection(_collection).doc(agendaId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = data['agendaItems'] as List<dynamic>? ?? [];
      return items.length + 1;
    }
    return 1;
  }

  /// Add an agenda item
  Future<void> addAgendaItem(String agendaId, AgendaItem item) async {
    final doc = await _firestore.collection(_collection).doc(agendaId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['agendaItems'] as List<dynamic>?) ?? [],
      );
      items.add(item.toMap());
      await _firestore.collection(_collection).doc(agendaId).update({
        'agendaItems': items,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// Update an agenda item
  Future<void> updateAgendaItem(
    String agendaId,
    int itemIndex,
    AgendaItem item,
  ) async {
    final doc = await _firestore.collection(_collection).doc(agendaId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['agendaItems'] as List<dynamic>?) ?? [],
      );
      if (itemIndex < items.length) {
        items[itemIndex] = item.toMap();
        await _firestore.collection(_collection).doc(agendaId).update({
          'agendaItems': items,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  /// Remove an agenda item
  Future<void> removeAgendaItem(String agendaId, int itemIndex) async {
    final doc = await _firestore.collection(_collection).doc(agendaId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['agendaItems'] as List<dynamic>?) ?? [],
      );
      if (itemIndex < items.length) {
        items.removeAt(itemIndex);

        // Get meeting date and starting sequence for regenerating item numbers
        final meetingDate = (data['meetingDate'] as Timestamp).toDate();
        final startingSeq = data['startingItemSequence'] ?? 1;

        // Re-order remaining items and regenerate item numbers
        final organization = data['organization'] as String? ?? 'ADCOM';
        for (int i = 0; i < items.length; i++) {
          items[i]['order'] = i;
          items[i]['itemNumber'] = AdcomAgenda.generateItemNumber(
            meetingDate,
            startingSeq + i,
            organization: organization,
          );
        }
        await _firestore.collection(_collection).doc(agendaId).update({
          'agendaItems': items,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  /// Reorder agenda items
  Future<void> reorderAgendaItems(
    String agendaId,
    int oldIndex,
    int newIndex,
  ) async {
    final doc = await _firestore.collection(_collection).doc(agendaId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['agendaItems'] as List<dynamic>?) ?? [],
      );

      if (oldIndex < items.length && newIndex < items.length) {
        final item = items.removeAt(oldIndex);
        items.insert(newIndex, item);

        // Get meeting date and starting sequence for regenerating item numbers
        final meetingDate = (data['meetingDate'] as Timestamp).toDate();
        final startingSeq = data['startingItemSequence'] ?? 1;
        final organization = data['organization'] as String? ?? 'ADCOM';

        // Update order and regenerate item numbers for all items
        for (int i = 0; i < items.length; i++) {
          items[i]['order'] = i;
          items[i]['itemNumber'] = AdcomAgenda.generateItemNumber(
            meetingDate,
            startingSeq + i,
            organization: organization,
          );
        }

        await _firestore.collection(_collection).doc(agendaId).update({
          'agendaItems': items,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  /// Update attendance
  Future<void> updateAttendance(
    String agendaId,
    List<AttendanceMember> members,
  ) async {
    await _firestore.collection(_collection).doc(agendaId).update({
      'attendanceMembers': members.map((m) => m.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Finalize agenda
  Future<void> finalizeAgenda(String agendaId) async {
    await _firestore.collection(_collection).doc(agendaId).update({
      'status': 'finalized',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Get default attendance members (can be customized)
  List<AttendanceMember> getDefaultAttendanceMembers() {
    return [
      AttendanceMember(name: '', affiliation: 'HC', isPresent: true),
      AttendanceMember(name: '', affiliation: 'SEUM', isPresent: true),
    ];
  }
}
