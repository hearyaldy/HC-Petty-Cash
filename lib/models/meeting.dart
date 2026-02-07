import 'package:cloud_firestore/cloud_firestore.dart';

// Meeting type enum
enum MeetingType {
  adcom,
  board,
}

extension MeetingTypeExtension on MeetingType {
  String get displayName {
    switch (this) {
      case MeetingType.adcom:
        return 'HC ADCOM';
      case MeetingType.board:
        return 'HC Board';
    }
  }

  String get value => name;

  static MeetingType fromString(String? value) {
    if (value == null) return MeetingType.adcom;
    return MeetingType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MeetingType.adcom,
    );
  }
}

// Meeting status enum
enum MeetingStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
}

extension MeetingStatusExtension on MeetingStatus {
  String get displayName {
    switch (this) {
      case MeetingStatus.scheduled:
        return 'Scheduled';
      case MeetingStatus.inProgress:
        return 'In Progress';
      case MeetingStatus.completed:
        return 'Completed';
      case MeetingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get value => name;

  static MeetingStatus fromString(String? value) {
    if (value == null) return MeetingStatus.scheduled;
    return MeetingStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MeetingStatus.scheduled,
    );
  }
}

// Agenda status enum
enum AgendaStatus {
  draft,
  review,
  approved,
  published,
}

extension AgendaStatusExtension on AgendaStatus {
  String get displayName {
    switch (this) {
      case AgendaStatus.draft:
        return 'Draft';
      case AgendaStatus.review:
        return 'Under Review';
      case AgendaStatus.approved:
        return 'Approved';
      case AgendaStatus.published:
        return 'Published';
    }
  }

  String get value => name;

  static AgendaStatus fromString(String? value) {
    if (value == null) return AgendaStatus.draft;
    return AgendaStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AgendaStatus.draft,
    );
  }
}

// Minutes status enum
enum MinutesStatus {
  draft,
  review,
  approved,
}

extension MinutesStatusExtension on MinutesStatus {
  String get displayName {
    switch (this) {
      case MinutesStatus.draft:
        return 'Draft';
      case MinutesStatus.review:
        return 'Under Review';
      case MinutesStatus.approved:
        return 'Approved';
    }
  }

  String get value => name;

  static MinutesStatus fromString(String? value) {
    if (value == null) return MinutesStatus.draft;
    return MinutesStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MinutesStatus.draft,
    );
  }
}

// Agenda item type enum
enum AgendaItemType {
  opening,
  approval,
  report,
  discussion,
  action,
  information,
  closing,
  other,
}

extension AgendaItemTypeExtension on AgendaItemType {
  String get displayName {
    switch (this) {
      case AgendaItemType.opening:
        return 'Opening';
      case AgendaItemType.approval:
        return 'Approval';
      case AgendaItemType.report:
        return 'Report';
      case AgendaItemType.discussion:
        return 'Discussion';
      case AgendaItemType.action:
        return 'Action Item';
      case AgendaItemType.information:
        return 'Information';
      case AgendaItemType.closing:
        return 'Closing';
      case AgendaItemType.other:
        return 'Other';
    }
  }

  String get value => name;

  static AgendaItemType fromString(String? value) {
    if (value == null) return AgendaItemType.other;
    return AgendaItemType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AgendaItemType.other,
    );
  }
}

// Attendance status enum
enum AttendanceStatus {
  present,
  absent,
  excused,
  late,
}

extension AttendanceStatusExtension on AttendanceStatus {
  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.excused:
        return 'Excused';
      case AttendanceStatus.late:
        return 'Late';
    }
  }

  String get value => name;

  static AttendanceStatus fromString(String? value) {
    if (value == null) return AttendanceStatus.absent;
    return AttendanceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AttendanceStatus.absent,
    );
  }
}

// Action item status enum
enum ActionItemStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

extension ActionItemStatusExtension on ActionItemStatus {
  String get displayName {
    switch (this) {
      case ActionItemStatus.pending:
        return 'Pending';
      case ActionItemStatus.inProgress:
        return 'In Progress';
      case ActionItemStatus.completed:
        return 'Completed';
      case ActionItemStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get value => name;

  static ActionItemStatus fromString(String? value) {
    if (value == null) return ActionItemStatus.pending;
    return ActionItemStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActionItemStatus.pending,
    );
  }
}

// Meeting Member model
class MeetingMember {
  final String oderId;
  final String name;
  final String? email;
  final String? role; // e.g., 'Chairperson', 'Secretary', 'Member', 'Guest'
  final String? organization; // For external members (e.g., 'GC', 'Union', etc.)

  MeetingMember({
    required this.oderId,
    required this.name,
    this.email,
    this.role,
    this.organization,
  });

  bool get isExternal => oderId.startsWith('external_');

  Map<String, dynamic> toMap() {
    return {
      'userId': oderId,
      'name': name,
      'email': email,
      'role': role,
      'organization': organization,
      'isExternal': isExternal,
    };
  }

  factory MeetingMember.fromMap(Map<String, dynamic> map) {
    return MeetingMember(
      oderId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'],
      role: map['role'],
      organization: map['organization'],
    );
  }
}

// Meeting model
class Meeting {
  final String id;
  final String type; // 'adcom' or 'board'
  final String title;
  final DateTime dateTime;
  final String? location;
  final String? virtualLink;
  final String status; // 'scheduled', 'inProgress', 'completed', 'cancelled'
  final String? chairpersonId;
  final String? chairpersonName;
  final String? secretaryId;
  final String? secretaryName;
  final List<MeetingMember> invitedMembers;
  final String? agendaId;
  final String? minutesId;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Meeting({
    required this.id,
    required this.type,
    required this.title,
    required this.dateTime,
    this.location,
    this.virtualLink,
    this.status = 'scheduled',
    this.chairpersonId,
    this.chairpersonName,
    this.secretaryId,
    this.secretaryName,
    this.invitedMembers = const [],
    this.agendaId,
    this.minutesId,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  MeetingType get meetingType => MeetingTypeExtension.fromString(type);
  MeetingStatus get meetingStatus => MeetingStatusExtension.fromString(status);

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'virtualLink': virtualLink,
      'status': status,
      'chairpersonId': chairpersonId,
      'chairpersonName': chairpersonName,
      'secretaryId': secretaryId,
      'secretaryName': secretaryName,
      'invitedMembers': invitedMembers.map((m) => m.toMap()).toList(),
      'agendaId': agendaId,
      'minutesId': minutesId,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final now = DateTime.now();

    List<MeetingMember> parseMembers(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((m) => MeetingMember.fromMap(m as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return Meeting(
      id: data['id'] ?? doc.id,
      type: data['type'] ?? 'adcom',
      title: data['title'] ?? '',
      dateTime: parseTimestamp(data['dateTime'], now),
      location: data['location'],
      virtualLink: data['virtualLink'],
      status: data['status'] ?? 'scheduled',
      chairpersonId: data['chairpersonId'],
      chairpersonName: data['chairpersonName'],
      secretaryId: data['secretaryId'],
      secretaryName: data['secretaryName'],
      invitedMembers: parseMembers(data['invitedMembers']),
      agendaId: data['agendaId'],
      minutesId: data['minutesId'],
      notes: data['notes'],
      createdBy: data['createdBy'] ?? '',
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: data['updatedAt'] != null
          ? parseTimestamp(data['updatedAt'], now)
          : null,
    );
  }

  Meeting copyWith({
    String? id,
    String? type,
    String? title,
    DateTime? dateTime,
    String? location,
    String? virtualLink,
    String? status,
    String? chairpersonId,
    String? chairpersonName,
    String? secretaryId,
    String? secretaryName,
    List<MeetingMember>? invitedMembers,
    String? agendaId,
    String? minutesId,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meeting(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      virtualLink: virtualLink ?? this.virtualLink,
      status: status ?? this.status,
      chairpersonId: chairpersonId ?? this.chairpersonId,
      chairpersonName: chairpersonName ?? this.chairpersonName,
      secretaryId: secretaryId ?? this.secretaryId,
      secretaryName: secretaryName ?? this.secretaryName,
      invitedMembers: invitedMembers ?? this.invitedMembers,
      agendaId: agendaId ?? this.agendaId,
      minutesId: minutesId ?? this.minutesId,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Agenda Item model
class AgendaItem {
  final String id;
  final int order;
  final String title;
  final String? description;
  final String type; // AgendaItemType
  final String? presenterId;
  final String? presenterName;
  final int timeAllocation; // in minutes
  final List<String> attachments; // URLs or file paths

  AgendaItem({
    required this.id,
    required this.order,
    required this.title,
    this.description,
    this.type = 'other',
    this.presenterId,
    this.presenterName,
    this.timeAllocation = 10,
    this.attachments = const [],
  });

  AgendaItemType get itemType => AgendaItemTypeExtension.fromString(type);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'title': title,
      'description': description,
      'type': type,
      'presenterId': presenterId,
      'presenterName': presenterName,
      'timeAllocation': timeAllocation,
      'attachments': attachments,
    };
  }

  factory AgendaItem.fromMap(Map<String, dynamic> map) {
    return AgendaItem(
      id: map['id'] ?? '',
      order: map['order'] ?? 0,
      title: map['title'] ?? '',
      description: map['description'],
      type: map['type'] ?? 'other',
      presenterId: map['presenterId'],
      presenterName: map['presenterName'],
      timeAllocation: map['timeAllocation'] ?? 10,
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  AgendaItem copyWith({
    String? id,
    int? order,
    String? title,
    String? description,
    String? type,
    String? presenterId,
    String? presenterName,
    int? timeAllocation,
    List<String>? attachments,
  }) {
    return AgendaItem(
      id: id ?? this.id,
      order: order ?? this.order,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      presenterId: presenterId ?? this.presenterId,
      presenterName: presenterName ?? this.presenterName,
      timeAllocation: timeAllocation ?? this.timeAllocation,
      attachments: attachments ?? this.attachments,
    );
  }
}

// Agenda model
class MeetingAgenda {
  final String id;
  final String meetingId;
  final String status; // 'draft', 'review', 'approved', 'published'
  final List<AgendaItem> items;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? publishedBy;
  final DateTime? publishedAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MeetingAgenda({
    required this.id,
    required this.meetingId,
    this.status = 'draft',
    this.items = const [],
    this.approvedBy,
    this.approvedAt,
    this.publishedBy,
    this.publishedAt,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  AgendaStatus get agendaStatus => AgendaStatusExtension.fromString(status);

  int get totalDuration => items.fold(0, (total, item) => total + item.timeAllocation);

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'meetingId': meetingId,
      'status': status,
      'items': items.map((i) => i.toMap()).toList(),
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'publishedBy': publishedBy,
      'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MeetingAgenda.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final now = DateTime.now();

    List<AgendaItem> parseItems(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((i) => AgendaItem.fromMap(i as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return MeetingAgenda(
      id: data['id'] ?? doc.id,
      meetingId: data['meetingId'] ?? '',
      status: data['status'] ?? 'draft',
      items: parseItems(data['items']),
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null
          ? parseTimestamp(data['approvedAt'], now)
          : null,
      publishedBy: data['publishedBy'],
      publishedAt: data['publishedAt'] != null
          ? parseTimestamp(data['publishedAt'], now)
          : null,
      createdBy: data['createdBy'] ?? '',
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: data['updatedAt'] != null
          ? parseTimestamp(data['updatedAt'], now)
          : null,
    );
  }

  MeetingAgenda copyWith({
    String? id,
    String? meetingId,
    String? status,
    List<AgendaItem>? items,
    String? approvedBy,
    DateTime? approvedAt,
    String? publishedBy,
    DateTime? publishedAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeetingAgenda(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      status: status ?? this.status,
      items: items ?? this.items,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      publishedBy: publishedBy ?? this.publishedBy,
      publishedAt: publishedAt ?? this.publishedAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Attendance Record model
class AttendanceRecord {
  final String oderId;
  final String name;
  final String status; // 'present', 'absent', 'excused', 'late'
  final DateTime? arrivedAt;
  final String? notes;

  AttendanceRecord({
    required this.oderId,
    required this.name,
    this.status = 'absent',
    this.arrivedAt,
    this.notes,
  });

  AttendanceStatus get attendanceStatus => AttendanceStatusExtension.fromString(status);

  Map<String, dynamic> toMap() {
    return {
      'userId': oderId,
      'name': name,
      'status': status,
      'arrivedAt': arrivedAt != null ? Timestamp.fromDate(arrivedAt!) : null,
      'notes': notes,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      oderId: map['userId'] ?? '',
      name: map['name'] ?? '',
      status: map['status'] ?? 'absent',
      arrivedAt: map['arrivedAt'] != null
          ? (map['arrivedAt'] as Timestamp).toDate()
          : null,
      notes: map['notes'],
    );
  }

  AttendanceRecord copyWith({
    String? oderId,
    String? name,
    String? status,
    DateTime? arrivedAt,
    String? notes,
  }) {
    return AttendanceRecord(
      oderId: oderId ?? this.oderId,
      name: name ?? this.name,
      status: status ?? this.status,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      notes: notes ?? this.notes,
    );
  }
}

// Motion Record model
class MotionRecord {
  final String id;
  final String description;
  final String? proposerId;
  final String? proposerName;
  final String? seconderId;
  final String? seconderName;
  final int? votesFor;
  final int? votesAgainst;
  final int? abstentions;
  final String result; // 'passed', 'failed', 'tabled', 'withdrawn'

  MotionRecord({
    required this.id,
    required this.description,
    this.proposerId,
    this.proposerName,
    this.seconderId,
    this.seconderName,
    this.votesFor,
    this.votesAgainst,
    this.abstentions,
    this.result = 'passed',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'proposerId': proposerId,
      'proposerName': proposerName,
      'seconderId': seconderId,
      'seconderName': seconderName,
      'votesFor': votesFor,
      'votesAgainst': votesAgainst,
      'abstentions': abstentions,
      'result': result,
    };
  }

  factory MotionRecord.fromMap(Map<String, dynamic> map) {
    return MotionRecord(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      proposerId: map['proposerId'],
      proposerName: map['proposerName'],
      seconderId: map['seconderId'],
      seconderName: map['seconderName'],
      votesFor: map['votesFor'],
      votesAgainst: map['votesAgainst'],
      abstentions: map['abstentions'],
      result: map['result'] ?? 'passed',
    );
  }
}

// Action Item model
class MeetingActionItem {
  final String id;
  final String meetingId;
  final String? agendaItemId;
  final String description;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? dueDate;
  final String status; // 'pending', 'inProgress', 'completed', 'cancelled'
  final String? completedNotes;
  final DateTime? completedAt;
  final String createdBy;
  final DateTime createdAt;

  MeetingActionItem({
    required this.id,
    required this.meetingId,
    this.agendaItemId,
    required this.description,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    this.status = 'pending',
    this.completedNotes,
    this.completedAt,
    required this.createdBy,
    required this.createdAt,
  });

  ActionItemStatus get actionStatus => ActionItemStatusExtension.fromString(status);

  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == 'completed' || status == 'cancelled') return false;
    return DateTime.now().isAfter(dueDate!);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'meetingId': meetingId,
      'agendaItemId': agendaItemId,
      'description': description,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'status': status,
      'completedNotes': completedNotes,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MeetingActionItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final now = DateTime.now();

    return MeetingActionItem(
      id: data['id'] ?? doc.id,
      meetingId: data['meetingId'] ?? '',
      agendaItemId: data['agendaItemId'],
      description: data['description'] ?? '',
      assigneeId: data['assigneeId'],
      assigneeName: data['assigneeName'],
      dueDate: data['dueDate'] != null
          ? parseTimestamp(data['dueDate'], now)
          : null,
      status: data['status'] ?? 'pending',
      completedNotes: data['completedNotes'],
      completedAt: data['completedAt'] != null
          ? parseTimestamp(data['completedAt'], now)
          : null,
      createdBy: data['createdBy'] ?? '',
      createdAt: parseTimestamp(data['createdAt'], now),
    );
  }

  MeetingActionItem copyWith({
    String? id,
    String? meetingId,
    String? agendaItemId,
    String? description,
    String? assigneeId,
    String? assigneeName,
    DateTime? dueDate,
    String? status,
    String? completedNotes,
    DateTime? completedAt,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return MeetingActionItem(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      agendaItemId: agendaItemId ?? this.agendaItemId,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      completedNotes: completedNotes ?? this.completedNotes,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Minutes Item Record model (discussion record per agenda item)
class MinutesItemRecord {
  final String agendaItemId;
  final String agendaItemTitle;
  final String? discussion;
  final List<String> decisions;
  final List<MotionRecord> motions;
  final List<String> actionItemIds;

  MinutesItemRecord({
    required this.agendaItemId,
    required this.agendaItemTitle,
    this.discussion,
    this.decisions = const [],
    this.motions = const [],
    this.actionItemIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'agendaItemId': agendaItemId,
      'agendaItemTitle': agendaItemTitle,
      'discussion': discussion,
      'decisions': decisions,
      'motions': motions.map((m) => m.toMap()).toList(),
      'actionItemIds': actionItemIds,
    };
  }

  factory MinutesItemRecord.fromMap(Map<String, dynamic> map) {
    return MinutesItemRecord(
      agendaItemId: map['agendaItemId'] ?? '',
      agendaItemTitle: map['agendaItemTitle'] ?? '',
      discussion: map['discussion'],
      decisions: List<String>.from(map['decisions'] ?? []),
      motions: (map['motions'] as List<dynamic>?)
              ?.map((m) => MotionRecord.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      actionItemIds: List<String>.from(map['actionItemIds'] ?? []),
    );
  }

  MinutesItemRecord copyWith({
    String? agendaItemId,
    String? agendaItemTitle,
    String? discussion,
    List<String>? decisions,
    List<MotionRecord>? motions,
    List<String>? actionItemIds,
  }) {
    return MinutesItemRecord(
      agendaItemId: agendaItemId ?? this.agendaItemId,
      agendaItemTitle: agendaItemTitle ?? this.agendaItemTitle,
      discussion: discussion ?? this.discussion,
      decisions: decisions ?? this.decisions,
      motions: motions ?? this.motions,
      actionItemIds: actionItemIds ?? this.actionItemIds,
    );
  }
}

// Meeting Minutes model
class MeetingMinutes {
  final String id;
  final String meetingId;
  final String status; // 'draft', 'review', 'approved'
  final List<AttendanceRecord> attendance;
  final List<MinutesItemRecord> itemRecords;
  final DateTime? callToOrderTime;
  final DateTime? adjournmentTime;
  final DateTime? nextMeetingDate;
  final String? generalNotes;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MeetingMinutes({
    required this.id,
    required this.meetingId,
    this.status = 'draft',
    this.attendance = const [],
    this.itemRecords = const [],
    this.callToOrderTime,
    this.adjournmentTime,
    this.nextMeetingDate,
    this.generalNotes,
    this.approvedBy,
    this.approvedAt,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  MinutesStatus get minutesStatus => MinutesStatusExtension.fromString(status);

  int get presentCount => attendance.where((a) => a.status == 'present' || a.status == 'late').length;
  int get absentCount => attendance.where((a) => a.status == 'absent').length;
  int get excusedCount => attendance.where((a) => a.status == 'excused').length;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'meetingId': meetingId,
      'status': status,
      'attendance': attendance.map((a) => a.toMap()).toList(),
      'itemRecords': itemRecords.map((r) => r.toMap()).toList(),
      'callToOrderTime': callToOrderTime != null ? Timestamp.fromDate(callToOrderTime!) : null,
      'adjournmentTime': adjournmentTime != null ? Timestamp.fromDate(adjournmentTime!) : null,
      'nextMeetingDate': nextMeetingDate != null ? Timestamp.fromDate(nextMeetingDate!) : null,
      'generalNotes': generalNotes,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MeetingMinutes.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final now = DateTime.now();

    List<AttendanceRecord> parseAttendance(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((a) => AttendanceRecord.fromMap(a as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    List<MinutesItemRecord> parseItemRecords(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((r) => MinutesItemRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return MeetingMinutes(
      id: data['id'] ?? doc.id,
      meetingId: data['meetingId'] ?? '',
      status: data['status'] ?? 'draft',
      attendance: parseAttendance(data['attendance']),
      itemRecords: parseItemRecords(data['itemRecords']),
      callToOrderTime: data['callToOrderTime'] != null
          ? parseTimestamp(data['callToOrderTime'], now)
          : null,
      adjournmentTime: data['adjournmentTime'] != null
          ? parseTimestamp(data['adjournmentTime'], now)
          : null,
      nextMeetingDate: data['nextMeetingDate'] != null
          ? parseTimestamp(data['nextMeetingDate'], now)
          : null,
      generalNotes: data['generalNotes'],
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null
          ? parseTimestamp(data['approvedAt'], now)
          : null,
      createdBy: data['createdBy'] ?? '',
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: data['updatedAt'] != null
          ? parseTimestamp(data['updatedAt'], now)
          : null,
    );
  }

  MeetingMinutes copyWith({
    String? id,
    String? meetingId,
    String? status,
    List<AttendanceRecord>? attendance,
    List<MinutesItemRecord>? itemRecords,
    DateTime? callToOrderTime,
    DateTime? adjournmentTime,
    DateTime? nextMeetingDate,
    String? generalNotes,
    String? approvedBy,
    DateTime? approvedAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeetingMinutes(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      status: status ?? this.status,
      attendance: attendance ?? this.attendance,
      itemRecords: itemRecords ?? this.itemRecords,
      callToOrderTime: callToOrderTime ?? this.callToOrderTime,
      adjournmentTime: adjournmentTime ?? this.adjournmentTime,
      nextMeetingDate: nextMeetingDate ?? this.nextMeetingDate,
      generalNotes: generalNotes ?? this.generalNotes,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
