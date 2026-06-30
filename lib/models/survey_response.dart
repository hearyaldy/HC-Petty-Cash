import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyAnswer {
  final String questionId;
  // String for singleChoice/yesNo/openText, List<String> for multipleChoice, int for scale
  final dynamic value;

  const SurveyAnswer({required this.questionId, required this.value});

  factory SurveyAnswer.fromMap(Map<String, dynamic> m) => SurveyAnswer(
        questionId: m['questionId'] as String,
        value: m['value'],
      );

  Map<String, dynamic> toMap() => {'questionId': questionId, 'value': value};

  String get displayValue {
    if (value is List) return (value as List).join(', ');
    return value?.toString() ?? '';
  }
}

class SurveyResponse {
  final String id;
  final String surveyId;
  final String surveyCode;
  final String? respondentId;
  final String? respondentName;
  final String? country;
  final DateTime submittedAt;
  final List<SurveyAnswer> answers;

  const SurveyResponse({
    required this.id,
    required this.surveyId,
    required this.surveyCode,
    this.respondentId,
    this.respondentName,
    this.country,
    required this.submittedAt,
    required this.answers,
  });

  factory SurveyResponse.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return SurveyResponse(
      id: doc.id,
      surveyId: m['surveyId'] as String? ?? '',
      surveyCode: m['surveyCode'] as String? ?? '',
      respondentId: m['respondentId'] as String?,
      respondentName: m['respondentName'] as String?,
      country: m['country'] as String?,
      submittedAt:
          (m['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      answers: (m['answers'] as List? ?? [])
          .map((a) => SurveyAnswer.fromMap(a as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'surveyId': surveyId,
        'surveyCode': surveyCode,
        if (respondentId != null) 'respondentId': respondentId,
        if (respondentName != null) 'respondentName': respondentName,
        if (country != null) 'country': country,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'answers': answers.map((a) => a.toMap()).toList(),
      };

  SurveyAnswer? answerFor(String questionId) =>
      answers.cast<SurveyAnswer?>().firstWhere(
            (a) => a?.questionId == questionId,
            orElse: () => null,
          );
}
