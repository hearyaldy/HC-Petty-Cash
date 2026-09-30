# Planning module — for hopechannel.asia

This is Phase 1 + Phase 2 of the Planning Intelligence Hub proposal:
a standalone Flutter/Firebase feature module that digitizes Workflow
HC's Planning stage (8 steps) and layers five Gemini-powered drafting
assistants on top of the research-heavy steps. It was built without
access to the existing hopechannel.asia codebase, so it's structured
to drop in cleanly rather than assume anything about your app's
current architecture.

## What's in here

```
lib/features/planning/
  models/       Dart classes for each of the 8 Planning steps + the aggregate PlanningProject
  services/     PlanningRepository (Firestore) and GeminiPlanningService (the 5 AI assistants)
  state/        PlanningProjectProvider — a ChangeNotifier tying the two services to the UI
  screens/      PlanningDashboardScreen (project list) + PlanningWizardScreen (8-step editor)
  widgets/      AiDraftButton, StageProgressRail, ReferenceCard — shared UI pieces
```

The 8 steps, matching Workflow HC exactly:

1. General Objective — pains, why the program exists, practical conditions
2. Audience — gender, age, social situation, activity, geography, who it's NOT for
3. Strategic Intent — transformation, attraction, retention, metrics
4. Format / Market Research — 3 references, platform, style, aspect ratio
5. Program Identity — briefing, naming, moodboard, palette, key visual (no AI — creative, not research)
6. Distribution — frequency, format per platform, boosting, editorial calendar
7. Budget — applies Workflow HC's own 10/30/10/45/5 benchmark split (rule-based, not AI)
8. Approvals — sign-off checklist before moving to Pre-production

## Wiring this into your existing app

**1. Dependencies** — add to `pubspec.yaml` (versions are current as of
this writing; check `flutter pub outdated` before locking them in):

```yaml
dependencies:
  cloud_firestore: ^5.0.0
  provider: ^6.1.0
  google_generative_ai: ^0.4.0
  intl: ^0.19.0
```

If hopechannel.asia already uses a different state-management approach
(Bloc, Riverpod, GetX) instead of `provider`, keep `PlanningRepository`
and `GeminiPlanningService` as-is — they have no UI dependency — and
re-implement `PlanningProjectProvider`'s handful of methods in your
existing pattern. That's the only file coupled to `provider`.

**2. Firestore collection** — this assumes a top-level `projects`
collection already exists (or will) with `title`, `country`, `ownerUid`
fields read by other modules. `PlanningRepository` only touches the
`planning` map and `approvals` array inside each project document, so
it's additive — it won't collide with fields other stages
(Pre-production, Production, etc.) already store on the same document.
If your existing collection is named differently, change the one
`_collection` constant in `planning_repository.dart`.

**3. Gemini API key** — `PlanningDashboardScreen._openProject()` has a
deliberate `throw UnimplementedError(...)` where the API key should be
supplied. Route it through whatever secrets mechanism your other
Gemini-integrated tools already use — never hardcode it in the
Flutter client for a production build; a Cloud Function proxy is safer
than calling the Gemini API directly from the app if you haven't
already set that up elsewhere.

**4. Firestore security rules** — add this to your existing
`firestore.rules` (adjust the auth check to match your existing role
system):

```
match /projects/{projectId} {
  allow read: if request.auth != null;
  allow update: if request.auth != null
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['planning', 'approvals', 'updatedAt']);
  allow create: if request.auth != null;
}
```

**5. Navigation** — add `PlanningDashboardScreen` wherever "Planning"
or "Mission Intelligence" belongs in your existing nav structure,
passing the signed-in user's uid/display name.

## What's intentionally left as TODO

A few Save buttons (Audience, Program Identity, Distribution, Budget,
Strategic Intent) are wired to `onPressed: null` with a comment
pointing at the pattern to copy from `saveObjective()` /
`saveApprovals()` in `PlanningProjectProvider`. This was a deliberate
cut to keep the scaffold reviewable — each one is the same five lines:
build the model from the screen's controllers, call
`_repository.saveSection(...)`, update `_project`, `notifyListeners()`.

Also not built here, per the phased roadmap in the proposal:

- **Phase 3** (Mission Intelligence connection): feeding Survey A/B/C
  responses into `synthesizeAudience()` instead of free-text notes.
  The method signature already accepts a plain string, so this is a
  matter of formatting survey export rows into that string — no model
  changes needed.
- **Phase 4** (cross-project memory): replacing
  `BudgetPhaseSplit.workflowHcBenchmark` with an average of a
  project's own logged budgets, and adding a "similar past projects"
  query to `PlanningRepository`.

## Cost control

`GeminiPlanningService` takes a `fastModel` and `strongModel` name in
its constructor and defaults every one of the 5 assistants to the fast
tier — none of the drafting tasks here need the stronger model. Keep
it that way until Phase 3/4 synthesis work actually requires deeper
reasoning across many projects at once.
