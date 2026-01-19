/// Configuration for student grade-based hourly rates.
///
/// Rate Structure (THB per hour):
/// | Role             | Grade A | Grade B | Grade C | Grade D |
/// |------------------|---------|---------|---------|---------|
/// | Video Editor     | 60      | 50      | 42      | 35      |
/// | Producer         | 60      | 50      | 42      | 35      |
/// | Content Creator  | 60      | 50      | 42      | 35      |
/// | Language Editor  | 55      | 46      | 38      | 32      |
/// | Other            | 50      | 42      | 35      | 30      |
class StudentRateConfig {
  /// Map of rates by role and grade
  static const Map<String, Map<String, double>> rates = {
    'Video Editor': {'A': 60, 'B': 50, 'C': 42, 'D': 35},
    'Producer': {'A': 60, 'B': 50, 'C': 42, 'D': 35},
    'Content Creator': {'A': 60, 'B': 50, 'C': 42, 'D': 35},
    'Language Editor': {'A': 55, 'B': 46, 'C': 38, 'D': 32},
    'Other': {'A': 50, 'B': 42, 'C': 35, 'D': 30},
  };

  /// List of valid grades
  static const List<String> grades = ['A', 'B', 'C', 'D'];

  /// List of valid roles
  static const List<String> roles = [
    'Video Editor',
    'Producer',
    'Content Creator',
    'Language Editor',
    'Other',
  ];

  /// Get the hourly rate for a given role and grade.
  /// Returns 0.0 if the role or grade is not found.
  static double getRate(String? role, String? grade) {
    if (role == null || grade == null) return 0.0;

    // Normalize the role - try to match case-insensitively
    String normalizedRole = role;
    for (final r in rates.keys) {
      if (r.toLowerCase() == role.toLowerCase()) {
        normalizedRole = r;
        break;
      }
    }

    // Get the rate for the role and grade
    final roleRates = rates[normalizedRole];
    if (roleRates == null) {
      // If role not found, use 'Other' rates
      return rates['Other']?[grade.toUpperCase()] ?? 0.0;
    }

    return roleRates[grade.toUpperCase()] ?? 0.0;
  }

  /// Check if a grade is valid
  static bool isValidGrade(String? grade) {
    if (grade == null) return false;
    return grades.contains(grade.toUpperCase());
  }

  /// Get the display name for a grade
  static String getGradeDisplayName(String? grade) {
    if (grade == null) return 'Not Set';
    return 'Grade $grade';
  }
}
