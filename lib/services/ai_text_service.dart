import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/survey.dart';
import '../models/survey_response.dart';

class AITextService {
  GenerativeModel? _model;

  AITextService() {
    _initializeModel();
  }

  void _initializeModel() {
    _model = null;
    final apiKey = _getApiKey();
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    }
  }

  /// Reinitialize the model (useful when API key changes)
  void reinitialize() {
    _initializeModel();
  }

  void _ensureInitialized() {
    if (_model == null) {
      _initializeModel();
    }
  }

  String _getApiKey() {
    try {
      if (!dotenv.isInitialized) return '';
      return dotenv.env['AI_API_KEY']?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool get isAvailable {
    _ensureInitialized();
    return _model != null;
  }

  /// Enhance/improve the given text to be more professional and clear
  Future<AIResult> enhanceText(String text, {String? context}) async {
    _ensureInitialized();
    if (_model == null) {
      return AIResult(
        success: false,
        error: 'AI service not configured. Please set AI_API_KEY in .env.',
      );
    }

    if (text.trim().isEmpty) {
      return AIResult(success: false, error: 'Text is empty');
    }

    try {
      final contextHint = context != null
          ? 'Context: This is for $context.\n\n'
          : '';

      final prompt =
          '''
${contextHint}Please improve the following text to be more professional, clear, and well-structured. 
Keep the same meaning but enhance the language, grammar, and flow.
Only return the improved text without any explanation or quotation marks.

Original text:
$text
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final enhancedText = response.text?.trim() ?? '';

      if (enhancedText.isEmpty) {
        return AIResult(success: false, error: 'No response from AI');
      }

      return AIResult(success: true, text: enhancedText);
    } catch (e) {
      debugPrint('AI Enhancement Error: $e');
      return AIResult(
        success: false,
        error: 'AI service error: ${e.toString()}',
      );
    }
  }

  /// Check spelling and grammar, return corrected text with issues highlighted
  Future<SpellCheckResult> checkSpelling(String text) async {
    _ensureInitialized();
    if (_model == null) {
      return SpellCheckResult(
        success: false,
        error: 'AI service not configured. Please set AI_API_KEY in .env.',
      );
    }

    if (text.trim().isEmpty) {
      return SpellCheckResult(success: true, correctedText: text, issues: []);
    }

    try {
      final prompt =
          '''
Check the following text for spelling and grammar errors. 
Return a JSON response in this exact format:
{
  "correctedText": "the corrected version of the text",
  "issues": [
    {"original": "misspeled", "correction": "misspelled", "type": "spelling"},
    {"original": "grammer error", "correction": "grammar error", "type": "grammar"}
  ]
}

If there are no errors, return:
{
  "correctedText": "original text unchanged",
  "issues": []
}

Text to check:
$text
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';

      if (responseText.isEmpty) {
        return SpellCheckResult(success: false, error: 'No response from AI');
      }

      // Parse the JSON response
      try {
        // Clean up the response - remove markdown code blocks if present
        String jsonStr = responseText;
        if (jsonStr.startsWith('```json')) {
          jsonStr = jsonStr.substring(7);
        }
        if (jsonStr.startsWith('```')) {
          jsonStr = jsonStr.substring(3);
        }
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
        jsonStr = jsonStr.trim();

        // Parse manually for simplicity
        final correctedMatch = RegExp(
          r'"correctedText"\s*:\s*"([^"]*(?:\\"[^"]*)*)"',
        ).firstMatch(jsonStr);
        final correctedText =
            correctedMatch?.group(1)?.replaceAll('\\"', '"') ?? text;

        // Extract issues
        List<SpellCheckIssue> issues = [];
        final issuesMatch = RegExp(
          r'"issues"\s*:\s*\[(.*?)\]',
          dotAll: true,
        ).firstMatch(jsonStr);
        if (issuesMatch != null) {
          final issuesStr = issuesMatch.group(1) ?? '';
          final issueMatches = RegExp(
            r'\{\s*"original"\s*:\s*"([^"]*)"\s*,\s*"correction"\s*:\s*"([^"]*)"\s*,\s*"type"\s*:\s*"([^"]*)"\s*\}',
          ).allMatches(issuesStr);

          for (final match in issueMatches) {
            issues.add(
              SpellCheckIssue(
                original: match.group(1) ?? '',
                correction: match.group(2) ?? '',
                type: match.group(3) ?? 'spelling',
              ),
            );
          }
        }

        return SpellCheckResult(
          success: true,
          correctedText: correctedText,
          issues: issues,
        );
      } catch (parseError) {
        // If parsing fails, return the raw response as corrected text
        debugPrint('JSON Parse Error: $parseError');
        return SpellCheckResult(
          success: true,
          correctedText: responseText,
          issues: [],
        );
      }
    } catch (e) {
      debugPrint('Spell Check Error: $e');
      return SpellCheckResult(
        success: false,
        error: 'AI service error: ${e.toString()}',
      );
    }
  }

  /// Get the exchange rate for a currency pair on a specific date.
  /// Returns the number of THB per 1 unit of [fromCurrency].
  /// [fromCurrency] is 'MYR', 'USD', etc. Target is always THB.
  Future<ExchangeRateResult> getExchangeRate({
    required String fromCurrency,
    required DateTime date,
  }) async {
    _ensureInitialized();
    if (_model == null) {
      return ExchangeRateResult(
        success: false,
        error: 'AI service not configured. Please set AI_API_KEY in .env.',
      );
    }

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      final prompt =
          '''
You are a financial assistant with knowledge of historical currency exchange rates.

Provide the exchange rate for 1 $fromCurrency to THB (Thai Baht) on $dateStr.

Return ONLY a JSON object in this exact format, nothing else:
{
  "rate": 8.45,
  "note": "Approximate rate based on historical data for $dateStr"
}

The "rate" must be a number (how many THB you get for 1 $fromCurrency).
If you are not certain of the exact rate, provide your best estimate based on historical data.
Do not include any explanation outside the JSON.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text?.trim() ?? '';

      if (responseText.isEmpty) {
        return ExchangeRateResult(success: false, error: 'No response from AI');
      }

      // Extract JSON
      String jsonStr = responseText;
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.substring(7);
      if (jsonStr.startsWith('```')) jsonStr = jsonStr.substring(3);
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final rateMatch = RegExp(r'"rate"\s*:\s*([\d.]+)').firstMatch(jsonStr);
      final noteMatch = RegExp(r'"note"\s*:\s*"([^"]*)"').firstMatch(jsonStr);

      if (rateMatch == null) {
        return ExchangeRateResult(
          success: false,
          error: 'Could not parse exchange rate from AI response',
        );
      }

      final rate = double.tryParse(rateMatch.group(1) ?? '');
      if (rate == null || rate <= 0) {
        return ExchangeRateResult(
          success: false,
          error: 'Invalid exchange rate returned by AI',
        );
      }

      return ExchangeRateResult(
        success: true,
        rate: rate,
        note: noteMatch?.group(1),
      );
    } catch (e) {
      debugPrint('Exchange Rate Error: $e');
      return ExchangeRateResult(
        success: false,
        error: 'AI service error: ${e.toString()}',
      );
    }
  }

  /// Generate a professional resolution text based on the agenda item
  Future<AIResult> generateResolution(
    String itemTitle,
    String description, {
    String? context,
  }) async {
    _ensureInitialized();
    if (_model == null) {
      return AIResult(
        success: false,
        error: 'AI service not configured. Please set AI_API_KEY in .env.',
      );
    }

    try {
      final prompt =
          '''
Based on the following agenda item from an Administrative Committee meeting, generate a professional resolution text that would be used after voting.

Item Title: $itemTitle
Description: $description
${context != null ? 'Additional Context: $context' : ''}

Generate a formal resolution in the style of: "VOTED to [action] that [details]..."
Keep it concise, professional, and actionable.
Only return the resolution text without any explanation.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final resolutionText = response.text?.trim() ?? '';

      if (resolutionText.isEmpty) {
        return AIResult(success: false, error: 'No response from AI');
      }

      return AIResult(success: true, text: resolutionText);
    } catch (e) {
      debugPrint('Resolution Generation Error: $e');
      return AIResult(
        success: false,
        error: 'AI service error: ${e.toString()}',
      );
    }
  }

  /// Analyse survey response data and return strategic insights + recommendations.
  Future<AIResult> analyzeSurveyResponses({
    required Survey survey,
    required List<SurveyResponse> responses,
  }) async {
    _ensureInitialized();
    if (_model == null) {
      return AIResult(success: false, error: 'AI service not configured. Please set AI_API_KEY in .env.');
    }
    if (responses.isEmpty) {
      return AIResult(success: false, error: 'No responses to analyze.');
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('SURVEY: ${survey.title}');
      buffer.writeln('PURPOSE: ${survey.description}');
      buffer.writeln('TOTAL RESPONSES: ${responses.length}');
      buffer.writeln();

      for (final section in survey.sections) {
        buffer.writeln('── ${section.title} ──');
        for (final q in section.questions) {
          final answered = responses.where((r) => r.answerFor(q.id) != null).toList();
          if (answered.isEmpty) continue;
          buffer.writeln('\n${q.code}: ${q.text} (${answered.length} answered)');

          if (q.type == QuestionType.openText) {
            final samples = answered.take(5)
                .map((r) => r.answerFor(q.id)?.value?.toString() ?? '')
                .where((s) => s.isNotEmpty);
            for (final s in samples) { buffer.writeln('  - "$s"'); }
          } else if (q.type == QuestionType.scale) {
            final vals = answered
                .map((r) => r.answerFor(q.id)?.value)
                .whereType<int>()
                .toList();
            if (vals.isNotEmpty) {
              final avg = vals.reduce((a, b) => a + b) / vals.length;
              buffer.writeln('  Average: ${avg.toStringAsFixed(2)} / ${q.scaleMax ?? 5}');
              final counts = <int, int>{};
              for (final v in vals) { counts[v] = (counts[v] ?? 0) + 1; }
              counts.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key))
                ..forEach((e) => buffer.writeln('  ${e.key}: ${e.value} (${(e.value / vals.length * 100).toStringAsFixed(0)}%)'));
            }
          } else {
            final counts = <String, int>{};
            for (final r in answered) {
              final v = r.answerFor(q.id)?.value;
              if (v is List) {
                for (final item in v) { final k = item.toString(); counts[k] = (counts[k] ?? 0) + 1; }
              } else if (v != null) {
                final k = v.toString();
                counts[k] = (counts[k] ?? 0) + 1;
              }
            }
            final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            for (final e in sorted.take(6)) {
              buffer.writeln('  ${e.key}: ${e.value} (${(e.value / answered.length * 100).toStringAsFixed(0)}%)');
            }
          }
        }
      }

      final prompt = '''
You are an expert audience research analyst for Hope Channel Southeast Asia (HCSEA), a Christian media ministry producing digital content across Southeast Asia.

Analyze the following survey data and provide strategic insights:

${buffer.toString()}

Please provide a structured analysis with these sections:

## Key Findings
3–5 bullet points of the most significant insights from the data.

## Audience Profile
A short paragraph describing who the respondents are based on the data.

## Opportunities
2–3 specific opportunities this data reveals for HCSEA's content strategy.

## Recommendations
4–5 specific, actionable recommendations for HCSEA based on this data. Be concrete and data-driven.

## Content Strategy Implications
How should these findings shape HCSEA's content topics, format, or platform strategy?

Be concise, specific, and reference actual numbers/percentages from the data where possible.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) return AIResult(success: false, error: 'No response from AI');
      return AIResult(success: true, text: text);
    } catch (e) {
      debugPrint('Survey Analysis Error: $e');
      return AIResult(success: false, error: 'AI service error: ${e.toString()}');
    }
  }

  Future<AIResult> generateMeetingVotePurpose({
    required String meetingTitle,
    required List<String> agendaItems,
    String? currentPurpose,
  }) async {
    _ensureInitialized();
    if (_model == null) {
      return AIResult(
        success: false,
        error: 'AI service not configured. Please set AI_API_KEY in .env.',
      );
    }

    if (agendaItems.isEmpty) {
      return AIResult(
        success: false,
        error:
            'Add at least one agenda item before asking AI to draft a purpose.',
      );
    }

    try {
      final prompt =
          '''
You are helping draft an explanation for a board or committee e-vote invitation.

Meeting title: $meetingTitle

Agenda items:
${agendaItems.map((item) => '- $item').join('\n')}

${currentPurpose != null && currentPurpose.trim().isNotEmpty ? 'Existing draft purpose:\n${currentPurpose.trim()}\n' : ''}

Write a concise but clear purpose / explanation section for the invitation email.
Requirements:
- Explain what vote is needed.
- Summarize the main matter being considered.
- Mention why the vote is being requested now if that can be reasonably inferred.
- Keep the tone formal and suitable for board members.
- Use 1 short introductory sentence followed by 2-4 bullet points.
- Return only the final text, with no quotation marks and no extra commentary.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final generatedText = response.text?.trim() ?? '';

      if (generatedText.isEmpty) {
        return AIResult(success: false, error: 'No response from AI');
      }

      return AIResult(success: true, text: generatedText);
    } catch (e) {
      debugPrint('Meeting Purpose Generation Error: $e');
      return AIResult(
        success: false,
        error: 'AI service error: ${e.toString()}',
      );
    }
  }
}

class AIResult {
  final bool success;
  final String? text;
  final String? error;

  AIResult({required this.success, this.text, this.error});
}

class SpellCheckResult {
  final bool success;
  final String? correctedText;
  final List<SpellCheckIssue> issues;
  final String? error;

  SpellCheckResult({
    required this.success,
    this.correctedText,
    this.issues = const [],
    this.error,
  });

  bool get hasIssues => issues.isNotEmpty;
}

class SpellCheckIssue {
  final String original;
  final String correction;
  final String type; // 'spelling' or 'grammar'

  SpellCheckIssue({
    required this.original,
    required this.correction,
    required this.type,
  });
}

class ExchangeRateResult {
  final bool success;
  final double? rate;
  final String? note;
  final String? error;

  ExchangeRateResult({required this.success, this.rate, this.note, this.error});
}
