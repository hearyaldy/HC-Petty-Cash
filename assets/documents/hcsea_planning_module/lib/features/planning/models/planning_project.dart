import 'package:cloud_firestore/cloud_firestore.dart';

import 'approval_item.dart';
import 'audience.dart';
import 'budget_plan.dart';
import 'distribution_plan.dart';
import 'market_research.dart';
import 'objective.dart';
import 'program_identity.dart';
import 'strategic_intent.dart';

/// A single HCSEA production project, shaped after Workflow HC's
/// Planning stage. This is the document stored at
/// `projects/{projectId}` inside hopechannel.asia's existing
/// Firestore project — see README.md for how the `planning` map
/// nests alongside whatever fields other modules (Pre-production,
/// Production, etc.) already read from the same document.
class PlanningProject {
  final String id;
  final String title;
  final String country; // Cambodia, Laos, Malaysia, Brunei, Thailand, Vietnam
  final String ownerUid;
  final String ownerName;
  final DateTime createdAt;
  final DateTime updatedAt;

  final Objective objective;
  final Audience audience;
  final StrategicIntent strategicIntent;
  final MarketResearch marketResearch;
  final ProgramIdentity identity;
  final DistributionPlan distribution;
  final BudgetPlan budget;
  final List<ApprovalItem> approvals;

  const PlanningProject({
    required this.id,
    this.title = '',
    this.country = '',
    this.ownerUid = '',
    this.ownerName = '',
    required this.createdAt,
    required this.updatedAt,
    this.objective = const Objective(),
    this.audience = const Audience(),
    this.strategicIntent = const StrategicIntent(),
    this.marketResearch = const MarketResearch(),
    this.identity = const ProgramIdentity(),
    this.distribution = const DistributionPlan(),
    this.budget = const BudgetPlan(),
    this.approvals = const [],
  });

  /// A brand-new project, pre-populated with the standard Planning
  /// checklist so it doesn't open blank.
  factory PlanningProject.newDraft({
    required String id,
    required String title,
    required String country,
    required String ownerUid,
    required String ownerName,
  }) {
    final now = DateTime.now();
    return PlanningProject(
      id: id,
      title: title,
      country: country,
      ownerUid: ownerUid,
      ownerName: ownerName,
      createdAt: now,
      updatedAt: now,
      approvals: ApprovalItem.defaultPlanningChecklist(),
    );
  }

  /// How many of the 8 Planning steps have real content — drives the
  /// progress indicator on the stage rail / project list.
  int get completedStepCount => [
        !objective.isEmpty,
        !audience.isEmpty,
        !strategicIntent.isEmpty,
        !marketResearch.isEmpty,
        !identity.isEmpty,
        !distribution.isEmpty,
        !budget.isEmpty,
        approvals.isNotEmpty &&
            approvals.every((a) => a.status.name == 'complete'),
      ].where((done) => done).length;

  static const int totalStepCount = 8;

  PlanningProject copyWith({
    String? title,
    String? country,
    Objective? objective,
    Audience? audience,
    StrategicIntent? strategicIntent,
    MarketResearch? marketResearch,
    ProgramIdentity? identity,
    DistributionPlan? distribution,
    BudgetPlan? budget,
    List<ApprovalItem>? approvals,
  }) {
    return PlanningProject(
      id: id,
      title: title ?? this.title,
      country: country ?? this.country,
      ownerUid: ownerUid,
      ownerName: ownerName,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      objective: objective ?? this.objective,
      audience: audience ?? this.audience,
      strategicIntent: strategicIntent ?? this.strategicIntent,
      marketResearch: marketResearch ?? this.marketResearch,
      identity: identity ?? this.identity,
      distribution: distribution ?? this.distribution,
      budget: budget ?? this.budget,
      approvals: approvals ?? this.approvals,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'country': country,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'planning': {
          'objective': objective.toMap(),
          'audience': audience.toMap(),
          'strategicIntent': strategicIntent.toMap(),
          'marketResearch': marketResearch.toMap(),
          'identity': identity.toMap(),
          'distribution': distribution.toMap(),
          'budget': budget.toMap(),
        },
        'approvals': approvals.map((a) => a.toMap()).toList(),
      };

  factory PlanningProject.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final planning = Map<String, dynamic>.from(data['planning'] ?? {});
    return PlanningProject(
      id: doc.id,
      title: data['title'] ?? '',
      country: data['country'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      ownerName: data['ownerName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      objective: Objective.fromMap(planning['objective']),
      audience: Audience.fromMap(planning['audience']),
      strategicIntent: StrategicIntent.fromMap(planning['strategicIntent']),
      marketResearch: MarketResearch.fromMap(planning['marketResearch']),
      identity: ProgramIdentity.fromMap(planning['identity']),
      distribution: DistributionPlan.fromMap(planning['distribution']),
      budget: BudgetPlan.fromMap(planning['budget']),
      approvals: (data['approvals'] as List? ?? const [])
          .map((a) => ApprovalItem.fromMap(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }
}
