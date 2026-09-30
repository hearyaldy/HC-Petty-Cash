/// Step 3 — Strategic Intent.
///
/// From Workflow HC: "What transformation do we want to generate with
/// this program? What will attract the audience to our program? How
/// can we build audience to return to our program regularly? What
/// metrics will guide our project? What do we want?"
class StrategicIntent {
  final String transformation;
  final String attractionHook;
  final String retentionPlan;
  final List<String> metrics;

  const StrategicIntent({
    this.transformation = '',
    this.attractionHook = '',
    this.retentionPlan = '',
    this.metrics = const [],
  });

  bool get isEmpty =>
      transformation.isEmpty &&
      attractionHook.isEmpty &&
      retentionPlan.isEmpty &&
      metrics.isEmpty;

  StrategicIntent copyWith({
    String? transformation,
    String? attractionHook,
    String? retentionPlan,
    List<String>? metrics,
  }) {
    return StrategicIntent(
      transformation: transformation ?? this.transformation,
      attractionHook: attractionHook ?? this.attractionHook,
      retentionPlan: retentionPlan ?? this.retentionPlan,
      metrics: metrics ?? this.metrics,
    );
  }

  Map<String, dynamic> toMap() => {
        'transformation': transformation,
        'attractionHook': attractionHook,
        'retentionPlan': retentionPlan,
        'metrics': metrics,
      };

  factory StrategicIntent.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StrategicIntent();
    return StrategicIntent(
      transformation: map['transformation'] ?? '',
      attractionHook: map['attractionHook'] ?? '',
      retentionPlan: map['retentionPlan'] ?? '',
      metrics: List<String>.from(map['metrics'] ?? const []),
    );
  }
}
