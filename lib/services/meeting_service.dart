import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting.dart';

class MeetingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _meetingsCollection =>
      _firestore.collection('meetings');
  CollectionReference<Map<String, dynamic>> get _agendasCollection =>
      _firestore.collection('meeting_agendas');
  CollectionReference<Map<String, dynamic>> get _minutesCollection =>
      _firestore.collection('meeting_minutes');
  CollectionReference<Map<String, dynamic>> get _actionItemsCollection =>
      _firestore.collection('meeting_action_items');

  // ========== MEETINGS ==========

  // Create a new meeting
  Future<String> createMeeting(Meeting meeting) async {
    final docRef = _meetingsCollection.doc();
    final meetingWithId = meeting.copyWith(id: docRef.id);
    await docRef.set(meetingWithId.toFirestore());
    return docRef.id;
  }

  // Update a meeting
  Future<void> updateMeeting(Meeting meeting) async {
    await _meetingsCollection.doc(meeting.id).update(meeting.toFirestore());
  }

  // Delete a meeting
  Future<void> deleteMeeting(String meetingId) async {
    // Delete associated agenda
    final agendaQuery = await _agendasCollection
        .where('meetingId', isEqualTo: meetingId)
        .get();
    for (var doc in agendaQuery.docs) {
      await doc.reference.delete();
    }

    // Delete associated minutes
    final minutesQuery = await _minutesCollection
        .where('meetingId', isEqualTo: meetingId)
        .get();
    for (var doc in minutesQuery.docs) {
      await doc.reference.delete();
    }

    // Delete associated action items
    final actionItemsQuery = await _actionItemsCollection
        .where('meetingId', isEqualTo: meetingId)
        .get();
    for (var doc in actionItemsQuery.docs) {
      await doc.reference.delete();
    }

    // Delete the meeting
    await _meetingsCollection.doc(meetingId).delete();
  }

  // Get a single meeting
  Future<Meeting?> getMeeting(String meetingId) async {
    final doc = await _meetingsCollection.doc(meetingId).get();
    if (!doc.exists) return null;
    return Meeting.fromFirestore(doc);
  }

  // Get all meetings
  Stream<List<Meeting>> getMeetings({String? type, String? status}) {
    Query<Map<String, dynamic>> query = _meetingsCollection;

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('dateTime', descending: true).snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList(),
        );
  }

  // Get upcoming meetings
  Stream<List<Meeting>> getUpcomingMeetings({String? type}) {
    Query<Map<String, dynamic>> query = _meetingsCollection
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.now())
        .where('status', whereIn: ['scheduled', 'inProgress']);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query.orderBy('dateTime').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList(),
        );
  }

  // Get past meetings
  Stream<List<Meeting>> getPastMeetings({String? type, int limit = 20}) {
    Query<Map<String, dynamic>> query = _meetingsCollection
        .where('status', isEqualTo: 'completed');

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query
        .orderBy('dateTime', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList(),
        );
  }

  // Update meeting status
  Future<void> updateMeetingStatus(String meetingId, String status) async {
    await _meetingsCollection.doc(meetingId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  // ========== AGENDAS ==========

  // Create a new agenda
  Future<String> createAgenda(MeetingAgenda agenda) async {
    final docRef = _agendasCollection.doc();
    final agendaWithId = agenda.copyWith(id: docRef.id);
    await docRef.set(agendaWithId.toFirestore());

    // Update meeting with agenda reference
    await _meetingsCollection.doc(agenda.meetingId).update({
      'agendaId': docRef.id,
      'updatedAt': Timestamp.now(),
    });

    return docRef.id;
  }

  // Update an agenda
  Future<void> updateAgenda(MeetingAgenda agenda) async {
    await _agendasCollection.doc(agenda.id).update(agenda.toFirestore());
  }

  // Get agenda by ID
  Future<MeetingAgenda?> getAgenda(String agendaId) async {
    final doc = await _agendasCollection.doc(agendaId).get();
    if (!doc.exists) return null;
    return MeetingAgenda.fromFirestore(doc);
  }

  // Get agenda by meeting ID
  Future<MeetingAgenda?> getAgendaByMeetingId(String meetingId) async {
    final query = await _agendasCollection
        .where('meetingId', isEqualTo: meetingId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return MeetingAgenda.fromFirestore(query.docs.first);
  }

  // Stream agenda by meeting ID
  Stream<MeetingAgenda?> streamAgendaByMeetingId(String meetingId) {
    return _agendasCollection
        .where('meetingId', isEqualTo: meetingId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return MeetingAgenda.fromFirestore(snapshot.docs.first);
    });
  }

  // Update agenda status
  Future<void> updateAgendaStatus(
    String agendaId,
    String status, {
    String? approvedBy,
    String? publishedBy,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': Timestamp.now(),
    };

    if (status == 'approved' && approvedBy != null) {
      updates['approvedBy'] = approvedBy;
      updates['approvedAt'] = Timestamp.now();
    }

    if (status == 'published' && publishedBy != null) {
      updates['publishedBy'] = publishedBy;
      updates['publishedAt'] = Timestamp.now();
    }

    await _agendasCollection.doc(agendaId).update(updates);
  }

  // ========== MINUTES ==========

  // Create new minutes
  Future<String> createMinutes(MeetingMinutes minutes) async {
    final docRef = _minutesCollection.doc();
    final minutesWithId = minutes.copyWith(id: docRef.id);
    await docRef.set(minutesWithId.toFirestore());

    // Update meeting with minutes reference
    await _meetingsCollection.doc(minutes.meetingId).update({
      'minutesId': docRef.id,
      'updatedAt': Timestamp.now(),
    });

    return docRef.id;
  }

  // Update minutes
  Future<void> updateMinutes(MeetingMinutes minutes) async {
    await _minutesCollection.doc(minutes.id).update(minutes.toFirestore());
  }

  // Get minutes by ID
  Future<MeetingMinutes?> getMinutes(String minutesId) async {
    final doc = await _minutesCollection.doc(minutesId).get();
    if (!doc.exists) return null;
    return MeetingMinutes.fromFirestore(doc);
  }

  // Get minutes by meeting ID
  Future<MeetingMinutes?> getMinutesByMeetingId(String meetingId) async {
    final query = await _minutesCollection
        .where('meetingId', isEqualTo: meetingId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return MeetingMinutes.fromFirestore(query.docs.first);
  }

  // Stream minutes by meeting ID
  Stream<MeetingMinutes?> streamMinutesByMeetingId(String meetingId) {
    return _minutesCollection
        .where('meetingId', isEqualTo: meetingId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return MeetingMinutes.fromFirestore(snapshot.docs.first);
    });
  }

  // Update minutes status
  Future<void> updateMinutesStatus(
    String minutesId,
    String status, {
    String? approvedBy,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': Timestamp.now(),
    };

    if (status == 'approved' && approvedBy != null) {
      updates['approvedBy'] = approvedBy;
      updates['approvedAt'] = Timestamp.now();
    }

    await _minutesCollection.doc(minutesId).update(updates);
  }

  // ========== ACTION ITEMS ==========

  // Create action item
  Future<String> createActionItem(MeetingActionItem actionItem) async {
    final docRef = _actionItemsCollection.doc();
    final itemWithId = actionItem.copyWith(id: docRef.id);
    await docRef.set(itemWithId.toFirestore());
    return docRef.id;
  }

  // Update action item
  Future<void> updateActionItem(MeetingActionItem actionItem) async {
    await _actionItemsCollection.doc(actionItem.id).update(actionItem.toFirestore());
  }

  // Delete action item
  Future<void> deleteActionItem(String actionItemId) async {
    await _actionItemsCollection.doc(actionItemId).delete();
  }

  // Get action item by ID
  Future<MeetingActionItem?> getActionItem(String actionItemId) async {
    final doc = await _actionItemsCollection.doc(actionItemId).get();
    if (!doc.exists) return null;
    return MeetingActionItem.fromFirestore(doc);
  }

  // Get action items by meeting ID
  Stream<List<MeetingActionItem>> getActionItemsByMeetingId(String meetingId) {
    return _actionItemsCollection
        .where('meetingId', isEqualTo: meetingId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetingActionItem.fromFirestore(doc))
              .toList(),
        );
  }

  // Get all action items (optionally filtered)
  Stream<List<MeetingActionItem>> getAllActionItems({
    String? status,
    String? assigneeId,
  }) {
    Query<Map<String, dynamic>> query = _actionItemsCollection;

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (assigneeId != null) {
      query = query.where('assigneeId', isEqualTo: assigneeId);
    }

    return query.orderBy('dueDate').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetingActionItem.fromFirestore(doc))
              .toList(),
        );
  }

  // Get pending action items
  Stream<List<MeetingActionItem>> getPendingActionItems() {
    return _actionItemsCollection
        .where('status', whereIn: ['pending', 'inProgress'])
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetingActionItem.fromFirestore(doc))
              .toList(),
        );
  }

  // Get overdue action items
  Future<List<MeetingActionItem>> getOverdueActionItems() async {
    final query = await _actionItemsCollection
        .where('status', whereIn: ['pending', 'inProgress'])
        .where('dueDate', isLessThan: Timestamp.now())
        .get();

    return query.docs
        .map((doc) => MeetingActionItem.fromFirestore(doc))
        .toList();
  }

  // Update action item status
  Future<void> updateActionItemStatus(
    String actionItemId,
    String status, {
    String? completedNotes,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
    };

    if (status == 'completed') {
      updates['completedAt'] = Timestamp.now();
      if (completedNotes != null) {
        updates['completedNotes'] = completedNotes;
      }
    }

    await _actionItemsCollection.doc(actionItemId).update(updates);
  }

  // ========== STATISTICS ==========

  // Get meeting statistics
  Future<Map<String, int>> getMeetingStats() async {
    final allMeetings = await _meetingsCollection.get();
    final pendingActions = await _actionItemsCollection
        .where('status', whereIn: ['pending', 'inProgress'])
        .get();

    int scheduled = 0;
    int completed = 0;
    int adcomCount = 0;
    int boardCount = 0;

    for (var doc in allMeetings.docs) {
      final data = doc.data();
      if (data['status'] == 'scheduled') scheduled++;
      if (data['status'] == 'completed') completed++;
      if (data['type'] == 'adcom') adcomCount++;
      if (data['type'] == 'board') boardCount++;
    }

    return {
      'total': allMeetings.docs.length,
      'scheduled': scheduled,
      'completed': completed,
      'adcom': adcomCount,
      'board': boardCount,
      'pendingActions': pendingActions.docs.length,
    };
  }

  // ========== AGENDA TEMPLATES ==========

  // Get default agenda template by meeting type
  List<AgendaItem> getDefaultAgendaTemplate(String meetingType) {
    if (meetingType == 'board') {
      return [
        AgendaItem(
          id: 'template_1',
          order: 1,
          title: 'Call to Order & Opening Prayer',
          type: 'opening',
          timeAllocation: 5,
        ),
        AgendaItem(
          id: 'template_2',
          order: 2,
          title: 'Roll Call & Quorum Declaration',
          type: 'opening',
          timeAllocation: 5,
        ),
        AgendaItem(
          id: 'template_3',
          order: 3,
          title: 'Approval of Agenda',
          type: 'approval',
          timeAllocation: 5,
        ),
        AgendaItem(
          id: 'template_4',
          order: 4,
          title: 'Approval of Previous Minutes',
          type: 'approval',
          timeAllocation: 10,
        ),
        AgendaItem(
          id: 'template_5',
          order: 5,
          title: "Chairperson's Report",
          type: 'report',
          timeAllocation: 15,
        ),
        AgendaItem(
          id: 'template_6',
          order: 6,
          title: "Executive Director's Report",
          type: 'report',
          timeAllocation: 20,
        ),
        AgendaItem(
          id: 'template_7',
          order: 7,
          title: 'Financial Report & Audit',
          type: 'report',
          timeAllocation: 20,
        ),
        AgendaItem(
          id: 'template_8',
          order: 8,
          title: 'Committee Reports',
          type: 'report',
          timeAllocation: 30,
        ),
        AgendaItem(
          id: 'template_9',
          order: 9,
          title: 'Old Business',
          type: 'discussion',
          timeAllocation: 20,
        ),
        AgendaItem(
          id: 'template_10',
          order: 10,
          title: 'New Business',
          type: 'discussion',
          timeAllocation: 30,
        ),
        AgendaItem(
          id: 'template_11',
          order: 11,
          title: 'Announcements',
          type: 'information',
          timeAllocation: 10,
        ),
        AgendaItem(
          id: 'template_12',
          order: 12,
          title: 'Adjournment & Closing Prayer',
          type: 'closing',
          timeAllocation: 5,
        ),
      ];
    } else {
      // ADCOM template
      return [
        AgendaItem(
          id: 'template_1',
          order: 1,
          title: 'Opening Prayer',
          type: 'opening',
          timeAllocation: 5,
        ),
        AgendaItem(
          id: 'template_2',
          order: 2,
          title: 'Attendance & Quorum',
          type: 'opening',
          timeAllocation: 5,
        ),
        AgendaItem(
          id: 'template_3',
          order: 3,
          title: 'Approval of Previous Minutes',
          type: 'approval',
          timeAllocation: 10,
        ),
        AgendaItem(
          id: 'template_4',
          order: 4,
          title: 'Matters Arising / Action Items Review',
          type: 'discussion',
          timeAllocation: 15,
        ),
        AgendaItem(
          id: 'template_5',
          order: 5,
          title: 'Department Reports',
          type: 'report',
          timeAllocation: 30,
        ),
        AgendaItem(
          id: 'template_6',
          order: 6,
          title: 'Financial Report',
          type: 'report',
          timeAllocation: 15,
        ),
        AgendaItem(
          id: 'template_7',
          order: 7,
          title: 'New Business Items',
          type: 'discussion',
          timeAllocation: 30,
        ),
        AgendaItem(
          id: 'template_8',
          order: 8,
          title: 'Any Other Business (AOB)',
          type: 'other',
          timeAllocation: 15,
        ),
        AgendaItem(
          id: 'template_9',
          order: 9,
          title: 'Next Meeting Date',
          type: 'information',
          timeAllocation: 5,
        ),
        AgendaItem(
          id: 'template_10',
          order: 10,
          title: 'Closing Prayer',
          type: 'closing',
          timeAllocation: 5,
        ),
      ];
    }
  }
}
