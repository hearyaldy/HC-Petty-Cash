import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestionType {
  singleChoice,
  multipleChoice,
  scale,
  openText,
  yesNo;

  static QuestionType fromString(String v) => switch (v) {
        'multipleChoice' => multipleChoice,
        'scale' => scale,
        'openText' => openText,
        'yesNo' => yesNo,
        _ => singleChoice,
      };
}

class SurveyQuestion {
  final String id;
  final String code;
  final String text;
  final QuestionType type;
  final List<String> options;
  final bool isRequired;
  final int? maxSelections;
  final int? scaleMin;
  final int? scaleMax;
  final String? scaleMinLabel;
  final String? scaleMaxLabel;
  final String? note;
  final String? conditionalOnId;
  final List<String>? conditionalOnValues;

  const SurveyQuestion({
    required this.id,
    required this.code,
    required this.text,
    required this.type,
    this.options = const [],
    this.isRequired = true,
    this.maxSelections,
    this.scaleMin,
    this.scaleMax,
    this.scaleMinLabel,
    this.scaleMaxLabel,
    this.note,
    this.conditionalOnId,
    this.conditionalOnValues,
  });

  factory SurveyQuestion.fromMap(Map<String, dynamic> m) => SurveyQuestion(
        id: m['id'] as String,
        code: m['code'] as String? ?? '',
        text: m['text'] as String,
        type: QuestionType.fromString(m['type'] as String? ?? 'singleChoice'),
        options: List<String>.from(m['options'] as List? ?? []),
        isRequired: m['isRequired'] as bool? ?? true,
        maxSelections: m['maxSelections'] as int?,
        scaleMin: m['scaleMin'] as int?,
        scaleMax: m['scaleMax'] as int?,
        scaleMinLabel: m['scaleMinLabel'] as String?,
        scaleMaxLabel: m['scaleMaxLabel'] as String?,
        note: m['note'] as String?,
        conditionalOnId: m['conditionalOnId'] as String?,
        conditionalOnValues: m['conditionalOnValues'] != null
            ? List<String>.from(m['conditionalOnValues'] as List)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'text': text,
        'type': type.name,
        'options': options,
        'isRequired': isRequired,
        if (maxSelections != null) 'maxSelections': maxSelections,
        if (scaleMin != null) 'scaleMin': scaleMin,
        if (scaleMax != null) 'scaleMax': scaleMax,
        if (scaleMinLabel != null) 'scaleMinLabel': scaleMinLabel,
        if (scaleMaxLabel != null) 'scaleMaxLabel': scaleMaxLabel,
        if (note != null) 'note': note,
        if (conditionalOnId != null) 'conditionalOnId': conditionalOnId,
        if (conditionalOnValues != null)
          'conditionalOnValues': conditionalOnValues,
      };
}

/// A routing rule on a section: if [questionId] answer is in [matchValues],
/// jump to [targetSectionIndex] (survey.sections.length == "End survey").
class SectionCondition {
  final String questionId;
  final List<String> matchValues;
  final int targetSectionIndex;

  const SectionCondition({
    required this.questionId,
    required this.matchValues,
    required this.targetSectionIndex,
  });

  factory SectionCondition.fromMap(Map<String, dynamic> m) => SectionCondition(
        questionId: m['questionId'] as String? ?? '',
        matchValues: List<String>.from(m['matchValues'] as List? ?? []),
        targetSectionIndex: m['targetSectionIndex'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        'matchValues': matchValues,
        'targetSectionIndex': targetSectionIndex,
      };
}

class SurveySection {
  final String title;
  final String subtitle;
  final List<SurveyQuestion> questions;
  /// Routing conditions evaluated in order after this section completes.
  final List<SectionCondition> conditions;
  /// Where to go if no condition matches. null = next section.
  /// survey.sections.length = end of survey.
  final int? defaultNext;

  const SurveySection({
    required this.title,
    required this.subtitle,
    required this.questions,
    this.conditions = const [],
    this.defaultNext,
  });

  factory SurveySection.fromMap(Map<String, dynamic> m) => SurveySection(
        title: m['title'] as String,
        subtitle: m['subtitle'] as String? ?? '',
        questions: (m['questions'] as List? ?? [])
            .map((q) => SurveyQuestion.fromMap(q as Map<String, dynamic>))
            .toList(),
        conditions: (m['conditions'] as List? ?? [])
            .map((c) => SectionCondition.fromMap(c as Map<String, dynamic>))
            .toList(),
        defaultNext: m['defaultNext'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'subtitle': subtitle,
        'questions': questions.map((q) => q.toMap()).toList(),
        'conditions': conditions.map((c) => c.toMap()).toList(),
        if (defaultNext != null) 'defaultNext': defaultNext,
      };
}

class Survey {
  final String id;
  final String code;
  final String title;
  final String description;
  final String targetAudience;
  final bool isActive;
  final bool isPublic;
  final int estimatedMinutes;
  final List<SurveySection> sections;
  final DateTime createdAt;

  const Survey({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.targetAudience,
    required this.isActive,
    required this.isPublic,
    required this.estimatedMinutes,
    required this.sections,
    required this.createdAt,
  });

  int get totalQuestions =>
      sections.fold(0, (acc, s) => acc + s.questions.length);

  factory Survey.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return Survey(
      id: doc.id,
      code: m['code'] as String? ?? '',
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      targetAudience: m['targetAudience'] as String? ?? 'public',
      isActive: m['isActive'] as bool? ?? false,
      isPublic: m['isPublic'] as bool? ?? false,
      estimatedMinutes: m['estimatedMinutes'] as int? ?? 10,
      sections: (m['sections'] as List? ?? [])
          .map((s) => SurveySection.fromMap(s as Map<String, dynamic>))
          .toList(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'code': code,
        'title': title,
        'description': description,
        'targetAudience': targetAudience,
        'isActive': isActive,
        'isPublic': isPublic,
        'estimatedMinutes': estimatedMinutes,
        'sections': sections.map((s) => s.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
