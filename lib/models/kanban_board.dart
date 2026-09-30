import 'package:cloud_firestore/cloud_firestore.dart';

/// A Trello-style board. Top-level Firestore doc at `boards/{boardId}`.
class KanbanBoard {
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;
  final bool archived;

  const KanbanBoard({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
    this.archived = false,
  });

  factory KanbanBoard.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return KanbanBoard(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      memberIds: (data['memberIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      archived: data['archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'archived': archived,
    };
  }

  KanbanBoard copyWith({
    String? title,
    String? description,
    List<String>? memberIds,
    bool? archived,
  }) {
    return KanbanBoard(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerId: ownerId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt,
      archived: archived ?? this.archived,
    );
  }
}

/// A column on a board. Subcollection doc at `boards/{boardId}/lists/{listId}`.
class KanbanList {
  final String id;
  final String title;
  final double order;
  final DateTime createdAt;

  const KanbanList({
    required this.id,
    required this.title,
    required this.order,
    required this.createdAt,
  });

  factory KanbanList.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return KanbanList(
      id: doc.id,
      title: data['title'] as String? ?? '',
      order: (data['order'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  KanbanList copyWith({String? title, double? order}) {
    return KanbanList(
      id: id,
      title: title ?? this.title,
      order: order ?? this.order,
      createdAt: createdAt,
    );
  }
}

/// One checklist row embedded on a card — not its own Firestore doc.
class KanbanChecklistItem {
  final String text;
  final bool done;

  const KanbanChecklistItem({required this.text, this.done = false});

  factory KanbanChecklistItem.fromMap(Map<String, dynamic> map) {
    return KanbanChecklistItem(
      text: map['text'] as String? ?? '',
      done: map['done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {'text': text, 'done': done};

  KanbanChecklistItem copyWith({String? text, bool? done}) {
    return KanbanChecklistItem(text: text ?? this.text, done: done ?? this.done);
  }
}

/// A card. Subcollection doc at `boards/{boardId}/lists/{listId}/cards/{cardId}`.
class KanbanCard {
  final String id;
  final String title;
  final String description;
  final List<String> assigneeIds;
  final DateTime? dueDate;
  final List<String> labels;
  final double order;
  final List<KanbanChecklistItem> checklist;
  final List<String> attachmentUrls;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KanbanCard({
    required this.id,
    required this.title,
    required this.description,
    required this.assigneeIds,
    required this.dueDate,
    required this.labels,
    required this.order,
    required this.checklist,
    required this.attachmentUrls,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KanbanCard.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return KanbanCard(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      assigneeIds: (data['assigneeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      labels: (data['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      order: (data['order'] as num?)?.toDouble() ?? 0,
      checklist: (data['checklist'] as List<dynamic>?)
              ?.map((e) => KanbanChecklistItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      attachmentUrls: (data['attachmentUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'assigneeIds': assigneeIds,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'labels': labels,
      'order': order,
      'checklist': checklist.map((e) => e.toMap()).toList(),
      'attachmentUrls': attachmentUrls,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  KanbanCard copyWith({
    String? title,
    String? description,
    List<String>? assigneeIds,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<String>? labels,
    double? order,
    List<KanbanChecklistItem>? checklist,
    List<String>? attachmentUrls,
    DateTime? updatedAt,
  }) {
    return KanbanCard(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      labels: labels ?? this.labels,
      order: order ?? this.order,
      checklist: checklist ?? this.checklist,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Order spacing helpers so a single drag only rewrites the one card/list
/// that moved, instead of every sibling.
class KanbanOrder {
  static const double _gap = 1024;

  static double first() => _gap;

  static double after(double order) => order + _gap;

  static double before(double order) => order - _gap;

  /// Order value for a drop between [prevOrder] and [nextOrder] — either
  /// may be null when dropping at the very start/end of a list.
  static double between(double? prevOrder, double? nextOrder) {
    if (prevOrder == null && nextOrder == null) return first();
    if (prevOrder == null) return before(nextOrder!);
    if (nextOrder == null) return after(prevOrder);
    return (prevOrder + nextOrder) / 2;
  }
}
