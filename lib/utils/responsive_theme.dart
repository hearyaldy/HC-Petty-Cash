import 'package:flutter/material.dart';

class ResponsiveTheme {
  static ThemeData getTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,

      // Typography
      textTheme: _getTextTheme(context, colorScheme),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _getTextTheme(
          context,
          colorScheme,
        ).titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        surfaceTintColor: Colors.transparent,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 8,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedTileColor: colorScheme.primaryContainer,
        selectedColor: colorScheme.onPrimaryContainer,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: _getTextTheme(context, colorScheme).bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static TextTheme _getTextTheme(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
    );
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      // Mobile
      return const EdgeInsets.all(16);
    } else if (width < 1200) {
      // Tablet
      return const EdgeInsets.all(24);
    } else {
      // Desktop
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
  }

  /// Get responsive spacing based on screen size
  static double getSpacing(
    BuildContext context, {
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return mobile;
    } else if (width < 1200) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// Get responsive border radius
  static double getBorderRadius(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return 8;
    } else {
      return 12;
    }
  }
}
