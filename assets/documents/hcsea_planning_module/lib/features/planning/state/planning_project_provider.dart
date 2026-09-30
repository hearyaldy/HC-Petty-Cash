import 'package:flutter/foundation.dart';

import '../models/approval_item.dart';
import '../models/objective.dart';
import '../models/planning_project.dart';
import '../services/gemini_planning_service.dart';
import '../services/planning_repository.dart';

/// Holds the currently-open project and coordinates between the
/// Firestore repository and the Gemini drafting service, so screens
/// stay free of both.
///
/// Wire this in with `provider` (as scaffolded) or adapt the same
/// methods into whatever state management hopechannel.asia already
/// uses elsewhere (Bloc, Riverpod, GetX) — the repository and Gemini
/// service underneath don't depend on this class.
class PlanningProjectProvider extends ChangeNotifier {
  PlanningProjectProvider({
    required PlanningRepository repository,
    required GeminiPlanningService geminiService,
  })  : _repository = repository,
        _gemini = geminiService;

  final PlanningRepository _repository;
  final GeminiPlanningService _gemini;

  PlanningProject? _project;
  bool _isLoading = false;
  bool _isDrafting = false;
  String? _error;

  PlanningProject? get project => _project;
  bool get isLoading => _isLoading;

  /// True while any "Draft with AI" call is in flight — screens use
  /// this to disable draft buttons and show a single shared spinner
  /// state rather than one per button.
  bool get isDrafting => _isDrafting;
  String? get error => _error;

  Future<void> loadProject(String projectId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _project = await _repository.getProject(projectId);
    } catch (e) {
      _error = 'Could not load project: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PlanningProject> createProject({
    required String title,
    required String country,
    required String ownerUid,
    required String ownerName,
  }) async {
    final created = await _repository.createProject(
      title: title,
      country: country,
      ownerUid: ownerUid,
      ownerName: ownerName,
    );
    _project = created;
    notifyListeners();
    return created;
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

  // ---- Manual edits (no AI) -------------------------------------------

  Future<void> saveObjective(Objective objective) async {
    final p = _project;
    if (p == null) return;
    await _repository.saveSection(p.id, objective: objective);
    _project = p.copyWith(objective: objective);
    notifyListeners();
  }

  Future<void> saveApprovals(List<ApprovalItem> approvals) async {
    final p = _project;
    if (p == null) return;
    await _repository.saveApprovals(p.id, approvals);
    _project = p.copyWith(approvals: approvals);
    notifyListeners();
  }

  // Equivalent saveX() methods exist for audience, strategicIntent,
  // marketResearch, identity, distribution and budget — omitted here
  // for brevity, same pattern as saveObjective above.

  // ---- AI-assisted drafting ---------------------------------------------

  Future<void> draftObjectiveWithAi(List<String> bullets) async {
    final p = _project;
    if (p == null) return;
    await _withDraftingState(() async {
      final drafted = await _gemini.draftObjective(bullets);
      await _repository.saveSection(p.id, objective: drafted);
      _project = p.copyWith(objective: drafted);
    });
  }

  Future<void> draftStrategicIntentWithAi(List<String> bullets) async {
    final p = _project;
    if (p == null) return;
    await _withDraftingState(() async {
      final drafted = await _gemini.draftStrategicIntent(bullets);
      await _repository.saveSection(p.id, strategicIntent: drafted);
      _project = p.copyWith(strategicIntent: drafted);
    });
  }

  Future<void> synthesizeAudienceWithAi(String rawNotes) async {
    final p = _project;
    if (p == null) return;
    await _withDraftingState(() async {
      final drafted = await _gemini.synthesizeAudience(rawNotes);
      await _repository.saveSection(p.id, audience: drafted);
      _project = p.copyWith(audience: drafted);
    });
  }

  Future<void> scoutReferencesWithAi({
    required String programIdea,
    String? preferredPlatform,
  }) async {
    final p = _project;
    if (p == null) return;
    await _withDraftingState(() async {
      final drafted = await _gemini.scoutReferences(
        programIdea: programIdea,
        country: p.country,
        preferredPlatform: preferredPlatform,
      );
      await _repository.saveSection(p.id, marketResearch: drafted);
      _project = p.copyWith(marketResearch: drafted);
    });
  }

  Future<void> draftEditorialCalendarWithAi({
    required List<String> platforms,
    required String frequency,
    required DateTime launchDate,
    int numberOfEntries = 8,
  }) async {
    final p = _project;
    if (p == null) return;
    await _withDraftingState(() async {
      final entries = await _gemini.draftEditorialCalendar(
        platforms: platforms,
        frequency: frequency,
        launchDate: launchDate,
        numberOfEntries: numberOfEntries,
      );
      final updated = p.distribution.copyWith(
        // formatByPlatform is left for manual edit — the calendar draft
        // only fills in cadence and the entry skeleton.
        frequency: frequency,
        editorialCalendar: entries,
      );
      await _repository.saveSection(p.id, distribution: updated);
      _project = p.copyWith(distribution: updated);
    });
  }
}
