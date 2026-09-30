/// Step 1 — General Objective of the Project.
///
/// Directly from Workflow HC, First stage: Planning:
///   "Identify the order of importance of the metrics: reach,
///   engagement, and connection. What pains do we need to attend?
///   Why does this program exist? Do we have practical conditions
///   to meet this pain?"
class Objective {
  final List<String> pains;
  final String whyItExists;
  final String practicalConditions;
  final List<String> metricPriority; // e.g. ['reach', 'engagement', 'connection']

  const Objective({
    this.pains = const [],
    this.whyItExists = '',
    this.practicalConditions = '',
    this.metricPriority = const [],
  });

  bool get isEmpty =>
      pains.isEmpty && whyItExists.isEmpty && practicalConditions.isEmpty;

  Objective copyWith({
    List<String>? pains,
    String? whyItExists,
    String? practicalConditions,
    List<String>? metricPriority,
  }) {
    return Objective(
      pains: pains ?? this.pains,
      whyItExists: whyItExists ?? this.whyItExists,
      practicalConditions: practicalConditions ?? this.practicalConditions,
      metricPriority: metricPriority ?? this.metricPriority,
    );
  }

  Map<String, dynamic> toMap() => {
        'pains': pains,
        'whyItExists': whyItExists,
        'practicalConditions': practicalConditions,
        'metricPriority': metricPriority,
      };

  factory Objective.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const Objective();
    return Objective(
      pains: List<String>.from(map['pains'] ?? const []),
      whyItExists: map['whyItExists'] ?? '',
      practicalConditions: map['practicalConditions'] ?? '',
      metricPriority: List<String>.from(map['metricPriority'] ?? const []),
    );
  }
}
