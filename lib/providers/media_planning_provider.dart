import 'package:flutter/foundation.dart';

import '../models/media_production_planning.dart';
import '../services/media_planning_ai_service.dart';
import '../services/media_planning_service.dart';

/// Holds the Planning stage of one Media Production and coordinates
/// between [MediaPlanningService] (Firestore) and [MediaPlanningAiService]
/// (Gemini drafting), so the Planning tab and its 8 step screens stay
/// free of both.
class MediaPlanningProvider extends ChangeNotifier {
  MediaPlanningProvider({
    MediaPlanningService? service,
    MediaPlanningAiService? aiService,
  })  : _service = service ?? MediaPlanningService(),
        _ai = aiService ?? MediaPlanningAiService();

  final MediaPlanningService _service;
  final MediaPlanningAiService _ai;

  String? _productionId;
  MediaProductionPlanning? _planning;
  bool _isLoading = false;
  bool _isDrafting = false;
  String? _error;

  MediaProductionPlanning? get planning => _planning;
  bool get isLoading => _isLoading;

  /// True while any "Draft with AI" call is in flight — steps use this
  /// to disable draft buttons and show one shared busy state.
  bool get isDrafting => _isDrafting;
  String? get error => _error;
  bool get aiAvailable => _ai.isAvailable;

  Future<void> loadPlanning(String productionId) async {
    _productionId = productionId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _planning = await _service.getPlanning(productionId);
    } catch (e) {
      _error = 'Could not load Planning data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _withDraftingState(Future<void> Function() action) async {
    _isDrafting = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      _error = 'AI draft failed: $e';
    } finally {
      _isDrafting = false;
      notifyListeners();
    }
  }

  // ---- Manual edits (no AI) ---------------------------------------------
  //
  // Every save below returns whether it actually succeeded. Previously
  // a Firestore failure here (permissions, a dropped connection, the
  // production doc not existing yet) threw silently — nothing was
  // shown to the user and the step just sat there looking like
  // "Save" had done nothing. Now the error surfaces via [error], and
  // callers (the step screens) only auto-advance to the next step on
  // a confirmed success.

  Future<bool> _persist(String? id, Future<void> Function() write, MediaProductionPlanning? Function() applyLocally) async {
    if (id == null) return false;
    try {
      await write();
      _planning = applyLocally();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not save — check your connection and try again. ($e)';
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveObjective(PlanningObjective objective) => _persist(
        _productionId,
        () => _service.saveSection(_productionId!, objective: objective),
        () => _planning?.copyWith(objective: objective),
      );

  Future<bool> saveAudience(PlanningAudience audience) => _persist(
        _productionId,
        () => _service.saveSection(_productionId!, audience: audience),
        () => _planning?.copyWith(audience: audience),
      );

  Future<bool> saveStrategicIntent(PlanningStrategicIntent strategicIntent) => _persist(
        _productionId,
        () => _service.saveSection(_productionId!, strategicIntent: strategicIntent),
        () => _planning?.copyWith(strategicIntent: strategicIntent),
      );

  Future<bool> saveMarketResearch(PlanningMarketResearch marketResearch) => _persist(
        _productionId,
        () => _service.saveSection(_productionId!, marketResearch: marketResearch),
        () => _planning?.copyWith(marketResearch: marketResearch),
      );

  Future<bool> saveProgramIdentity(PlanningProgramIdentity identity) => _persist(
        _productionId,
        () => _service.saveSection(_productionId!, identity: identity),
        () => _planning?.copyWith(identity: identity),
      );

  Future<bool> saveDistribution(PlanningDistribution distribution) => _persist(
        _productionId,
        () => _service.saveSection(_productionId!, distribution: distribution),
        () => _planning?.copyWith(distribution: distribution),
      );

  Future<bool> saveBudget(PlanningBudget budget) => _persist(
        _productionId,
        () => _service.saveSection(_productionId!, budget: budget),
        () => _planning?.copyWith(budget: budget),
      );

  Future<bool> saveApprovals(List<PlanningApprovalItem> approvals) => _persist(
        _productionId,
        () => _service.saveApprovals(_productionId!, approvals),
        () => _planning?.copyWith(approvals: approvals),
      );

  // ---- AI-assisted drafting -----------------------------------------------

  Future<void> draftObjectiveWithAi(List<String> bullets) async {
    final id = _productionId;
    if (id == null) return;
    await _withDraftingState(() async {
      final drafted = await _ai.draftObjective(bullets);
      await _service.saveSection(id, objective: drafted);
      _planning = _planning?.copyWith(objective: drafted);
    });
  }

  Future<void> draftStrategicIntentWithAi(List<String> bullets) async {
    final id = _productionId;
    if (id == null) return;
    await _withDraftingState(() async {
      final drafted = await _ai.draftStrategicIntent(bullets);
      await _service.saveSection(id, strategicIntent: drafted);
      _planning = _planning?.copyWith(strategicIntent: drafted);
    });
  }

  Future<void> synthesizeAudienceWithAi(String rawNotes) async {
    final id = _productionId;
    if (id == null) return;
    await _withDraftingState(() async {
      final drafted = await _ai.synthesizeAudience(rawNotes);
      await _service.saveSection(id, audience: drafted);
      _planning = _planning?.copyWith(audience: drafted);
    });
  }

  Future<void> scoutReferencesWithAi({
    required String programIdea,
    String? preferredPlatform,
  }) async {
    final id = _productionId;
    if (id == null) return;
    await _withDraftingState(() async {
      final drafted = await _ai.scoutReferences(
        programIdea: programIdea,
        preferredPlatform: preferredPlatform,
      );
      await _service.saveSection(id, marketResearch: drafted);
      _planning = _planning?.copyWith(marketResearch: drafted);
    });
  }

  Future<void> draftEditorialCalendarWithAi({
    required List<String> platforms,
    required String frequency,
    required DateTime launchDate,
    int numberOfEntries = 8,
  }) async {
    final id = _productionId;
    final current = _planning?.distribution ?? const PlanningDistribution();
    if (id == null) return;
    await _withDraftingState(() async {
      final entries = await _ai.draftEditorialCalendar(
        platforms: platforms,
        frequency: frequency,
        launchDate: launchDate,
        numberOfEntries: numberOfEntries,
      );
      final aiEntries = entries.map((e) => e.copyWith(source: 'ai')).toList();
      final manualEntries = current.editorialCalendar.where((e) => e.source != 'ai').toList();
      final updated = current.copyWith(
        frequency: frequency,
        editorialCalendar: [...manualEntries, ...aiEntries],
      );
      await _service.saveSection(id, distribution: updated);
      _planning = _planning?.copyWith(distribution: updated);
    });
  }
}
