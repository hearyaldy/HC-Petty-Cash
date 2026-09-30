/// Step 2 — Audience.
///
/// From Workflow HC: "Gender, Age, Social situation, Activity: student,
/// entrepreneur, farmer, etc., Geography, Who is not the target
/// audience of this project?"
class Audience {
  final String gender;
  final String ageRange;
  final String socialSituation;
  final String activity;
  final String geography;
  final String notAudience;

  const Audience({
    this.gender = '',
    this.ageRange = '',
    this.socialSituation = '',
    this.activity = '',
    this.geography = '',
    this.notAudience = '',
  });

  bool get isEmpty =>
      gender.isEmpty &&
      ageRange.isEmpty &&
      socialSituation.isEmpty &&
      activity.isEmpty &&
      geography.isEmpty &&
      notAudience.isEmpty;

  Audience copyWith({
    String? gender,
    String? ageRange,
    String? socialSituation,
    String? activity,
    String? geography,
    String? notAudience,
  }) {
    return Audience(
      gender: gender ?? this.gender,
      ageRange: ageRange ?? this.ageRange,
      socialSituation: socialSituation ?? this.socialSituation,
      activity: activity ?? this.activity,
      geography: geography ?? this.geography,
      notAudience: notAudience ?? this.notAudience,
    );
  }

  Map<String, dynamic> toMap() => {
        'gender': gender,
        'ageRange': ageRange,
        'socialSituation': socialSituation,
        'activity': activity,
        'geography': geography,
        'notAudience': notAudience,
      };

  factory Audience.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const Audience();
    return Audience(
      gender: map['gender'] ?? '',
      ageRange: map['ageRange'] ?? '',
      socialSituation: map['socialSituation'] ?? '',
      activity: map['activity'] ?? '',
      geography: map['geography'] ?? '',
      notAudience: map['notAudience'] ?? '',
    );
  }
}
