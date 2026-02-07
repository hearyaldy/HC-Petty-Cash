import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AITextService {
  GenerativeModel? _model;

  AITextService() {
    _initializeModel();
  }

  void _initializeModel() {
    _model = null;
    final apiKey = _getApiKey();
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
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
