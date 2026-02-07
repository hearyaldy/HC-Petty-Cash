import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/adcom_minutes.dart';
import '../models/adcom_agenda.dart';

class AdcomMinutesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'adcom_minutes';

  /// Get all minutes
  Stream<List<AdcomMinutes>> getMinutes() {
    return _firestore
        .collection(_collection)
        .orderBy('meetingDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdcomMinutes.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a single minutes by ID
  Future<AdcomMinutes?> getMinutesById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return AdcomMinutes.fromFirestore(doc);
    }
    return null;
  }

  /// Get minutes by agenda ID
  Future<AdcomMinutes?> getMinutesByAgendaId(String agendaId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('agendaId', isEqualTo: agendaId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return AdcomMinutes.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// Create minutes from an agenda
  Future<String> createMinutesFromAgenda(AdcomAgenda agenda) async {
    // Check if minutes already exist for this agenda
    final existingMinutes = await getMinutesByAgendaId(agenda.id);
    if (existingMinutes != null) {
      return existingMinutes.id;
    }

    // Create new minutes from agenda
    final minutes = AdcomMinutes.fromAgenda(agenda, '');
    final docRef = await _firestore
        .collection(_collection)
        .add(minutes.toMap());
    return docRef.id;
  }

  /// Create a new minutes
  Future<String> createMinutes(AdcomMinutes minutes) async {
    final docRef = await _firestore
        .collection(_collection)
        .add(minutes.toMap());
    return docRef.id;
  }

  /// Update existing minutes
  Future<void> updateMinutes(AdcomMinutes minutes) async {
    await _firestore.collection(_collection).doc(minutes.id).update({
      ...minutes.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete minutes
  Future<void> deleteMinutes(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Add a minutes item (new agenda/discussion item during meeting)
  Future<void> addMinutesItem(String minutesId, MinutesItem item) async {
    final doc = await _firestore.collection(_collection).doc(minutesId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['minutesItems'] as List<dynamic>?) ?? [],
      );
      items.add(item.toMap());
      await _firestore.collection(_collection).doc(minutesId).update({
        'minutesItems': items,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// Update a minutes item
  Future<void> updateMinutesItem(
    String minutesId,
    int itemIndex,
    MinutesItem item,
  ) async {
    final doc = await _firestore.collection(_collection).doc(minutesId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['minutesItems'] as List<dynamic>?) ?? [],
      );
      if (itemIndex < items.length) {
        items[itemIndex] = item.toMap();
        await _firestore.collection(_collection).doc(minutesId).update({
          'minutesItems': items,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  /// Remove a minutes item
  Future<void> removeMinutesItem(String minutesId, int itemIndex) async {
    final doc = await _firestore.collection(_collection).doc(minutesId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['minutesItems'] as List<dynamic>?) ?? [],
      );
      if (itemIndex < items.length) {
        items.removeAt(itemIndex);
        // Update order for remaining items
        for (int i = 0; i < items.length; i++) {
          items[i]['order'] = i;
        }
        await _firestore.collection(_collection).doc(minutesId).update({
          'minutesItems': items,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  /// Update item status (Voted/Tabled/Discussed)
  Future<void> updateItemStatus(
    String minutesId,
    int itemIndex,
    MinutesItemStatus status, {
    String? resolution,
    String? notes,
  }) async {
    final doc = await _firestore.collection(_collection).doc(minutesId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (data['minutesItems'] as List<dynamic>?) ?? [],
      );
      if (itemIndex < items.length) {
        items[itemIndex]['status'] = status.displayName.toLowerCase();
        if (resolution != null) {
          items[itemIndex]['resolution'] = resolution;
        }
        if (notes != null) {
          items[itemIndex]['notes'] = notes;
        }
        await _firestore.collection(_collection).doc(minutesId).update({
          'minutesItems': items,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }
}
