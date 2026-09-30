/// Models for the Planning stage of a Media Production, digitizing
/// Workflow HC's 8-step Planning template. Stored on the same
/// `media_productions/{id}` Firestore document as the rest of the
/// production — see [MediaProductionPlanning.fromProductionData] — under
/// a `planning` map plus a top-level `approvals` array, so it sits
/// alongside whatever other fields the production already has.
library;

// ---------------------------------------------------------------------
// Step 1 — General Objective of the Project
// ---------------------------------------------------------------------

class PlanningObjective {
  final List<String> pains;
  final String whyItExists;
  final String practicalConditions;
  final List<String> metricPriority; // ordered subset of reach/engagement/connection

  const PlanningObjective({
    this.pains = const [],
    this.whyItExists = '',
    this.practicalConditions = '',
    this.metricPriority = const [],
  });

  bool get isEmpty =>
      pains.isEmpty && whyItExists.isEmpty && practicalConditions.isEmpty;

  Map<String, dynamic> toMap() => {
        'pains': pains,
        'whyItExists': whyItExists,
        'practicalConditions': practicalConditions,
        'metricPriority': metricPriority,
      };

  factory PlanningObjective.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlanningObjective();
    return PlanningObjective(
      pains: List<String>.from(map['pains'] ?? const []),
      whyItExists: map['whyItExists'] ?? '',
      practicalConditions: map['practicalConditions'] ?? '',
      metricPriority: List<String>.from(map['metricPriority'] ?? const []),
    );
  }
}

// ---------------------------------------------------------------------
// Step 2 — Audience
// ---------------------------------------------------------------------

class PlanningAudience {
  final String gender;
  final String ageRange;
  final String socialSituation;
  final String activity;
  final String geography;
  final String notAudience;

  const PlanningAudience({
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

  Map<String, dynamic> toMap() => {
        'gender': gender,
        'ageRange': ageRange,
        'socialSituation': socialSituation,
        'activity': activity,
        'geography': geography,
        'notAudience': notAudience,
      };

  factory PlanningAudience.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlanningAudience();
    return PlanningAudience(
      gender: map['gender'] ?? '',
      ageRange: map['ageRange'] ?? '',
      socialSituation: map['socialSituation'] ?? '',
      activity: map['activity'] ?? '',
      geography: map['geography'] ?? '',
      notAudience: map['notAudience'] ?? '',
    );
  }
}

// ---------------------------------------------------------------------
// Step 3 — Strategic Intent
// ---------------------------------------------------------------------

class PlanningStrategicIntent {
  final String transformation;
  final String attractionHook;
  final String retentionPlan;
  final List<String> metrics;

  const PlanningStrategicIntent({
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

  Map<String, dynamic> toMap() => {
        'transformation': transformation,
        'attractionHook': attractionHook,
        'retentionPlan': retentionPlan,
        'metrics': metrics,
      };

  factory PlanningStrategicIntent.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlanningStrategicIntent();
    return PlanningStrategicIntent(
      transformation: map['transformation'] ?? '',
      attractionHook: map['attractionHook'] ?? '',
      retentionPlan: map['retentionPlan'] ?? '',
      metrics: List<String>.from(map['metrics'] ?? const []),
    );
  }
}

// ---------------------------------------------------------------------
// Step 4 — Format: Market Research
// ---------------------------------------------------------------------

class PlanningReference {
  final String title;
  final String url;
  final String whatWorks;

  const PlanningReference({
    this.title = '',
    this.url = '',
    this.whatWorks = '',
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'url': url,
        'whatWorks': whatWorks,
      };

  factory PlanningReference.fromMap(Map<String, dynamic> map) {
    return PlanningReference(
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      whatWorks: map['whatWorks'] ?? '',
    );
  }
}

// Named `PlanningAspectRatio` (not `AspectRatio`) to avoid colliding with
// Flutter's own `AspectRatio` widget.
enum PlanningAspectRatio { landscape169, portrait916 }

extension PlanningAspectRatioLabel on PlanningAspectRatio {
  String get label => this == PlanningAspectRatio.landscape169
      ? '16:9 (landscape)'
      : '9:16 (portrait)';

  String toStorageString() =>
      this == PlanningAspectRatio.landscape169 ? 'landscape_16_9' : 'portrait_9_16';

  static PlanningAspectRatio fromString(String? value) => value == 'portrait_9_16'
      ? PlanningAspectRatio.portrait916
      : PlanningAspectRatio.landscape169;
}

class PlanningMarketResearch {
  final List<PlanningReference> references; // Workflow HC asks for exactly 3
  final List<String> preferredPlatforms;
  final String style; // podcast, documentary, shorts, talk show, etc.
  final PlanningAspectRatio aspectRatio;

  const PlanningMarketResearch({
    this.references = const [],
    this.preferredPlatforms = const [],
    this.style = '',
    this.aspectRatio = PlanningAspectRatio.landscape169,
  });

  bool get isEmpty => references.isEmpty && preferredPlatforms.isEmpty && style.isEmpty;

  Map<String, dynamic> toMap() => {
        'references': references.map((r) => r.toMap()).toList(),
        'preferredPlatforms': preferredPlatforms,
        'style': style,
        'aspectRatio': aspectRatio.toStorageString(),
      };

  factory PlanningMarketResearch.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlanningMarketResearch();
    return PlanningMarketResearch(
      references: (map['references'] as List? ?? const [])
          .map((r) => PlanningReference.fromMap(Map<String, dynamic>.from(r)))
          .toList(),
      preferredPlatforms: List<String>.from(map['preferredPlatforms'] ?? const []),
      style: map['style'] ?? '',
      aspectRatio: PlanningAspectRatioLabel.fromString(map['aspectRatio']),
    );
  }
}

// ---------------------------------------------------------------------
// Step 5 — Program Identity (Visual Identity)
// ---------------------------------------------------------------------

class PlanningProgramIdentity {
  final String briefing;
  final String programName;
  final List<String> moodboardRefs;
  final String fontChoice;
  final String colorPalette;
  final String keyVisualDescription;
  final List<String> derivationsNeeded;

  const PlanningProgramIdentity({
    this.briefing = '',
    this.programName = '',
    this.moodboardRefs = const [],
    this.fontChoice = '',
    this.colorPalette = '',
    this.keyVisualDescription = '',
    this.derivationsNeeded = const [
      'Thumbnail (YouTube)',
      'Reel',
      'Square Post',
      'Carousel',
      'Story',
    ],
  });

  bool get isEmpty => briefing.isEmpty && programName.isEmpty;

  Map<String, dynamic> toMap() => {
        'briefing': briefing,
        'programName': programName,
        'moodboardRefs': moodboardRefs,
        'fontChoice': fontChoice,
        'colorPalette': colorPalette,
        'keyVisualDescription': keyVisualDescription,
        'derivationsNeeded': derivationsNeeded,
      };

  factory PlanningProgramIdentity.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlanningProgramIdentity();
    return PlanningProgramIdentity(
      briefing: map['briefing'] ?? '',
      programName: map['programName'] ?? '',
      moodboardRefs: List<String>.from(map['moodboardRefs'] ?? const []),
      fontChoice: map['fontChoice'] ?? '',
      colorPalette: map['colorPalette'] ?? '',
      keyVisualDescription: map['keyVisualDescription'] ?? '',
      derivationsNeeded: List<String>.from(
        map['derivationsNeeded'] ??
            const ['Thumbnail (YouTube)', 'Reel', 'Square Post', 'Carousel', 'Story'],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Step 6 — Distribution (including the Editorial Calendar)
// ---------------------------------------------------------------------

class PlanningCalendarEntry {
  final DateTime date;
  final String theme;
  final String format;
  final String channel;
  final String responsible;
  final String status; // free text, matches Workflow HC's own "status" column
  final String campaign;

  /// 'ai' for entries produced by the Editorial Calendar Drafter, 'manual'
  /// for anything a producer typed in directly — lets the calendar table
  /// label each row's origin and offer "clear AI-drafted entries" without
  /// touching manual additions.
  final String source;

  const PlanningCalendarEntry({
    required this.date,
    this.theme = '',
    this.format = '',
    this.channel = '',
    this.responsible = '',
    this.status = 'Planned',
    this.campaign = '',
    this.source = 'manual',
  });

  PlanningCalendarEntry copyWith({
    DateTime? date,
    String? theme,
    String? format,
    String? channel,
    String? responsible,
    String? status,
    String? campaign,
    String? source,
  }) {
    return PlanningCalendarEntry(
      date: date ?? this.date,
      theme: theme ?? this.theme,
      format: format ?? this.format,
      channel: channel ?? this.channel,
      responsible: responsible ?? this.responsible,
      status: status ?? this.status,
      campaign: campaign ?? this.campaign,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'theme': theme,
        'format': format,
        'channel': channel,
        'responsible': responsible,
        'status': status,
        'campaign': campaign,
        'source': source,
      };

  factory PlanningCalendarEntry.fromMap(Map<String, dynamic> map) {
    return PlanningCalendarEntry(
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      theme: map['theme'] ?? '',
      format: map['format'] ?? '',
      channel: map['channel'] ?? '',
      responsible: map['responsible'] ?? '',
      status: map['status'] ?? 'Planned',
      campaign: map['campaign'] ?? '',
      source: map['source'] ?? 'ai',
    );
  }
}

class PlanningDistribution {
  final List<String> platforms;
  final String frequency;
  final DateTime? launchDate;
  final Map<String, String> formatByPlatform;
  final String boostStrategyPre;
  final String boostStrategyDuring;
  final String boostStrategyPost;
  final bool usesPaidTraffic;
  final List<PlanningCalendarEntry> editorialCalendar;

  const PlanningDistribution({
    this.platforms = const [],
    this.frequency = '',
    this.launchDate,
    this.formatByPlatform = const {},
    this.boostStrategyPre = '',
    this.boostStrategyDuring = '',
    this.boostStrategyPost = '',
    this.usesPaidTraffic = false,
    this.editorialCalendar = const [],
  });

  bool get isEmpty => platforms.isEmpty && frequency.isEmpty && formatByPlatform.isEmpty;

  PlanningDistribution copyWith({
    List<String>? platforms,
    String? frequency,
    DateTime? launchDate,
    Map<String, String>? formatByPlatform,
    List<PlanningCalendarEntry>? editorialCalendar,
  }) {
    return PlanningDistribution(
      platforms: platforms ?? this.platforms,
      frequency: frequency ?? this.frequency,
      launchDate: launchDate ?? this.launchDate,
      formatByPlatform: formatByPlatform ?? this.formatByPlatform,
      boostStrategyPre: boostStrategyPre,
      boostStrategyDuring: boostStrategyDuring,
      boostStrategyPost: boostStrategyPost,
      usesPaidTraffic: usesPaidTraffic,
      editorialCalendar: editorialCalendar ?? this.editorialCalendar,
    );
  }

  Map<String, dynamic> toMap() => {
        'platforms': platforms,
        'frequency': frequency,
        'launchDate': launchDate?.toIso8601String(),
        'formatByPlatform': formatByPlatform,
        'boostStrategyPre': boostStrategyPre,
        'boostStrategyDuring': boostStrategyDuring,
        'boostStrategyPost': boostStrategyPost,
        'usesPaidTraffic': usesPaidTraffic,
        'editorialCalendar': editorialCalendar.map((e) => e.toMap()).toList(),
      };

  factory PlanningDistribution.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlanningDistribution();
    return PlanningDistribution(
      platforms: List<String>.from(map['platforms'] ?? const []),
      frequency: map['frequency'] ?? '',
      launchDate: map['launchDate'] != null ? DateTime.tryParse(map['launchDate']) : null,
      formatByPlatform: Map<String, String>.from(map['formatByPlatform'] ?? const {}),
      boostStrategyPre: map['boostStrategyPre'] ?? '',
      boostStrategyDuring: map['boostStrategyDuring'] ?? '',
      boostStrategyPost: map['boostStrategyPost'] ?? '',
      usesPaidTraffic: map['usesPaidTraffic'] ?? false,
      editorialCalendar: (map['editorialCalendar'] as List? ?? const [])
          .map((e) => PlanningCalendarEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------
// Step 7 — Budget
// ---------------------------------------------------------------------

class PlanningBudgetSplit {
  final double preProductionPct;
  final double productionPct;
  final double postProductionPct;
  final double distributionPct;
  final double closurePct;

  /// Workflow HC's own published benchmark split (Pre-production 10% /
  /// Production 30% / Post-production 10% / Distribution 45% / Closure
  /// & documentation 5%).
  static const PlanningBudgetSplit workflowHcBenchmark = PlanningBudgetSplit(
    preProductionPct: 0.10,
    productionPct: 0.30,
    postProductionPct: 0.10,
    distributionPct: 0.45,
    closurePct: 0.05,
  );

  const PlanningBudgetSplit({
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

  factory PlanningBudgetSplit.fromMap(Map<String, dynamic> map) {
    return PlanningBudgetSplit(
      preProductionPct: (map['preProductionPct'] ?? 0.10).toDouble(),
      productionPct: (map['productionPct'] ?? 0.30).toDouble(),
      postProductionPct: (map['postProductionPct'] ?? 0.10).toDouble(),
      distributionPct: (map['distributionPct'] ?? 0.45).toDouble(),
      closurePct: (map['closurePct'] ?? 0.05).toDouble(),
    );
  }
}

/// One line item in the itemized Planning budget (e.g. "Camera rental —
/// 5,000"). The budget's total is always the sum of these.
class PlanningBudgetItem {
  final String label;
  final double amount;

  const PlanningBudgetItem({this.label = '', this.amount = 0});

  Map<String, dynamic> toMap() => {'label': label, 'amount': amount};

  factory PlanningBudgetItem.fromMap(Map<String, dynamic> map) {
    return PlanningBudgetItem(
      label: map['label'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
    );
  }
}

class PlanningBudget {
  final List<PlanningBudgetItem> items;
  final String currency;
  final PlanningBudgetSplit split;

  const PlanningBudget({
    this.items = const [],
    this.currency = 'USD',
    this.split = PlanningBudgetSplit.workflowHcBenchmark,
  });

  /// Always the sum of [items] — there is no separately-editable total.
  double get total => items.fold<double>(0, (sum, item) => sum + item.amount);

  double get preProduction => total * split.preProductionPct;
  double get production => total * split.productionPct;
  double get postProduction => total * split.postProductionPct;
  double get distribution => total * split.distributionPct;
  double get closure => total * split.closurePct;

  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toMap() => {
        'items': items.map((i) => i.toMap()).toList(),
        'currency': currency,
        'split': split.toMap(),
      };

  factory PlanningBudget.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlanningBudget();
    final rawItems = map['items'] as List?;
    List<PlanningBudgetItem> items;
    if (rawItems != null) {
      items = rawItems
          .map((i) => PlanningBudgetItem.fromMap(Map<String, dynamic>.from(i)))
          .toList();
    } else if ((map['total'] as num?) != null && (map['total'] as num) > 0) {
      // Backward compatibility with Planning data saved before itemized
      // budgets existed, which stored a single `total` number.
      items = [PlanningBudgetItem(label: 'Total budget', amount: (map['total'] as num).toDouble())];
    } else {
      items = const [];
    }
    return PlanningBudget(
      items: items,
      currency: map['currency'] ?? 'USD',
      split: map['split'] != null
          ? PlanningBudgetSplit.fromMap(Map<String, dynamic>.from(map['split']))
          : PlanningBudgetSplit.workflowHcBenchmark,
    );
  }
}

// ---------------------------------------------------------------------
// Step 8 — Approvals
// ---------------------------------------------------------------------

enum PlanningStepStatus {
  notStarted,
  inProgress,
  complete;

  String get label {
    switch (this) {
      case PlanningStepStatus.notStarted:
        return 'Not started';
      case PlanningStepStatus.inProgress:
        return 'In progress';
      case PlanningStepStatus.complete:
        return 'Complete';
    }
  }

  static PlanningStepStatus fromString(String? value) {
    switch (value) {
      case 'inProgress':
        return PlanningStepStatus.inProgress;
      case 'complete':
        return PlanningStepStatus.complete;
      default:
        return PlanningStepStatus.notStarted;
    }
  }

  String toStorageString() => name;
}

class PlanningApprovalItem {
  final String item;
  final PlanningStepStatus status;
  final String owner;
  final String notes;

  const PlanningApprovalItem({
    required this.item,
    this.status = PlanningStepStatus.notStarted,
    this.owner = '',
    this.notes = '',
  });

  /// The eight Planning steps, pre-populated as the default checklist so
  /// a production starts Planning with the right rows instead of a blank
  /// list — mirrors Workflow HC's own "Pre-production Approval Checklist"
  /// table shape (Item | Status | Owner | Notes).
  static List<PlanningApprovalItem> defaultChecklist() => const [
        PlanningApprovalItem(item: 'General objective defined'),
        PlanningApprovalItem(item: 'Audience defined'),
        PlanningApprovalItem(item: 'Strategic intent defined'),
        PlanningApprovalItem(item: 'Market research completed (3 references)'),
        PlanningApprovalItem(item: 'Program identity approved'),
        PlanningApprovalItem(item: 'Distribution plan and editorial calendar drafted'),
        PlanningApprovalItem(item: 'Budget allocated by phase'),
        PlanningApprovalItem(item: 'Planning stage signed off'),
      ];

  PlanningApprovalItem copyWith({
    PlanningStepStatus? status,
    String? owner,
    String? notes,
  }) {
    return PlanningApprovalItem(
      item: item,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'item': item,
        'status': status.toStorageString(),
        'owner': owner,
        'notes': notes,
      };

  factory PlanningApprovalItem.fromMap(Map<String, dynamic> map) {
    return PlanningApprovalItem(
      item: map['item'] ?? '',
      status: PlanningStepStatus.fromString(map['status']),
      owner: map['owner'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}

// ---------------------------------------------------------------------
// Aggregate — the whole Planning stage for one MediaProduction
// ---------------------------------------------------------------------

/// All Planning-stage data for one `MediaProduction`. Persisted on the
/// same `media_productions/{id}` document as everything else that
/// production owns — the 7 step sections live under a `planning` map,
/// and the Approvals checklist under a top-level `approvals` array —
/// rather than in a separate collection, so Planning is just the first
/// stage of one continuous production record.
class MediaProductionPlanning {
  final PlanningObjective objective;
  final PlanningAudience audience;
  final PlanningStrategicIntent strategicIntent;
  final PlanningMarketResearch marketResearch;
  final PlanningProgramIdentity identity;
  final PlanningDistribution distribution;
  final PlanningBudget budget;
  final List<PlanningApprovalItem> approvals;

  const MediaProductionPlanning({
    this.objective = const PlanningObjective(),
    this.audience = const PlanningAudience(),
    this.strategicIntent = const PlanningStrategicIntent(),
    this.marketResearch = const PlanningMarketResearch(),
    this.identity = const PlanningProgramIdentity(),
    this.distribution = const PlanningDistribution(),
    this.budget = const PlanningBudget(),
    this.approvals = const [],
  });

  static const int totalStepCount = 8;

  /// How many of the 8 Planning steps have real content — drives the
  /// stage rail's progress indicator.
  int get completedStepCount => [
        !objective.isEmpty,
        !audience.isEmpty,
        !strategicIntent.isEmpty,
        !marketResearch.isEmpty,
        !identity.isEmpty,
        !distribution.isEmpty,
        !budget.isEmpty,
        approvals.isNotEmpty &&
            approvals.every((a) => a.status == PlanningStepStatus.complete),
      ].where((done) => done).length;

  bool get isApprovalsComplete =>
      approvals.isNotEmpty && approvals.every((a) => a.status == PlanningStepStatus.complete);

  MediaProductionPlanning copyWith({
    PlanningObjective? objective,
    PlanningAudience? audience,
    PlanningStrategicIntent? strategicIntent,
    PlanningMarketResearch? marketResearch,
    PlanningProgramIdentity? identity,
    PlanningDistribution? distribution,
    PlanningBudget? budget,
    List<PlanningApprovalItem>? approvals,
  }) {
    return MediaProductionPlanning(
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

  Map<String, dynamic> toPlanningMap() => {
        'objective': objective.toMap(),
        'audience': audience.toMap(),
        'strategicIntent': strategicIntent.toMap(),
        'marketResearch': marketResearch.toMap(),
        'identity': identity.toMap(),
        'distribution': distribution.toMap(),
        'budget': budget.toMap(),
      };

  List<Map<String, dynamic>> approvalsToList() => approvals.map((a) => a.toMap()).toList();

  /// Reads the `planning` map + `approvals` array off a
  /// `media_productions/{id}` document's raw data.
  factory MediaProductionPlanning.fromProductionData(Map<String, dynamic> data) {
    final planning = Map<String, dynamic>.from(data['planning'] ?? {});
    final approvals = (data['approvals'] as List? ?? const [])
        .map((a) => PlanningApprovalItem.fromMap(Map<String, dynamic>.from(a)))
        .toList();
    return MediaProductionPlanning(
      objective: PlanningObjective.fromMap(planning['objective']),
      audience: PlanningAudience.fromMap(planning['audience']),
      strategicIntent: PlanningStrategicIntent.fromMap(planning['strategicIntent']),
      marketResearch: PlanningMarketResearch.fromMap(planning['marketResearch']),
      identity: PlanningProgramIdentity.fromMap(planning['identity']),
      distribution: PlanningDistribution.fromMap(planning['distribution']),
      budget: PlanningBudget.fromMap(planning['budget']),
      approvals: approvals.isNotEmpty ? approvals : PlanningApprovalItem.defaultChecklist(),
    );
  }
}
