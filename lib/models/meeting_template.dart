import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingTemplateType {
  agendaIntroduction,
  openingPrayer,
  closingPrayer,
  minutesHeader,
  resolutionTemplate,
}

extension MeetingTemplateTypeExtension on MeetingTemplateType {
  String get displayName {
    switch (this) {
      case MeetingTemplateType.agendaIntroduction:
        return 'Agenda Introduction';
      case MeetingTemplateType.openingPrayer:
        return 'Opening Prayer';
      case MeetingTemplateType.closingPrayer:
        return 'Closing Prayer';
      case MeetingTemplateType.minutesHeader:
        return 'Minutes Header';
      case MeetingTemplateType.resolutionTemplate:
        return 'Resolution Template';
    }
  }

  String get description {
    switch (this) {
      case MeetingTemplateType.agendaIntroduction:
        return 'Opening text displayed at the beginning of meeting agendas';
      case MeetingTemplateType.openingPrayer:
        return 'Prayer template for the start of meetings';
      case MeetingTemplateType.closingPrayer:
        return 'Prayer template for the end of meetings';
      case MeetingTemplateType.minutesHeader:
        return 'Header text for minutes documents';
      case MeetingTemplateType.resolutionTemplate:
        return 'Template format for meeting resolutions';
    }
  }
}

class MeetingTemplate {
  final String? id;
  final String name;
  final MeetingTemplateType type;
  final String organization; // 'ADCOM' or 'HC Board'
  final String content; // Plain text or Quill Delta JSON
  final bool isQuillFormat; // true if content is Quill Delta JSON
  final DateTime createdAt;
  final DateTime updatedAt;

  MeetingTemplate({
    this.id,
    required this.name,
    required this.type,
    required this.organization,
    required this.content,
    this.isQuillFormat = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory MeetingTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetingTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      type: MeetingTemplateType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => MeetingTemplateType.agendaIntroduction,
      ),
      organization: data['organization'] ?? 'ADCOM',
      content: data['content'] ?? '',
      isQuillFormat: data['isQuillFormat'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'organization': organization,
      'content': content,
      'isQuillFormat': isQuillFormat,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  MeetingTemplate copyWith({
    String? id,
    String? name,
    MeetingTemplateType? type,
    String? organization,
    String? content,
    bool? isQuillFormat,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeetingTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      organization: organization ?? this.organization,
      content: content ?? this.content,
      isQuillFormat: isQuillFormat ?? this.isQuillFormat,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Process template content by replacing placeholders with actual values
  String processContent({
    DateTime? meetingDate,
    String? meetingNumber,
    String? customOrganization,
  }) {
    String processed = _extractPlainTextContent();
    final date = meetingDate ?? DateTime.now();
    final org = customOrganization ?? organization;

    processed = processed.replaceAll('{{date}}', _formatDate(date));
    processed = processed.replaceAll('{{organization}}', org);
    processed = processed.replaceAll('{{meetingNumber}}', meetingNumber ?? '');
    processed = processed.replaceAll('{{year}}', date.year.toString());
    processed = processed.replaceAll(
      '{{fullDate}}',
      _formatFullDate(date),
    );

    return processed;
  }

  String _extractPlainTextContent() {
    if (!isQuillFormat || content.isEmpty) {
      return content;
    }
    try {
      final json = jsonDecode(content);
      if (json is List) {
        final buffer = StringBuffer();
        for (final op in json) {
          if (op is Map && op['insert'] != null) {
            buffer.write(op['insert']);
          }
        }
        return buffer.toString();
      }
    } catch (_) {
      // Fall through to return raw content if parsing fails.
    }
    return content;
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatFullDate(DateTime date) {
    final days = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday'
    ];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
