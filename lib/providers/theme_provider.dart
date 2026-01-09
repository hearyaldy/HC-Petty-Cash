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

  // Get primary color based on color theme
  Color getPrimaryColor() {
    switch (colorTheme) {
      case 'purple':
        return Colors.purple;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'teal':
        return Colors.teal;
      case 'blue':
      default:
        return Colors.blue;
    }
  }

  // Get gradient colors based on color theme
  List<Color> getGradientColors() {
    switch (colorTheme) {
      case 'purple':
        return [Colors.purple.shade400, Colors.purple.shade600];
      case 'green':
        return [Colors.green.shade400, Colors.green.shade600];
      case 'orange':
        return [Colors.orange.shade400, Colors.orange.shade600];
      case 'red':
        return [Colors.red.shade400, Colors.red.shade600];
      case 'teal':
        return [Colors.teal.shade400, Colors.teal.shade600];
      case 'blue':
      default:
        return [Colors.blue.shade400, Colors.blue.shade600];
    }
  }

  // Light theme
  ThemeData get lightTheme {
    final primaryColor = getPrimaryColor();

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
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
