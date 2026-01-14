import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Responsive utility class to handle different screen sizes and layouts
class ResponsiveHelper {
  // Breakpoints for different screen sizes
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Check if the current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if the current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if the current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Get appropriate padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      // Add extra horizontal padding for web on tablets too
      final basePadding = EdgeInsets.symmetric(
        horizontal: kIsWeb ? 64 : 24, // Extra horizontal padding for web
        vertical: 24,
      );
      return basePadding;
    } else {
      // For desktop/web, add more horizontal padding especially for web browsers
      final basePadding = EdgeInsets.symmetric(
        horizontal: kIsWeb ? 80 : 32, // Extra horizontal padding for web
        vertical: 24,
      );
      return basePadding;
    }
  }

  /// Get maximum content width for desktop to prevent stretching
  static double getMaxContentWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 1200;
    }
    return double.infinity;
  }

  /// Get appropriate cross axis count for grids
  static int getGridCrossAxisCount(
    BuildContext context, {
    int maxColumns = 4,
    double minItemWidth = 250,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = getScreenPadding(context);
    final availableWidth = screenWidth - (padding.left + padding.right);

    int columns = (availableWidth / minItemWidth).floor();
    return columns.clamp(1, maxColumns);
  }

  /// Get appropriate font sizes based on screen size
  static TextTheme getResponsiveTextTheme(BuildContext context) {
    final baseTheme = Theme.of(context).textTheme;

    if (isMobile(context)) {
      return baseTheme.copyWith(
        headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: 28),
        headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: 24),
        titleLarge: baseTheme.titleLarge?.copyWith(fontSize: 20),
        titleMedium: baseTheme.titleMedium?.copyWith(fontSize: 16),
      );
    } else if (isTablet(context)) {
      return baseTheme.copyWith(
        headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: 32),
        headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: 28),
        titleLarge: baseTheme.titleLarge?.copyWith(fontSize: 22),
        titleMedium: baseTheme.titleMedium?.copyWith(fontSize: 18),
      );
    } else {
      return baseTheme.copyWith(
        headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: 36),
        headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: 32),
        titleLarge: baseTheme.titleLarge?.copyWith(fontSize: 24),
        titleMedium: baseTheme.titleMedium?.copyWith(fontSize: 20),
      );
    }
  }

  /// Get responsive spacing
  static double getSpacing(
    BuildContext context, {
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive card elevation
  static double getCardElevation(BuildContext context) {
    return isMobile(context) ? 2 : 4;
  }

  /// Get responsive border radius
  static double getBorderRadius(BuildContext context) {
    return isMobile(context) ? 8 : 12;
  }
}

/// Responsive layout builder widget for different screen configurations
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (ResponsiveHelper.isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }
}

/// Responsive grid that automatically adjusts based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 250,
    this.maxColumns = 4,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(
      context,
      maxColumns: maxColumns,
      minItemWidth: minItemWidth,
    );

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: childAspectRatio,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Responsive container that limits width on desktop
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ?? ResponsiveHelper.getScreenPadding(context);
    final effectiveMaxWidth =
        maxWidth ?? ResponsiveHelper.getMaxContentWidth(context);

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}

/// Responsive wrap that automatically arranges items based on screen size
class ResponsiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;

  const ResponsiveWrap({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSpacing = ResponsiveHelper.getSpacing(
      context,
      mobile: spacing,
      tablet: spacing * 1.5,
      desktop: spacing * 2,
    );

    return Wrap(
      spacing: responsiveSpacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}
