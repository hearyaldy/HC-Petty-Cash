import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'ai_text_service.dart' show AIResult, SpellCheckResult, SpellCheckIssue;

/// Calls through the `agendaAi` Cloud Function (see `functions/index.js`)
/// rather than holding a Gemini model client-side — the client never holds
/// AI_API_KEY, same proxy pattern as [ExchangeRateAiService] and
/// [MediaPlanningAiService]. Replaces AITextService.checkSpelling/
/// enhanceText for the ADCOM agenda editor, which depended on the app's
/// .env being loaded via flutter_dotenv; that file isn't declared as a
/// Flutter asset, so it silently fails to load in real builds and the AI
/// Spell Check button never had a key to call Gemini with.
class AgendaAiService {
  AgendaAiService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

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
        return Uri.parse('${Uri.base.origin}/api/agenda-ai');
      }
    }
    return Uri.parse(
      'https://us-central1-hc-petty-cash-report.cloudfunctions.net/agendaAi',
    );
  }

  Future<Map<String, dynamic>> _callTask(
    String task,
    Map<String, dynamic> payload,
  ) async {
    final idToken =
        await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken();
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

  /// Enhance/improve the given text to be more professional and clear.
  Future<AIResult> enhanceText(String text, {String? context}) async {
    if (text.trim().isEmpty) {
      return AIResult(success: false, error: 'Text is empty');
    }
    try {
      final data = await _callTask('enhanceText', {
        'text': text,
        'context': context,
      });
      final enhanced = (data['text'] as String?)?.trim() ?? '';
      if (enhanced.isEmpty) {
        return AIResult(success: false, error: 'No response from AI');
      }
      return AIResult(success: true, text: enhanced);
    } catch (e) {
      return AIResult(success: false, error: e.toString());
    }
  }

  /// Check spelling and grammar, return corrected text with issues highlighted.
  Future<SpellCheckResult> checkSpelling(String text) async {
    if (text.trim().isEmpty) {
      return SpellCheckResult(success: true, correctedText: text, issues: []);
    }
    try {
      final data = await _callTask('spellCheck', {'text': text});
      final correctedText = data['correctedText'] as String? ?? text;
      final issuesRaw = data['issues'] as List<dynamic>? ?? [];
      final issues = issuesRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => SpellCheckIssue(
              original: m['original']?.toString() ?? '',
              correction: m['correction']?.toString() ?? '',
              type: m['type']?.toString() ?? 'spelling',
            ),
          )
          .toList();
      return SpellCheckResult(
        success: true,
        correctedText: correctedText,
        issues: issues,
      );
    } catch (e) {
      return SpellCheckResult(success: false, error: e.toString());
    }
  }
}
