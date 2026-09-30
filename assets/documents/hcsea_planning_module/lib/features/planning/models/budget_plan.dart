/// Step 7 — Budget.
///
/// From Workflow HC's own benchmark reference table:
///   Pre-production        10%  Planning, research, script and initial organization.
///   Production            30%  Recruitment, technical team, operation and execution.
///   Post-production       10%  Editing, finishing, audio and image adjustments.
///   Distribution          45%  Distribution, media, boosting and promotion.
///   Closure & documentation 5% Reports, final organization and registration.
class BudgetPhaseSplit {
  final double preProductionPct;
  final double productionPct;
  final double postProductionPct;
  final double distributionPct;
  final double closurePct;

  /// The exact benchmark split published in Workflow HC. Used as the
  /// starting point for the Budget Allocator before any project-specific
  /// history exists (Phase 4 of the rollout replaces this with an
  /// average of the user's own logged projects).
  static const BudgetPhaseSplit workflowHcBenchmark = BudgetPhaseSplit(
    preProductionPct: 0.10,
    productionPct: 0.30,
    postProductionPct: 0.10,
    distributionPct: 0.45,
    closurePct: 0.05,
  );

  const BudgetPhaseSplit({
    required this.preProductionPct,
    required this.productionPct,
    required this.postProductionPct,
    required this.distributionPct,
    required this.closurePct,
  });

  Map<String, dynamic> toMap() => {
        'preProductionPct': preProductionPct,
        'productionPct': productionPct,
        'postProductionPct': postProductionPct,
        'distributionPct': distributionPct,
        'closurePct': closurePct,
      };

  factory BudgetPhaseSplit.fromMap(Map<String, dynamic> map) {
    return BudgetPhaseSplit(
      preProductionPct: (map['preProductionPct'] ?? 0.10).toDouble(),
      productionPct: (map['productionPct'] ?? 0.30).toDouble(),
      postProductionPct: (map['postProductionPct'] ?? 0.10).toDouble(),
      distributionPct: (map['distributionPct'] ?? 0.45).toDouble(),
      closurePct: (map['closurePct'] ?? 0.05).toDouble(),
    );
  }
}

class BudgetPlan {
  final double total;
  final String currency; // e.g. 'THB', 'MYR', 'USD'
  final BudgetPhaseSplit split;

  const BudgetPlan({
    this.total = 0,
    this.currency = 'USD',
    this.split = BudgetPhaseSplit.workflowHcBenchmark,
  });

  double get preProduction => total * split.preProductionPct;
  double get production => total * split.productionPct;
  double get postProduction => total * split.postProductionPct;
  double get distribution => total * split.distributionPct;
  double get closure => total * split.closurePct;

  bool get isEmpty => total == 0;

  BudgetPlan copyWith({
    double? total,
    String? currency,
    BudgetPhaseSplit? split,
  }) {
    return BudgetPlan(
      total: total ?? this.total,
      currency: currency ?? this.currency,
      split: split ?? this.split,
    );
  }

  Map<String, dynamic> toMap() => {
        'total': total,
        'currency': currency,
        'split': split.toMap(),
      };

  factory BudgetPlan.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BudgetPlan();
    return BudgetPlan(
      total: (map['total'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'USD',
      split: map['split'] != null
          ? BudgetPhaseSplit.fromMap(Map<String, dynamic>.from(map['split']))
          : BudgetPhaseSplit.workflowHcBenchmark,
    );
  }
}
