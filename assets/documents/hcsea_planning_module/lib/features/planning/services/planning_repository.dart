import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/approval_item.dart';
import '../models/audience.dart';
import '../models/budget_plan.dart';
import '../models/distribution_plan.dart';
import '../models/market_research.dart';
import '../models/objective.dart';
import '../models/planning_project.dart';
import '../models/program_identity.dart';
import '../models/strategic_intent.dart';

/// Firestore access for Planning data.
///
/// Assumes hopechannel.asia already has a top-level `projects`
/// collection with a `title`, `country`, `ownerUid` shape used by
/// other modules — this repository only reads/writes the `planning`
/// map and `approvals` array inside each project document, so it can
/// sit alongside whatever Pre-production/Production/etc. fields
/// already exist there. Adjust `_collection` if your existing schema
/// names it differently (e.g. `programs`).
class PlanningRepository {
  PlanningRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _collection = 'projects';

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection(_collection);

  /// Live list of projects, most recently updated first — for the
  /// project picker / dashboard.
  Stream<List<PlanningProject>> watchProjects() {
    return _projects
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PlanningProject.fromDoc).toList());
  }

  Stream<PlanningProject?> watchProject(String projectId) {
    return _projects.doc(projectId).snapshots().map(
          (doc) => doc.exists ? PlanningProject.fromDoc(doc) : null,
        );
  }

  Future<PlanningProject?> getProject(String projectId) async {
    final doc = await _projects.doc(projectId).get();
    return doc.exists ? PlanningProject.fromDoc(doc) : null;
  }

  Future<PlanningProject> createProject({
    required String title,
    required String country,
    required String ownerUid,
    required String ownerName,
  }) async {
    final docRef = _projects.doc();
    final project = PlanningProject.newDraft(
      id: docRef.id,
      title: title,
      country: country,
      ownerUid: ownerUid,
      ownerName: ownerName,
    );
    await docRef.set(project.toMap());
    return project;
  }

  /// Merges a single Planning section into the project document
  /// without touching other stages' data or approvals — keeps writes
  /// small and safe to call after every "Draft with AI" or manual edit.
  Future<void> saveSection(
    String projectId, {
    Objective? objective,
    Audience? audience,
    StrategicIntent? strategicIntent,
    MarketResearch? marketResearch,
    ProgramIdentity? identity,
    DistributionPlan? distribution,
    BudgetPlan? budget,
  }) async {
    final update = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
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

    await _projects.doc(projectId).update(update);
  }

  Future<void> saveApprovals(String projectId, List<ApprovalItem> approvals) async {
    await _projects.doc(projectId).update({
      'approvals': approvals.map((a) => a.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
