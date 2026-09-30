import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/media_production_planning.dart';
import 'media_production_service.dart';

/// Firestore access for the Planning stage of a Media Production.
///
/// Reads/writes the `planning` map and `approvals` array on the same
/// `media_productions/{productionId}` document that
/// [MediaProductionService] already owns, so Planning is additive data
/// on an existing production rather than a separate collection.
class MediaPlanningService {
  MediaPlanningService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _productions =>
      _db.collection(MediaProductionService.productionsCollection);

  Stream<MediaProductionPlanning> watchPlanning(String productionId) {
    return _productions
        .doc(productionId)
        .snapshots()
        .map((doc) => MediaProductionPlanning.fromProductionData(doc.data() ?? {}));
  }

  Future<MediaProductionPlanning> getPlanning(String productionId) async {
    final doc = await _productions.doc(productionId).get();
    return MediaProductionPlanning.fromProductionData(doc.data() ?? {});
  }

  /// Merges a single Planning section into the production document
  /// without touching other stages' data — safe to call after every
  /// "Draft with AI" run or manual edit.
  Future<void> saveSection(
    String productionId, {
    PlanningObjective? objective,
    PlanningAudience? audience,
    PlanningStrategicIntent? strategicIntent,
    PlanningMarketResearch? marketResearch,
    PlanningProgramIdentity? identity,
    PlanningDistribution? distribution,
    PlanningBudget? budget,
  }) async {
    final update = <String, dynamic>{'updatedAt': Timestamp.now()};
    if (objective != null) update['planning.objective'] = objective.toMap();
    if (audience != null) update['planning.audience'] = audience.toMap();
    if (strategicIntent != null) {
      update['planning.strategicIntent'] = strategicIntent.toMap();
    }
    if (marketResearch != null) {
      update['planning.marketResearch'] = marketResearch.toMap();
    }
    if (identity != null) update['planning.identity'] = identity.toMap();
    if (distribution != null) update['planning.distribution'] = distribution.toMap();
    if (budget != null) update['planning.budget'] = budget.toMap();

    await _productions.doc(productionId).update(update);
  }

  Future<void> saveApprovals(
    String productionId,
    List<PlanningApprovalItem> approvals,
  ) async {
    await _productions.doc(productionId).update({
      'approvals': approvals.map((a) => a.toMap()).toList(),
      'updatedAt': Timestamp.now(),
    });
  }
}
