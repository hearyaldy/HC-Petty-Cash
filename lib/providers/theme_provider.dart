import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  AppSettings? _settings;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider() {
    _loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  AppSettings? get settings => _settings;
  String get colorTheme => _settings?.colorTheme ?? 'blue';

  Future<void> _loadSettings() async {
    try {
      _settings = await _settingsService.getSettings();
      _updateThemeMode();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings in ThemeProvider: $e');
    }
  }

  void _updateThemeMode() {
    if (_settings == null) return;

    switch (_settings!.theme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'auto':
        _themeMode = ThemeMode.system;
        break;
      default:
        _themeMode = ThemeMode.light;
    }
  }

  Future<void> updateTheme(String theme) async {
    if (_settings == null) return;

    final updated = _settings!.copyWith(theme: theme);
    await _settingsService.saveSettings(updated);
    _settings = updated;
    _updateThemeMode();
    notifyListeners();
  }

  Future<void> updateColorTheme(String colorTheme) async {
    if (_settings == null) return;

    final updated = _settings!.copyWith(colorTheme: colorTheme);
    await _settingsService.saveSettings(updated);
    _settings = updated;
    notifyListeners();
  }

  // Exact palette colors from dashboard mockup
  static const _palettes = {
    'blue':   (p500: Color(0xFF3B82F6), p600: Color(0xFF2563EB), p700: Color(0xFF1D4ED8)),
    'purple': (p500: Color(0xFF8B5CF6), p600: Color(0xFF7C3AED), p700: Color(0xFF6D28D9)),
    'green':  (p500: Color(0xFF10B981), p600: Color(0xFF059669), p700: Color(0xFF047857)),
    'red':    (p500: Color(0xFFF43F5E), p600: Color(0xFFE11D48), p700: Color(0xFFBE123C)),
    'slate':  (p500: Color(0xFF475569), p600: Color(0xFF334155), p700: Color(0xFF1E293B)),
  };

  // Get primary color based on color theme
  Color getPrimaryColor() {
    return _palettes[colorTheme]?.p600 ?? _palettes['blue']!.p600;
  }

  // Get gradient colors based on color theme
  List<Color> getGradientColors() {
    final p = _palettes[colorTheme] ?? _palettes['blue']!;
    return [p.p500, p.p700];
  }

  // Get seed color (p500) for ColorScheme generation
  Color getSeedColor() {
    return _palettes[colorTheme]?.p500 ?? _palettes['blue']!.p500;
  }

  // Light theme
  ThemeData get lightTheme {
    final primaryColor = getPrimaryColor();
    final seedColor = getSeedColor();

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.grey[50],
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
      ),
    );
  }

  // Dark theme
  ThemeData get darkTheme {
    final primaryColor = getPrimaryColor();

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: CardThemeData(
        elevation: 4,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
