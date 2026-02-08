import 'package:cloud_firestore/cloud_firestore.dart';

enum AgendaActionType { recommended, voted, information, forDiscussion }

extension AgendaActionTypeExtension on AgendaActionType {
  String get displayName {
    switch (this) {
      case AgendaActionType.recommended:
        return 'Recommended';
      case AgendaActionType.voted:
        return 'Voted';
      case AgendaActionType.information:
        return 'Information';
      case AgendaActionType.forDiscussion:
        return 'For Discussion';
    }
  }

  static AgendaActionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'recommended':
        return AgendaActionType.recommended;
      case 'voted':
        return AgendaActionType.voted;
      case 'information':
        return AgendaActionType.information;
      case 'fordiscussion':
      case 'for discussion':
        return AgendaActionType.forDiscussion;
      default:
        return AgendaActionType.recommended;
    }
  }
}

class AgendaItem {
  final String id;
  final String itemNumber; // e.g., "05/02-AD001"
  final String title; // Will be displayed in CAPS
  final AgendaActionType actionType;
  final String description;
  final int order;

  AgendaItem({
    required this.id,
    required this.itemNumber,
    required this.title,
    required this.actionType,
    required this.description,
    required this.order,
  });

  factory AgendaItem.fromMap(Map<String, dynamic> map, String id) {
    return AgendaItem(
      id: id,
      itemNumber: map['itemNumber'] ?? '',
      title: map['title'] ?? '',
      actionType: AgendaActionTypeExtension.fromString(
        map['actionType'] ?? 'recommended',
      ),
      description: map['description'] ?? '',
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemNumber': itemNumber,
      'title': title,
      'actionType': actionType.displayName.toLowerCase().replaceAll(' ', ''),
      'description': description,
      'order': order,
    };
  }

  AgendaItem copyWith({
    String? id,
    String? itemNumber,
    String? title,
    AgendaActionType? actionType,
    String? description,
    int? order,
  }) {
    return AgendaItem(
      id: id ?? this.id,
      itemNumber: itemNumber ?? this.itemNumber,
      title: title ?? this.title,
      actionType: actionType ?? this.actionType,
      description: description ?? this.description,
      order: order ?? this.order,
    );
  }
}

class AttendanceMember {
  final String name;
  final String affiliation; // HC, SEUM, etc.
  final bool isPresent;
  final bool isAbsentWithApology;

  AttendanceMember({
    required this.name,
    required this.affiliation,
    this.isPresent = true,
    this.isAbsentWithApology = false,
  });

  factory AttendanceMember.fromMap(Map<String, dynamic> map) {
    return AttendanceMember(
      name: map['name'] ?? '',
      affiliation: map['affiliation'] ?? '',
      isPresent: map['isPresent'] ?? true,
      isAbsentWithApology: map['isAbsentWithApology'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'affiliation': affiliation,
      'isPresent': isPresent,
      'isAbsentWithApology': isAbsentWithApology,
    };
  }
}

class AdcomAgenda {
  final String id;
  final String organization;
  final DateTime meetingDate;
  final String meetingTime;
  final String? startTime;
  final String location;
  final List<AttendanceMember> attendanceMembers;
  final List<AgendaItem> agendaItems;
  final List<dynamic>? agendaContent; // Quill delta JSON
  final String? openingPrayer;
  final String? closingPrayer;
  final String? meetingAdjournedAt;
  final String status; // draft, finalized
  final int
  startingItemSequence; // Starting sequence number for first agenda item
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  AdcomAgenda({
    required this.id,
    this.organization = 'HOPE CHANNEL SOUTHEAST ASIA',
    required this.meetingDate,
    required this.meetingTime,
    this.startTime,
    required this.location,
    this.attendanceMembers = const [],
    this.agendaItems = const [],
    this.agendaContent,
    this.openingPrayer,
    this.closingPrayer,
    this.meetingAdjournedAt,
    this.status = 'draft',
    this.startingItemSequence = 1,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory AdcomAgenda.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdcomAgenda(
      id: doc.id,
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
      agendaContent: data['agendaContent'] as List<dynamic>?,
      agendaItems:
          (data['agendaItems'] as List<dynamic>?)
              ?.asMap()
              .entries
              .map(
                (e) => AgendaItem.fromMap(
                  e.value as Map<String, dynamic>,
                  'item_${e.key}',
                ),
              )
              .toList() ??
          [],
      openingPrayer: data['openingPrayer'],
      closingPrayer: data['closingPrayer'],
      meetingAdjournedAt: data['meetingAdjournedAt'],
      status: data['status'] ?? 'draft',
      startingItemSequence: data['startingItemSequence'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organization': organization,
      'meetingDate': Timestamp.fromDate(meetingDate),
      'meetingTime': meetingTime,
      'startTime': startTime,
      'location': location,
      'attendanceMembers': attendanceMembers.map((m) => m.toMap()).toList(),
      'agendaContent': agendaContent ?? [],
      'agendaItems': agendaItems.map((a) => a.toMap()).toList(),
      'openingPrayer': openingPrayer,
      'closingPrayer': closingPrayer,
      'meetingAdjournedAt': meetingAdjournedAt,
      'status': status,
      'startingItemSequence': startingItemSequence,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  AdcomAgenda copyWith({
    String? id,
    String? organization,
    DateTime? meetingDate,
    String? meetingTime,
    String? startTime,
    String? location,
    List<AttendanceMember>? attendanceMembers,
    List<AgendaItem>? agendaItems,
    List<dynamic>? agendaContent,
    String? openingPrayer,
    String? closingPrayer,
    String? meetingAdjournedAt,
    String? status,
    int? startingItemSequence,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return AdcomAgenda(
      id: id ?? this.id,
      organization: organization ?? this.organization,
      meetingDate: meetingDate ?? this.meetingDate,
      meetingTime: meetingTime ?? this.meetingTime,
      startTime: startTime ?? this.startTime,
      location: location ?? this.location,
      attendanceMembers: attendanceMembers ?? this.attendanceMembers,
      agendaItems: agendaItems ?? this.agendaItems,
      agendaContent: agendaContent ?? this.agendaContent,
      openingPrayer: openingPrayer ?? this.openingPrayer,
      closingPrayer: closingPrayer ?? this.closingPrayer,
      meetingAdjournedAt: meetingAdjournedAt ?? this.meetingAdjournedAt,
      status: status ?? this.status,
      startingItemSequence: startingItemSequence ?? this.startingItemSequence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Generate item number based on meeting date and sequence
  /// Format: DD/MM-ADXXX (e.g., 05/02-AD001)
  static String generateItemNumber(DateTime meetingDate, int sequence) {
    final day = meetingDate.day.toString().padLeft(2, '0');
    final month = meetingDate.month.toString().padLeft(2, '0');
    final seq = sequence.toString().padLeft(3, '0');
    return '$day/$month-AD$seq';
  }
}
