import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'ai_text_service.dart' show ExchangeRateResult;

/// Calls through the `exchangeRateAi` Cloud Function (see
/// `functions/index.js`) rather than holding a Gemini model client-side —
/// the client never holds AI_API_KEY, same proxy pattern as
/// [MediaPlanningAiService]. Replaces AITextService.getExchangeRate, which
/// depended on the app's .env being loaded via flutter_dotenv; that file
/// isn't declared as a Flutter asset, so it silently fails to load in real
/// builds and the AI Rate button never had a key to call Gemini with.
class ExchangeRateAiService {
  ExchangeRateAiService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _endpoint() {
    if (kIsWeb) {
      final host = Uri.base.host;
      final isLocalhost = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1' ||
          host.endsWith('.local');
      if (!isLocalhost) {
        return Uri.parse('${Uri.base.origin}/api/exchange-rate-ai');
      }
    }
    return Uri.parse(
      'https://us-central1-hc-petty-cash-report.cloudfunctions.net/exchangeRateAi',
    );
  }

  /// Returns how many THB equal 1 unit of [fromCurrency] on [date],
  /// estimated from Gemini's historical knowledge.
  Future<ExchangeRateResult> getExchangeRate({
    required String fromCurrency,
    required DateTime date,
  }) async {
    final idToken = await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      return ExchangeRateResult(
        success: false,
        error: 'You must be signed in to fetch an exchange rate.',
      );
    }

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      final response = await _http.post(
        _endpoint(),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fromCurrency': fromCurrency, 'date': dateStr}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ExchangeRateResult(
          success: false,
          error: data['error']?.toString() ?? 'Exchange rate lookup failed: ${response.statusCode}',
        );
      }

      final result = data['data'] as Map<String, dynamic>? ?? {};
      final rate = (result['rate'] as num?)?.toDouble();
      if (rate == null || rate <= 0) {
        return ExchangeRateResult(success: false, error: 'Invalid exchange rate returned by AI');
      }

      return ExchangeRateResult(success: true, rate: rate, note: result['note'] as String?);
    } catch (e) {
      return ExchangeRateResult(success: false, error: 'AI service error: ${e.toString()}');
    }
  }
}
