import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// Fetches live exchange rates from the open.er-api.com free API (no key needed).
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  double? _cachedRate;
  DateTime? _fetchedAt;
  static const _cacheDuration = Duration(hours: 1);

  static const _apiUrl = 'https://open.er-api.com/v6/latest/USD';

  /// Returns the current USD → THB exchange rate.
  /// Returns null if the fetch fails.
  Future<double?> getUsdToThbRate({bool forceRefresh = false}) async {
    // Return cached value if still fresh
    if (!forceRefresh &&
        _cachedRate != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _cacheDuration) {
      return _cachedRate;
    }

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final rates = data['rates'] as Map<String, dynamic>;
          final rate = (rates['THB'] as num?)?.toDouble();
          if (rate != null) {
            _cachedRate = rate;
            _fetchedAt = DateTime.now();
            return rate;
          }
        }
      }
    } catch (e) {
      AppLogger.warning('CurrencyService: Failed to fetch exchange rate: $e');
    }
    return null;
  }
}
