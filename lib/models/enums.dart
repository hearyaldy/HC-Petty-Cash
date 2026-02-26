import 'dart:ui' show Color;

enum UserRole {
  requester,
  manager,
  finance,
  admin,
  studentWorker;

  String get displayName {
    switch (this) {
      case UserRole.requester:
        return 'Requester';
      case UserRole.manager:
        return 'Manager';
      case UserRole.finance:
        return 'Finance';
      case UserRole.admin:
        return 'Admin';
      case UserRole.studentWorker:
        return 'Student Worker';
    }
  }
}

enum TransactionStatus {
  draft,
  pendingApproval,
  approved,
  rejected,
  processed;

  String get displayName {
    switch (this) {
      case TransactionStatus.draft:
        return 'Draft';
      case TransactionStatus.pendingApproval:
        return 'Pending Approval';
      case TransactionStatus.approved:
        return 'Approved';
      case TransactionStatus.rejected:
        return 'Rejected';
      case TransactionStatus.processed:
        return 'Processed';
    }
  }
}

enum ReportStatus {
  draft,
  submitted,
  underReview,
  approved,
  closed;

  String get displayName {
    switch (this) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.underReview:
        return 'Under Review';
      case ReportStatus.approved:
        return 'Approved';
      case ReportStatus.closed:
        return 'Closed';
    }
  }
}

enum PaymentMethod {
  cash,
  card,
  bankTransfer,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}

enum ExpenseCategory {
  office,
  travel,
  meals,
  utilities,
  maintenance,
  supplies,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.office:
        return 'Office Expenses';
      case ExpenseCategory.travel:
        return 'Travel';
      case ExpenseCategory.meals:
        return 'Meals & Entertainment';
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.maintenance:
        return 'Maintenance';
      case ExpenseCategory.supplies:
        return 'Supplies';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}

// Extension methods to provide displayName for string-based enum values
extension UserRoleExtension on String {
  String get userRoleDisplayName {
    final role = UserRole.values.firstWhere(
      (e) => e.name == this,
      orElse: () => UserRole.requester,
    );
    return role.displayName;
  }

  UserRole toUserRole() {
    return UserRole.values.firstWhere(
      (e) => e.name == this,
      orElse: () => UserRole.requester,
    );
  }
}

extension TransactionStatusExtension on String {
  String get transactionStatusDisplayName {
    final status = TransactionStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => TransactionStatus.draft,
    );
    return status.displayName;
  }

  TransactionStatus toTransactionStatus() {
    return TransactionStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => TransactionStatus.draft,
    );
  }
}

extension ReportStatusExtension on String {
  String get reportStatusDisplayName {
    final status = ReportStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ReportStatus.draft,
    );
    return status.displayName;
  }

  ReportStatus toReportStatus() {
    return ReportStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ReportStatus.draft,
    );
  }
}

extension ExpenseCategoryExtension on String {
  String get expenseCategoryDisplayName {
    final category = ExpenseCategory.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ExpenseCategory.other,
    );
    return category.displayName;
  }

  ExpenseCategory toExpenseCategory() {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ExpenseCategory.other,
    );
  }
}

extension PaymentMethodExtension on String {
  String get paymentMethodDisplayName {
    final method = PaymentMethod.values.firstWhere(
      (e) => e.name == this,
      orElse: () => PaymentMethod.cash,
    );
    return method.displayName;
  }

  PaymentMethod toPaymentMethod() {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == this,
      orElse: () => PaymentMethod.cash,
    );
  }
}

enum TravelLocation {
  local,
  abroad;

  String get displayName {
    switch (this) {
      case TravelLocation.local:
        return 'Local';
      case TravelLocation.abroad:
        return 'Abroad';
    }
  }

  double get perDiemRate {
    switch (this) {
      case TravelLocation.local:
        return 125.0; // 125 Baht per meal for local travel
      case TravelLocation.abroad:
        return 250.0; // 250 Baht per meal for abroad travel
    }
  }
}

extension TravelLocationExtension on String {
  String get travelLocationDisplayName {
    final location = TravelLocation.values.firstWhere(
      (e) => e.name == this,
      orElse: () => TravelLocation.local,
    );
    return location.displayName;
  }

  TravelLocation toTravelLocation() {
    return TravelLocation.values.firstWhere(
      (e) => e.name == this,
      orElse: () => TravelLocation.local,
    );
  }

  double get perDiemRate {
    return toTravelLocation().perDiemRate;
  }
}

// Employment-related enums for Staff model
enum EmploymentType {
  fullTime,
  partTime,
  contract,
  intern,
  consultant;

  String get displayName {
    switch (this) {
      case EmploymentType.fullTime:
        return 'Full Time';
      case EmploymentType.partTime:
        return 'Part Time';
      case EmploymentType.contract:
        return 'Contract';
      case EmploymentType.intern:
        return 'Intern';
      case EmploymentType.consultant:
        return 'Consultant';
    }
  }
}

enum EmploymentStatus {
  active,
  onLeave,
  resigned,
  terminated,
  retired;

  String get displayName {
    switch (this) {
      case EmploymentStatus.active:
        return 'Active';
      case EmploymentStatus.onLeave:
        return 'On Leave';
      case EmploymentStatus.resigned:
        return 'Resigned';
      case EmploymentStatus.terminated:
        return 'Terminated';
      case EmploymentStatus.retired:
        return 'Retired';
    }
  }
}

enum Gender {
  male,
  female,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
      case Gender.preferNotToSay:
        return 'Prefer not to say';
    }
  }
}

// Media Production enums
enum MediaLanguage {
  english,
  malay,
  thai,
  khmer,
  laos,
  chinese,
  vietnamese;

  String get displayName {
    switch (this) {
      case MediaLanguage.english:
        return 'English';
      case MediaLanguage.malay:
        return 'Malay';
      case MediaLanguage.thai:
        return 'Thai';
      case MediaLanguage.khmer:
        return 'Khmer';
      case MediaLanguage.laos:
        return 'Laos';
      case MediaLanguage.chinese:
        return 'Chinese';
      case MediaLanguage.vietnamese:
        return 'Vietnamese';
    }
  }

  String get code {
    switch (this) {
      case MediaLanguage.english:
        return 'en';
      case MediaLanguage.malay:
        return 'ms';
      case MediaLanguage.thai:
        return 'th';
      case MediaLanguage.khmer:
        return 'km';
      case MediaLanguage.laos:
        return 'lo';
      case MediaLanguage.chinese:
        return 'zh';
      case MediaLanguage.vietnamese:
        return 'vi';
    }
  }
}

extension MediaLanguageExtension on String {
  String get mediaLanguageDisplayName {
    final language = MediaLanguage.values.firstWhere(
      (e) => e.name == this || e.code == this,
      orElse: () => MediaLanguage.english,
    );
    return language.displayName;
  }

  MediaLanguage toMediaLanguage() {
    return MediaLanguage.values.firstWhere(
      (e) => e.name == this || e.code == this,
      orElse: () => MediaLanguage.english,
    );
  }
}

enum MediaPlatform {
  youtube,
  facebook,
  instagram,
  tiktok;

  String get displayName {
    switch (this) {
      case MediaPlatform.youtube:
        return 'YouTube';
      case MediaPlatform.facebook:
        return 'Facebook';
      case MediaPlatform.instagram:
        return 'Instagram';
      case MediaPlatform.tiktok:
        return 'TikTok';
    }
  }

  String get icon {
    switch (this) {
      case MediaPlatform.youtube:
        return 'youtube';
      case MediaPlatform.facebook:
        return 'facebook';
      case MediaPlatform.instagram:
        return 'instagram';
      case MediaPlatform.tiktok:
        return 'tiktok';
    }
  }
}

extension MediaPlatformExtension on String {
  String get mediaPlatformDisplayName {
    final platform = MediaPlatform.values.firstWhere(
      (e) => e.name == this,
      orElse: () => MediaPlatform.youtube,
    );
    return platform.displayName;
  }

  MediaPlatform toMediaPlatform() {
    return MediaPlatform.values.firstWhere(
      (e) => e.name == this,
      orElse: () => MediaPlatform.youtube,
    );
  }
}

enum ProductionType {
  series,
  standalone,
  liveStream,
  short;

  String get displayName {
    switch (this) {
      case ProductionType.series:
        return 'Series';
      case ProductionType.standalone:
        return 'Standalone Video';
      case ProductionType.liveStream:
        return 'Live Stream';
      case ProductionType.short:
        return 'Short/Reel';
    }
  }
}

extension ProductionTypeExtension on String {
  String get productionTypeDisplayName {
    final type = ProductionType.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ProductionType.standalone,
    );
    return type.displayName;
  }

  ProductionType toProductionType() {
    return ProductionType.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ProductionType.standalone,
    );
  }
}

enum ProductionStatus {
  planning,
  inProduction,
  postProduction,
  published,
  archived;

  String get displayName {
    switch (this) {
      case ProductionStatus.planning:
        return 'Planning';
      case ProductionStatus.inProduction:
        return 'In Production';
      case ProductionStatus.postProduction:
        return 'Post Production';
      case ProductionStatus.published:
        return 'Published';
      case ProductionStatus.archived:
        return 'Archived';
    }
  }
}

extension ProductionStatusExtension on String {
  String get productionStatusDisplayName {
    final status = ProductionStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ProductionStatus.planning,
    );
    return status.displayName;
  }

  ProductionStatus toProductionStatus() {
    return ProductionStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => ProductionStatus.planning,
    );
  }
}

enum EpisodeStatus {
  draft,
  editing,
  scheduled,
  published;

  String get displayName {
    switch (this) {
      case EpisodeStatus.draft:
        return 'Draft';
      case EpisodeStatus.editing:
        return 'Editing';
      case EpisodeStatus.scheduled:
        return 'Scheduled';
      case EpisodeStatus.published:
        return 'Published';
    }
  }
}

extension EpisodeStatusExtension on String {
  String get episodeStatusDisplayName {
    final status = EpisodeStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => EpisodeStatus.draft,
    );
    return status.displayName;
  }

  EpisodeStatus toEpisodeStatus() {
    return EpisodeStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => EpisodeStatus.draft,
    );
  }
}

// Cash Advance enums
enum CashAdvanceStatus {
  draft,
  submitted,
  approved,
  disbursed,
  settled,
  rejected,
  cancelled;

  String get displayName {
    switch (this) {
      case CashAdvanceStatus.draft:
        return 'Draft';
      case CashAdvanceStatus.submitted:
        return 'Pending Approval';
      case CashAdvanceStatus.approved:
        return 'Approved';
      case CashAdvanceStatus.disbursed:
        return 'Disbursed';
      case CashAdvanceStatus.settled:
        return 'Settled';
      case CashAdvanceStatus.rejected:
        return 'Rejected';
      case CashAdvanceStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case CashAdvanceStatus.draft:
        return const Color(0xFF9E9E9E); // Grey
      case CashAdvanceStatus.submitted:
        return const Color(0xFFFFA726); // Orange
      case CashAdvanceStatus.approved:
        return const Color(0xFF42A5F5); // Blue
      case CashAdvanceStatus.disbursed:
        return const Color(0xFF66BB6A); // Green
      case CashAdvanceStatus.settled:
        return const Color(0xFF7E57C2); // Purple
      case CashAdvanceStatus.rejected:
        return const Color(0xFFEF5350); // Red
      case CashAdvanceStatus.cancelled:
        return const Color(0xFF78909C); // Blue Grey
    }
  }
}

extension CashAdvanceStatusExtension on String {
  String get cashAdvanceStatusDisplayName {
    final status = CashAdvanceStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => CashAdvanceStatus.draft,
    );
    return status.displayName;
  }

  CashAdvanceStatus toCashAdvanceStatus() {
    return CashAdvanceStatus.values.firstWhere(
      (e) => e.name == this,
      orElse: () => CashAdvanceStatus.draft,
    );
  }
}
