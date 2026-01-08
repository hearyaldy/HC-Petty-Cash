import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Petty Cash Manager';
  static const String appVersion = '1.0.0';

  // Organization Information (Parent Organization)
  static const String organizationName = 'SOUTHEASTERN ASIA UNION MISSION OF SEVENTH-DAY ADVENTIST FOUNDATION (SEUM)';
  static const String organizationNameThai = 'มูลนิธิสหมิชชั่นเอเชียตะวันออกเฉียงใต้ของเซเว่นธ์เดย์แอ๊ดเวนตีส';
  static const String organizationAddress = '195 Moo.3, Muak Lek, Saraburi, 18180 Thailand';

  // Company Information (Reporting Entity)
  static const String companyName = 'Hope Channel Southeast Asia';
  static const String companyLogo = 'assets/images/hope_channel_logo.png';

  // Currency Settings
  static const String currencySymbol = '฿';
  static const String currencyCode = 'THB';
  static const String currencyName = 'Thai Baht';

  // Colors
  static const Color primaryColor = Colors.deepPurple;
  static const Color secondaryColor = Colors.purple;
  static const Color accentColor = Colors.amber;

  // Dimensions
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;
  static const double maxContentWidth = 1200.0;

  // Animation Durations
  static const Duration defaultDuration = Duration(milliseconds: 300);

  // Date Formats
  static const String dateFormat = 'MMM dd, yyyy';
  static const String dateTimeFormat = 'MMM dd, yyyy hh:mm a';
  static const String reportNumberFormat = 'PCR-yyyyMMdd-000';

  // Security and Demo Mode
  static const bool enableDemoAccounts = false; // Set to false for production
}

class AppRoutes {
  static const String login = '/';
  static const String dashboard = '/dashboard';
  static const String reports = '/reports';
  static const String reportDetails = '/reports/:id';
  static const String newReport = '/reports/new';
  static const String approvals = '/approvals';
  static const String admin = '/admin';
}
