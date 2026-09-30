import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/media_production_planning.dart';

/// The five AI drafting assistants for Media Production Planning, each
/// mapped to one research-heavy step of Workflow HC's Planning stage.
/// Budget allocation is deliberately NOT here — Workflow HC's benchmark
/// split is a fixed formula (see [PlanningBudgetSplit.workflowHcBenchmark]),
/// not something to generate. Program Identity also has no assistant —
/// naming, moodboards, and key visuals are creative decisions, not
/// research.
///
/// Calls through the `mediaPlanningAi` Cloud Function (see
/// `functions/index.js`) rather than the Gemini SDK directly — the
/// client never holds AI_API_KEY. That matters especially on web: a
/// key bundled into a Flutter web build becomes a public, fetchable
/// file on the deployed site, not just something buried in a compiled
/// app binary. The Cloud Function holds the key server-side and only
/// accepts calls from a signed-in Firebase user, mirroring the same
/// proxy pattern already used for the Finance AI Report
/// (financeAiReport).
class MediaPlanningAiService {
  MediaPlanningAiService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// AI drafting just needs a signed-in user — the app is auth-gated
  /// already, so this is effectively always true, but it lets the UI
  /// show an honest state if the session somehow has no current user.
  bool get isAvailable => firebase_auth.FirebaseAuth.instance.currentUser != null;

  Uri _endpoint() {
    if (kIsWeb) {
      final host = Uri.base.host;
      final isLocalhost = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1' ||
          host.endsWith('.local');
      if (!isLocalhost) {
        return Uri.parse('${Uri.base.origin}/api/media-planning-ai');
      }
    }
    return Uri.parse(
      'https://us-central1-hc-petty-cash-report.cloudfunctions.net/mediaPlanningAi',
    );
  }

  Future<Map<String, dynamic>> _callTask(String task, Map<String, dynamic> payload) async {
    final idToken = await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw StateError('You must be signed in to use AI drafting.');
    }

    final response = await _http.post(
      _endpoint(),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'task': task, 'payload': payload}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) detail = data['error'].toString();
      } catch (_) {}
      throw StateError('AI service error: ${response.statusCode} $detail');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>? ?? {};
  }

  // ---------------------------------------------------------------------
  // 1. Objective & Intent Co-writer (Steps 1 & 3)
  // ---------------------------------------------------------------------

  Future<PlanningObjective> draftObjective(List<String> roughBullets) async {
    final json = await _callTask('objective', {'bullets': roughBullets});
    return PlanningObjective(
      pains: List<String>.from(json['pains'] ?? const []),
      whyItExists: json['whyItExists'] ?? '',
      practicalConditions: json['practicalConditions'] ?? '',
      metricPriority: List<String>.from(json['metricPriority'] ?? const []),
    );
  }

  Future<PlanningStrategicIntent> draftStrategicIntent(List<String> roughBullets) async {
    final json = await _callTask('strategicIntent', {'bullets': roughBullets});
    return PlanningStrategicIntent(
      transformation: json['transformation'] ?? '',
      attractionHook: json['attractionHook'] ?? '',
      retentionPlan: json['retentionPlan'] ?? '',
      metrics: List<String>.from(json['metrics'] ?? const []),
    );
  }

  // ---------------------------------------------------------------------
  // 2. Audience Synthesizer (Step 2)
  // ---------------------------------------------------------------------

  Future<PlanningAudience> synthesizeAudience(String rawNotes) async {
    final json = await _callTask('audience', {'rawNotes': rawNotes});
    return PlanningAudience(
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

  Future<PlanningMarketResearch> scoutReferences({
    required String programIdea,
    String? preferredPlatform,
  }) async {
    final json = await _callTask('marketResearch', {
      'programIdea': programIdea,
      'preferredPlatform': preferredPlatform ?? '',
    });
    final refs = (json['references'] as List? ?? const [])
        .map((r) => PlanningReference.fromMap(Map<String, dynamic>.from(r)))
        .toList();
    return PlanningMarketResearch(
      references: refs,
      preferredPlatforms: List<String>.from(json['preferredPlatforms'] ?? const []),
      style: json['style'] ?? '',
      aspectRatio: PlanningAspectRatioLabel.fromString(json['aspectRatio']),
    );
  }

  // ---------------------------------------------------------------------
  // 4. Editorial Calendar Drafter (Step 6 — Distribution)
  // ---------------------------------------------------------------------

  Future<List<PlanningCalendarEntry>> draftEditorialCalendar({
    required List<String> platforms,
    required String frequency,
    required DateTime launchDate,
    int numberOfEntries = 8,
  }) async {
    final json = await _callTask('editorialCalendar', {
      'platforms': platforms,
      'frequency': frequency,
      'launchDate': launchDate.toIso8601String().split('T').first,
      'numberOfEntries': numberOfEntries,
    });
    return (json['entries'] as List? ?? const [])
        .map((e) => PlanningCalendarEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}
