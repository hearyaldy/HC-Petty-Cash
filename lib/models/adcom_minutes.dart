import 'package:cloud_firestore/cloud_firestore.dart';
import 'adcom_agenda.dart';

enum MinutesItemStatus { voted, tabled, discussed, pending }

extension MinutesItemStatusExtension on MinutesItemStatus {
  String get displayName {
    switch (this) {
      case MinutesItemStatus.voted:
        return 'VOTED';
      case MinutesItemStatus.tabled:
        return 'TABLE';
      case MinutesItemStatus.discussed:
        return 'DISCUSSED';
      case MinutesItemStatus.pending:
        return 'PENDING';
    }
  }

  static MinutesItemStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'voted':
        return MinutesItemStatus.voted;
      case 'tabled':
      case 'table':
        return MinutesItemStatus.tabled;
      case 'discussed':
        return MinutesItemStatus.discussed;
      case 'pending':
      default:
        return MinutesItemStatus.pending;
    }
  }
}

class MinutesItem {
  final String id;
  final String itemNumber; // e.g., "05/02-AD001"
  final String title; // Will be displayed in CAPS
  final AgendaActionType actionType; // From original agenda
  final String description;
  final MinutesItemStatus status; // Voted, Tabled, Discussed
  final String? resolution; // Resolution text if voted
  final String? notes; // Additional notes or discussion points
  final int order;
  final bool isNewItem; // True if added during meeting

  MinutesItem({
    required this.id,
    required this.itemNumber,
    required this.title,
    required this.actionType,
    required this.description,
    this.status = MinutesItemStatus.pending,
    this.resolution,
    this.notes,
    required this.order,
    this.isNewItem = false,
  });

  factory MinutesItem.fromMap(Map<String, dynamic> map, String id) {
    return MinutesItem(
      id: id,
      itemNumber: map['itemNumber'] ?? '',
      title: map['title'] ?? '',
      actionType: AgendaActionTypeExtension.fromString(
        map['actionType'] ?? 'recommended',
      ),
      description: map['description'] ?? '',
      status: MinutesItemStatusExtension.fromString(map['status'] ?? 'pending'),
      resolution: map['resolution'],
      notes: map['notes'],
      order: map['order'] ?? 0,
      isNewItem: map['isNewItem'] ?? false,
    );
  }

  factory MinutesItem.fromAgendaItem(AgendaItem agendaItem) {
    return MinutesItem(
      id: agendaItem.id,
      itemNumber: agendaItem.itemNumber,
      title: agendaItem.title,
      actionType: agendaItem.actionType,
      description: agendaItem.description,
      status: MinutesItemStatus.pending,
      order: agendaItem.order,
      isNewItem: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemNumber': itemNumber,
      'title': title,
      'actionType': actionType.displayName.toLowerCase().replaceAll(' ', ''),
      'description': description,
      'status': status.displayName.toLowerCase(),
      'resolution': resolution,
      'notes': notes,
      'order': order,
      'isNewItem': isNewItem,
    };
  }

  MinutesItem copyWith({
    String? id,
    String? itemNumber,
    String? title,
    AgendaActionType? actionType,
    String? description,
    MinutesItemStatus? status,
    String? resolution,
    String? notes,
    int? order,
    bool? isNewItem,
  }) {
    return MinutesItem(
      id: id ?? this.id,
      itemNumber: itemNumber ?? this.itemNumber,
      title: title ?? this.title,
      actionType: actionType ?? this.actionType,
      description: description ?? this.description,
      status: status ?? this.status,
      resolution: resolution ?? this.resolution,
      notes: notes ?? this.notes,
      order: order ?? this.order,
      isNewItem: isNewItem ?? this.isNewItem,
    );
  }
}

class AdcomMinutes {
  final String id;
  final String agendaId; // Reference to the original agenda
  final String organization;
  final DateTime meetingDate;
  final String meetingTime;
  final String? startTime;
  final String location;
  final List<AttendanceMember> attendanceMembers;
  final List<MinutesItem> minutesItems;
  final String? openingPrayer;
  final String? closingPrayer;
  final String? meetingAdjournedAt;
  final String? chairperson;
  final String? secretary;
  final String status; // draft, finalized
  final int startingItemSequence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  AdcomMinutes({
    required this.id,
    required this.agendaId,
    this.organization = 'HOPE CHANNEL SOUTHEAST ASIA',
    required this.meetingDate,
    required this.meetingTime,
    this.startTime,
    required this.location,
    this.attendanceMembers = const [],
    this.minutesItems = const [],
    this.openingPrayer,
    this.closingPrayer,
    this.meetingAdjournedAt,
    this.chairperson,
    this.secretary,
    this.status = 'draft',
    this.startingItemSequence = 1,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory AdcomMinutes.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdcomMinutes(
      id: doc.id,
      agendaId: data['agendaId'] ?? '',
      organization: data['organization'] ?? 'HOPE CHANNEL SOUTHEAST ASIA',
      meetingDate: (data['meetingDate'] as Timestamp).toDate(),
      meetingTime: data['meetingTime'] ?? '',
      startTime: data['startTime'],
      location: data['location'] ?? '',
      attendanceMembers:
          (data['attendanceMembers'] as List<dynamic>?)
              ?.map((m) => AttendanceMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      minutesItems:
          (data['minutesItems'] as List<dynamic>?)
              ?.asMap()
              .entries
              .map(
                (e) => MinutesItem.fromMap(
                  e.value as Map<String, dynamic>,
                  'item_${e.key}',
                ),
              )
              .toList() ??
          [],
      openingPrayer: data['openingPrayer'],
      closingPrayer: data['closingPrayer'],
      meetingAdjournedAt: data['meetingAdjournedAt'],
      chairperson: data['chairperson'],
      secretary: data['secretary'],
      status: data['status'] ?? 'draft',
      startingItemSequence: data['startingItemSequence'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  factory AdcomMinutes.fromAgenda(AdcomAgenda agenda, String minutesId) {
    return AdcomMinutes(
      id: minutesId,
      agendaId: agenda.id,
      organization: agenda.organization,
      meetingDate: agenda.meetingDate,
      meetingTime: agenda.meetingTime,
      startTime: agenda.startTime,
      location: agenda.location,
      attendanceMembers: agenda.attendanceMembers,
      minutesItems: agenda.agendaItems
          .map((item) => MinutesItem.fromAgendaItem(item))
          .toList(),
      openingPrayer: agenda.openingPrayer,
      closingPrayer: agenda.closingPrayer,
      meetingAdjournedAt: agenda.meetingAdjournedAt,
      status: 'draft',
      startingItemSequence: agenda.startingItemSequence,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: agenda.createdBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agendaId': agendaId,
      'organization': organization,
      'meetingDate': Timestamp.fromDate(meetingDate),
      'meetingTime': meetingTime,
      'startTime': startTime,
      'location': location,
      'attendanceMembers': attendanceMembers.map((m) => m.toMap()).toList(),
      'minutesItems': minutesItems.map((m) => m.toMap()).toList(),
      'openingPrayer': openingPrayer,
      'closingPrayer': closingPrayer,
      'meetingAdjournedAt': meetingAdjournedAt,
      'chairperson': chairperson,
      'secretary': secretary,
      'status': status,
      'startingItemSequence': startingItemSequence,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  AdcomMinutes copyWith({
    String? id,
    String? agendaId,
    String? organization,
    DateTime? meetingDate,
    String? meetingTime,
    String? startTime,
    String? location,
    List<AttendanceMember>? attendanceMembers,
    List<MinutesItem>? minutesItems,
    String? openingPrayer,
    String? closingPrayer,
    String? meetingAdjournedAt,
    String? chairperson,
    String? secretary,
    String? status,
    int? startingItemSequence,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return AdcomMinutes(
      id: id ?? this.id,
      agendaId: agendaId ?? this.agendaId,
      organization: organization ?? this.organization,
      meetingDate: meetingDate ?? this.meetingDate,
      meetingTime: meetingTime ?? this.meetingTime,
      startTime: startTime ?? this.startTime,
      location: location ?? this.location,
      attendanceMembers: attendanceMembers ?? this.attendanceMembers,
      minutesItems: minutesItems ?? this.minutesItems,
      openingPrayer: openingPrayer ?? this.openingPrayer,
      closingPrayer: closingPrayer ?? this.closingPrayer,
      meetingAdjournedAt: meetingAdjournedAt ?? this.meetingAdjournedAt,
      chairperson: chairperson ?? this.chairperson,
      secretary: secretary ?? this.secretary,
      status: status ?? this.status,
      startingItemSequence: startingItemSequence ?? this.startingItemSequence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Generate item number based on meeting date, sequence, and organization
  /// Format for ADCOM: DD/MM-ADXXX (e.g., 05/02-AD001)
  /// Format for HC Board: DD/MM-XXX (e.g., 10/02-024)
  static String generateItemNumber(
    DateTime meetingDate,
    int sequence, {
    String organization = 'ADCOM',
  }) {
    final day = meetingDate.day.toString().padLeft(2, '0');
    final month = meetingDate.month.toString().padLeft(2, '0');
    final seq = sequence.toString().padLeft(3, '0');

    // Check if organization is ADCOM (case-insensitive)
    final isAdcom = organization.toUpperCase().contains('ADCOM');

    if (isAdcom) {
      return '$day/$month-AD$seq';
    } else {
      return '$day/$month-$seq';
    }
  }
}
