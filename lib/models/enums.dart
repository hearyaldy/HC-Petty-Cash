enum UserRole {
  requester,
  manager,
  finance,
  admin;

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
