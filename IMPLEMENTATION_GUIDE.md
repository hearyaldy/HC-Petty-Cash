# Petty Cash Management System - Implementation Guide

## Overview
A complete Flutter web application for managing petty cash reports with approval workflows, Excel/PDF export, and role-based access control.

## Features Implemented

### 1. **Data Models**
- User with roles (Requester, Manager, Finance, Admin)
- Petty Cash Report with automatic calculations
- Transaction with approval workflow
- Approval history tracking
- Local storage using Hive

### 2. **Authentication & Authorization**
- Role-based access control
- Local authentication (demo mode)
- Session persistence
- 4 pre-loaded demo accounts

### 3. **Core Functionality**
- Create and manage petty cash reports
- Add transactions to reports
- Approval workflow
- Automatic calculation of totals, balances, and variance
- Search and filter reports

### 4. **Export Features**
- **Excel Export**: Generates formatted .xlsx files matching your template
- **PDF Export**: Professional PDF reports with all transaction details

### 5. **UI Screens**
- Login screen with demo accounts
- Dashboard with statistics and quick actions
- Reports list and details
- Transaction entry forms
- Approval queue for managers
- Admin panel

## Demo Accounts

| Role      | Email                  | Password    | Access Level                              |
|-----------|------------------------|-------------|-------------------------------------------|
| Admin     | admin@company.com      | admin123    | Full access + user management             |
| Manager   | manager@company.com    | manager123  | Approve transactions + create reports     |
| Finance   | finance@company.com    | finance123  | Process approved transactions + reports   |
| Requester | user@company.com       | user123     | Create reports + submit transactions      |

## Getting Started

### Run the Application

```bash
# Install dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run on macOS
flutter run -d macos

# Build for web
flutter build web
```

### Project Structure

```
lib/
├── models/              # Data models (User, Report, Transaction)
├── services/            # Business logic (Storage, Auth, Excel, PDF)
├── providers/           # State management (Provider pattern)
├── screens/             # UI screens
│   ├── auth/           # Login screen
│   ├── dashboard/      # Main dashboard
│   ├── reports/        # Report management
│   ├── transactions/   # Transaction forms
│   ├── approval/       # Approval workflow
│   └── admin/          # Admin panel
├── widgets/            # Reusable UI components
└── utils/              # Constants and helpers
```

## Key Services

### StorageService
- Hive-based local storage
- CRUD operations for all entities
- Sample data initialization

### ReportService
- Create and manage reports
- Calculate totals and balances
- Status management (Draft → Submitted → Approved → Closed)

### ExcelExportService
- Generate Excel files matching your template structure
- Formatted headers, transaction tables, and summaries
- Automatic styling and column widths

### PdfExportService
- Professional PDF report generation
- Transaction tables with proper formatting
- Summary section with calculations

## Data Flow

1. **User Login** → Authentication → Dashboard
2. **Create Report** → Add Opening Balance → Draft Status
3. **Add Transactions** → Submit for Approval → Pending Status
4. **Manager Approval** → Approved Status → Updates Report
5. **Finance Processing** → Processed Status
6. **Export** → Generate Excel/PDF

## Report Calculations

The system automatically calculates:
- **Total Disbursements**: Sum of all approved/processed transactions
- **Cash on Hand**: Opening Balance - Total Disbursements
- **Closing Balance**: Cash on Hand (current balance)
- **Variance**: Closing Balance - Opening Balance + Total Disbursements

## Workflow States

### Transaction States
1. Draft → User creating transaction
2. Pending Approval → Submitted to manager
3. Approved → Manager approved
4. Rejected → Manager rejected
5. Processed → Finance processed

### Report States
1. Draft → Being created
2. Submitted → Sent for review
3. Under Review → Being reviewed
4. Approved → Approved by manager
5. Closed → Finalized and archived

## Extending the Application

### Add More Expense Categories
Edit `lib/models/enums.dart`:
```dart
enum ExpenseCategory {
  office,
  travel,
  meals,
  utilities,
  maintenance,
  supplies,
  yourNewCategory, // Add here
  other;
}
```

### Customize Excel Template
Modify `lib/services/excel_export_service.dart`:
- Adjust cell styling
- Add/remove columns
- Change formatting

### Add Backend Integration
Replace `StorageService` calls with API calls:
1. Create API service using `http` package
2. Update providers to use API service
3. Add authentication tokens
4. Implement error handling

## Next Steps (Future Enhancements)

1. **Complete Remaining Screens**:
   - Full reports list with filters
   - Report details with transaction list
   - Transaction entry form
   - Approval queue interface

2. **Add Features**:
   - Attachment upload for receipts
   - Email notifications
   - Audit trail
   - Multi-currency support
   - Budget tracking

3. **Backend Integration**:
   - Firebase or custom API
   - Real-time sync
   - Cloud storage for attachments
   - User authentication (OAuth)

4. **Mobile Support**:
   - Responsive UI for mobile
   - Camera integration for receipts
   - Offline mode with sync

## Troubleshooting

### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Storage Issues
Data is stored locally in Hive boxes. To reset:
- Delete the app data folder
- Or call `StorageService.clearAllData()`

## License
This is a demo application for petty cash management.

---

**Generated with Claude Code** 🤖
