import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/audience.dart';
import '../models/distribution_plan.dart';
import '../models/market_research.dart';
import '../models/objective.dart';
import '../models/strategic_intent.dart';

/// Which Gemini tier to use for a given call.
///
/// Per the "Keeping it cheap" note in the Planning Intelligence Hub
/// proposal: mechanical expansion/formatting work uses [fast], and
/// only genuine cross-project synthesis (Phase 3-4 — not implemented
/// in this scaffold) should reach for [strong].
enum GeminiTier { fast, strong }

/// The five AI assistants from the Planning Intelligence Hub proposal,
/// each mapped to one research-heavy step of Workflow HC's Planning
/// stage. Budget allocation is deliberately NOT here — Workflow HC's
/// benchmark split is a fixed formula, not something to generate (see
/// [BudgetPhaseSplit.workflowHcBenchmark]).
///
/// Swap the model names below for whatever your Firebase project /
/// Gemini API key already has enabled — these are placeholders for a
/// fast/cheap tier and a stronger tier, matching whatever tiering
/// approach is already used elsewhere in hopechannel.asia.
class GeminiPlanningService {
  GeminiPlanningService({
    required String apiKey,
    String fastModel = 'gemini-2.5-flash',
    String strongModel = 'gemini-2.5-pro',
  })  : _apiKey = apiKey,
        _fastModel = fastModel,
        _strongModel = strongModel;

  final String _apiKey;
  final String _fastModel;
  final String _strongModel;

  GenerativeModel _modelFor(GeminiTier tier) {
    return GenerativeModel(
      model: tier == GeminiTier.fast ? _fastModel : _strongModel,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.4,
      ),
    );
  }

  Future<Map<String, dynamic>> _generateJson(
    String prompt, {
    GeminiTier tier = GeminiTier.fast,
  }) async {
    final model = _modelFor(tier);
    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------
  // 1. Objective & Intent Co-writer (Steps 1 & 3)
  // ---------------------------------------------------------------------

  /// Expands a few rough bullet points into Workflow HC's exact
  /// General Objective shape: pains, why the program exists, and
  /// whether there are practical conditions to meet that pain.
  Future<Objective> draftObjective(List<String> roughBullets) async {
    final prompt = '''
You are helping a Hope Channel Southeast Asia producer fill in the
"General Objective of the Project" section of their production
Planning template. The template asks exactly these questions:
- What pains do we need to attend?
- Why does this program exist?
- Do we have practical conditions to meet this pain?

From the producer's rough notes below, draft clear, specific answers.
Do not invent facts the notes do not support — if practical
conditions are not mentioned, say so plainly rather than guessing.

Producer's notes:
${roughBullets.map((b) => '- $b').join('\n')}

Respond as JSON with exactly these keys:
{"pains": ["..."], "whyItExists": "...", "practicalConditions": "...", "metricPriority": ["reach"|"engagement"|"connection", ...]}
metricPriority should order reach/engagement/connection by what the notes imply matters most.
''';
    final json = await _generateJson(prompt);
    return Objective(
      pains: List<String>.from(json['pains'] ?? const []),
      whyItExists: json['whyItExists'] ?? '',
      practicalConditions: json['practicalConditions'] ?? '',
      metricPriority: List<String>.from(json['metricPriority'] ?? const []),
    );
  }

  /// Expands the same rough notes into Strategic Intent: transformation,
  /// what attracts the audience, how to build return visits, and metrics.
  Future<StrategicIntent> draftStrategicIntent(List<String> roughBullets) async {
    final prompt = '''
Draft the "Strategic Intent" section of a Hope Channel Southeast Asia
Planning document from the producer's notes below. The template asks:
- What transformation do we want to generate with this program?
- What will attract the audience to our program?
- How can we build audience to return to our program regularly?
- What metrics will guide our project?

Producer's notes:
${roughBullets.map((b) => '- $b').join('\n')}

Respond as JSON: {"transformation": "...", "attractionHook": "...", "retentionPlan": "...", "metrics": ["..."]}
''';
    final json = await _generateJson(prompt);
    return StrategicIntent(
      transformation: json['transformation'] ?? '',
      attractionHook: json['attractionHook'] ?? '',
      retentionPlan: json['retentionPlan'] ?? '',
      metrics: List<String>.from(json['metrics'] ?? const []),
    );
  }

  // ---------------------------------------------------------------------
  // 2. Audience Synthesizer (Step 2)
  // ---------------------------------------------------------------------

  /// Turns raw notes (or, once Phase 3 connects Mission Intelligence,
  /// pasted Survey C open-text rows) into the Audience fields Workflow
  /// HC asks for, including who the program is explicitly NOT for.
  Future<Audience> synthesizeAudience(String rawNotes) async {
    final prompt = '''
You are drafting the "Audience" section of a Hope Channel Southeast
Asia Planning document from raw observations below. The template
asks for: Gender, Age, Social situation, Activity (student,
entrepreneur, farmer, etc.), Geography, and — importantly — who is
NOT the target audience.

Raw notes / observations:
$rawNotes

Respond as JSON: {"gender": "...", "ageRange": "...", "socialSituation": "...", "activity": "...", "geography": "...", "notAudience": "..."}
Keep each field to one or two sentences. If the notes don't support a field, write "Not specified in notes" rather than guessing.
''';
    final json = await _generateJson(prompt);
    return Audience(
      gender: json['gender'] ?? '',
      ageRange: json['ageRange'] ?? '',
      socialSituation: json['socialSituation'] ?? '',
      activity: json['activity'] ?? '',
      geography: json['geography'] ?? '',
      notAudience: json['notAudience'] ?? '',
    );
  }

  // ---------------------------------------------------------------------
  // 3. Reference Scout (Step 4 — Format: market research)
  // ---------------------------------------------------------------------

  /// Drafts the "3 references from similar or related programs" table,
  /// plus a platform/style/aspect-ratio recommendation.
  Future<MarketResearch> scoutReferences({
    required String programIdea,
    required String country,
    String? preferredPlatform,
  }) async {
    final prompt = '''
A Hope Channel Southeast Asia producer in $country is planning a new
program. Program idea: "$programIdea".
${preferredPlatform != null ? 'They are leaning toward: $preferredPlatform.' : ''}

Draft the "Format: market research" section of their Planning
document. Workflow HC requires exactly 3 references from similar or
related programs, a platform recommendation, a content style
(podcast, documentary, shorts, talk show, etc.), and an aspect ratio
choice (16:9 landscape or 9:16 portrait).

Respond as JSON:
{
  "references": [{"title": "...", "url": "", "whatWorks": "..."}, ...exactly 3...],
  "preferredPlatforms": ["..."],
  "style": "...",
  "aspectRatio": "landscape_16_9" | "portrait_9_16"
}
Leave "url" empty if you are not certain of a real URL — never invent one.
''';
    final json = await _generateJson(prompt);
    final refs = (json['references'] as List? ?? const [])
        .map((r) => ProgramReference.fromMap(Map<String, dynamic>.from(r)))
        .toList();
    return MarketResearch(
      references: refs,
      preferredPlatforms: List<String>.from(json['preferredPlatforms'] ?? const []),
      style: json['style'] ?? '',
      aspectRatio: ProgramAspectRatioLabel.fromString(json['aspectRatio']),
    );
  }

  // ---------------------------------------------------------------------
  // 4. Editorial Calendar Drafter (Step 6 — Distribution)
  // ---------------------------------------------------------------------

  /// Drafts a starting editorial calendar skeleton — themes, formats,
  /// channel, and status per entry — for the producer to adjust rather
  /// than build from a blank grid.
  Future<List<EditorialCalendarEntry>> draftEditorialCalendar({
    required List<String> platforms,
    required String frequency,
    required DateTime launchDate,
    required int numberOfEntries,
  }) async {
    final prompt = '''
Draft an editorial calendar skeleton for a Hope Channel Southeast
Asia program launching ${launchDate.toIso8601String().split('T').first},
publishing on: ${platforms.join(', ')}, at this frequency: $frequency.

Produce exactly $numberOfEntries entries, spaced according to the
stated frequency starting on the launch date. These are placeholders
for the producer to refine, not final content.

Respond as JSON: {"entries": [{"date": "YYYY-MM-DD", "theme": "...", "format": "...", "channel": "...", "status": "Planned"}, ...]}
''';
    final json = await _generateJson(prompt);
    final entries = (json['entries'] as List? ?? const [])
        .map((e) => EditorialCalendarEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return entries;
  }
}
