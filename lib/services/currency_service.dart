import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// Fetches live exchange rates from the open.er-api.com free API (no key needed).
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  Map<String, double>? _cachedRates; // USD-based rates table
  DateTime? _fetchedAt;
  static const _cacheDuration = Duration(hours: 1);

  static const _apiUrl = 'https://open.er-api.com/v6/latest/USD';

  /// Returns the full USD-based rates table, or null if the fetch fails.
  Future<Map<String, double>?> _getRates({bool forceRefresh = false}) async {
    // Return cached value if still fresh
    if (!forceRefresh &&
        _cachedRates != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _cacheDuration) {
      return _cachedRates;
    }

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final rates = data['rates'] as Map<String, dynamic>;
          _cachedRates = rates.map(
            (code, value) => MapEntry(code, (value as num).toDouble()),
          );
          _fetchedAt = DateTime.now();
          return _cachedRates;
        }
      }
    } catch (e) {
      AppLogger.warning('CurrencyService: Failed to fetch exchange rate: $e');
    }
    return null;
  }

  /// Returns how many units of [to] equal 1 unit of [from]
  /// (e.g. getRate('MYR', 'THB') → THB per 1 Ringgit).
  /// Returns null if the fetch fails or either currency is unknown.
  Future<double?> getRate(
    String from,
    String to, {
    bool forceRefresh = false,
  }) async {
    final rates = await _getRates(forceRefresh: forceRefresh);
    if (rates == null) return null;
    final fromRate = rates[from.toUpperCase()];
    final toRate = rates[to.toUpperCase()];
    if (fromRate == null || toRate == null || fromRate == 0) return null;
    return toRate / fromRate;
  }

  /// Returns the current USD → THB exchange rate.
  /// Returns null if the fetch fails.
  Future<double?> getUsdToThbRate({bool forceRefresh = false}) =>
      getRate('USD', 'THB', forceRefresh: forceRefresh);
}
