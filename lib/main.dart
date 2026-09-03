import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/report_provider.dart';
import 'providers/project_report_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/reports/reports_list_screen.dart';
import 'screens/reports/choose_report_type_screen.dart';
import 'screens/reports/new_report_screen.dart';
import 'screens/reports/new_project_report_screen.dart';
import 'screens/reports/report_detail_screen.dart';
import 'screens/reports/project_report_detail_screen.dart';
import 'screens/approval/approvals_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/organization_management_screen.dart';
import 'screens/admin/payment_rate_screen.dart';
import 'screens/admin/admin_student_reports_screen.dart';
import 'screens/admin/admin_student_report_detail_screen.dart';
import 'screens/admin/staff_management_screen.dart';
import 'screens/admin/add_edit_staff_screen.dart';
import 'screens/admin/staff_details_screen.dart';
import 'screens/admin/salary_benefits_management_screen.dart';
import 'screens/admin/add_edit_salary_benefits_screen.dart';
import 'screens/admin/salary_benefits_history_screen.dart';
import 'screens/admin/employment_letter_template_screen.dart';
import 'screens/admin/add_edit_employment_letter_template_screen.dart';
import 'screens/admin/send_employment_letter_screen.dart';
import 'screens/transactions/transactions_summary_screen.dart';
import 'screens/settings/settings_screen_impl.dart';
import 'screens/student/student_onboarding_screen.dart';
import 'screens/student/student_report_screen.dart';
import 'screens/student/student_registration_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'screens/student/student_profile_screen.dart';
import 'screens/student/student_reports_list_screen.dart';
import 'screens/student/student_monthly_report_detail_screen.dart';
import 'screens/student/new_student_report_screen.dart';
import 'screens/traveling/traveling_reports_screen.dart';
import 'screens/traveling/traveling_report_detail_screen.dart';
import 'screens/admin/admin_traveling_reports_screen.dart';
import 'screens/admin/admin_traveling_report_detail_screen.dart';
import 'screens/transportation/transportation_requests_screen.dart';
import 'screens/transportation/transportation_request_detail_screen.dart';
import 'screens/admin/admin_income_reports_screen.dart';
import 'screens/hr/employee_onboarding_screen.dart';
import 'screens/hr/hr_data_submission_screen.dart';
import 'screens/hr/hr_management_screen.dart';
import 'screens/hr/my_hr_data_screen.dart';
import 'screens/hr/hr_data_submissions_screen.dart';
import 'screens/hr/annual_leave_request_screen.dart';
import 'screens/hr/annual_leave_requests_screen.dart';
import 'screens/hr/annual_leave_stats_screen.dart';
import 'screens/profile/user_profile_screen.dart';
import 'screens/income/income_reports_screen.dart';
import 'screens/income/new_income_report_screen.dart';
import 'screens/income/income_report_detail_screen.dart';
import 'screens/purchase_requisition/purchase_requisitions_screen.dart';
import 'screens/purchase_requisition/purchase_requisition_detail_screen.dart';
import 'screens/cash_advance/cash_advances_screen.dart';
import 'screens/cash_advance/cash_advance_detail_screen.dart';
import 'screens/cash_advance/new_cash_advance_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/inventory/add_edit_equipment_screen.dart';
import 'screens/inventory/equipment_detail_screen.dart';
import 'screens/inventory/qr_scan_screen.dart';
import 'screens/meetings/meetings_dashboard_screen.dart';
import 'screens/meetings/meetings_list_screen.dart';
import 'screens/meetings/minutes_search_screen.dart';
import 'screens/meetings/new_meeting_screen.dart';
import 'screens/meetings/edit_meeting_screen.dart';
import 'screens/meetings/meeting_detail_screen.dart';
import 'screens/meetings/action_items_screen.dart';
import 'screens/meetings/edit_agenda_screen.dart';
import 'screens/meetings/edit_minutes_screen.dart';
import 'screens/meetings/meeting_members_screen.dart';
import 'screens/meetings/meeting_vote_screen.dart';
import 'screens/hub/admin_hub_screen.dart';
import 'screens/hub/finance_dashboard_screen.dart';
import 'screens/hub/finance_ai_report_screen.dart';
import 'screens/hub/student_labor_dashboard_screen.dart';
import 'screens/hub/student_labor_budget_screen.dart';
import 'screens/hub/production_language_budget_screen.dart';
import 'screens/hub/hr_dashboard_screen.dart';
import 'screens/hub/inventory_dashboard_screen.dart';
import 'screens/admin/adcom_agenda_list_screen.dart';
import 'screens/admin/adcom_agenda_edit_screen.dart';
import 'screens/admin/adcom_agenda_view_screen.dart';
import 'screens/admin/adcom_minutes_edit_screen.dart';
import 'screens/admin/adcom_minutes_view_screen.dart';
import 'screens/admin/meeting_template_list_screen.dart';
import 'screens/admin/meeting_template_edit_screen.dart';
import 'providers/income_report_provider.dart';
import 'providers/media_production_provider.dart';
import 'providers/cash_advance_provider.dart';
import 'providers/medical_bill_reimbursement_provider.dart';
import 'providers/payment_voucher_provider.dart';
import 'screens/payment_voucher/payment_vouchers_screen.dart';
import 'screens/payment_voucher/new_payment_voucher_screen.dart';
import 'screens/payment_voucher/payment_voucher_detail_screen.dart';
import 'screens/payment_voucher/edit_payment_voucher_screen.dart';
import 'screens/medical_reimbursement/medical_reimbursement_list_screen.dart';
import 'screens/medical_reimbursement/medical_reimbursement_detail_screen.dart';
import 'screens/expense_claim/expense_claims_list_screen.dart';
import 'screens/expense_claim/new_expense_claim_screen.dart';
import 'screens/expense_claim/expense_claim_detail_screen.dart';
import 'providers/expense_claim_provider.dart';
import 'providers/internal_debit_note_provider.dart';
import 'screens/internal_debit_note/internal_debit_notes_screen.dart';
import 'screens/internal_debit_note/new_internal_debit_note_screen.dart';
import 'screens/internal_debit_note/internal_debit_note_detail_screen.dart';
import 'screens/internal_debit_note/edit_internal_debit_note_screen.dart';
import 'screens/hub/media_dashboard_screen.dart';
import 'screens/budget/budget_list_screen.dart';
import 'screens/budget/budget_year_detail_screen.dart';
import 'providers/budget_provider.dart';
import 'screens/media/media_productions_screen.dart';
import 'screens/media/add_edit_production_screen.dart';
import 'screens/media/media_production_detail_screen.dart';
import 'screens/media/add_edit_engagement_screen.dart';
import 'screens/media/media_engagement_screen.dart';
import 'screens/media/media_annual_report_screen.dart';
import 'screens/media/media_yearly_stats_screen.dart';
import 'screens/media/media_period_reports_screen.dart';
import 'screens/media/media_production_budget_screen.dart';
import 'utils/constants.dart';
import 'utils/logger.dart';
import 'utils/responsive_theme.dart';
import 'providers/survey_provider.dart';
import 'screens/survey/survey_fill_screen.dart';
import 'screens/survey/admin_surveys_screen.dart';
import 'screens/survey/admin_survey_responses_screen.dart';
import 'screens/survey/admin_survey_edit_screen.dart';
import 'screens/privacy/privacy_policy_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('DEBUG: .env load failed: $e');
  }

  // Initialize logger
  AppLogger.init();

  // Initialize Firebase - must complete before app starts
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;

    // Configure Firestore persistence per platform to avoid web assertion crash
    if (kIsWeb) {
      // Use memory-only cache for web to avoid IndexedDB issues
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('DEBUG: Firestore configured for web (persistence disabled)');
    } else {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
    debugPrint('DEBUG: Firebase initialized successfully');
  } catch (e) {
    AppLogger.severe('Firebase initialization error: $e');
    debugPrint('DEBUG: Firebase initialization error: $e');
    // Continue anyway for demo purposes
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MyApp({super.key, this.firebaseInitialized = false});

  @override
  Widget build(BuildContext context) {
    // Show error screen if Firebase failed to initialize
    if (!firebaseInitialized) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        ),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Firebase Initialization Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your internet connection and try again.',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => ProjectReportProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => IncomeReportProvider()),
        ChangeNotifierProvider(create: (_) => MediaProductionProvider()),
        ChangeNotifierProvider(create: (_) => CashAdvanceProvider()),
        ChangeNotifierProvider(
          create: (_) => MedicalBillReimbursementProvider(),
        ),
        ChangeNotifierProvider(create: (_) => PaymentVoucherProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseClaimProvider()),
        ChangeNotifierProvider(create: (_) => InternalDebitNoteProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          final seed = themeProvider.getSeedColor();
          return MaterialApp.router(
            title: AppConstants.appName,
            theme: ResponsiveTheme.getTheme(context, seedColor: seed),
            darkTheme: ResponsiveTheme.getTheme(context, seedColor: seed),
            themeMode: themeProvider.themeMode,
            routerConfig: _createRouter(authProvider),
            debugShowCheckedModeBanner: false,
            localizationsDelegates: [
              ...GlobalMaterialLocalizations.delegates,
              quill.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              // Add other supported locales if needed
            ],
          );
        },
      ),
    );
  }

  GoRouter _createRouter(AuthProvider authProvider) {
    final initialRoute = kIsWeb
        ? () {
            final path = Uri.base.path.isEmpty ? '/' : Uri.base.path;
            final query = Uri.base.hasQuery ? '?${Uri.base.query}' : '';
            return '$path$query';
          }()
        : '/';

    return GoRouter(
      initialLocation: initialRoute,
      refreshListenable: authProvider,
      redirect: (context, state) async {
        final currentPath = state.uri.path;
        final currentFragment = state.uri.fragment;
        final fullLocation = state.uri.toString();
        final isLoggingIn = currentPath == '/' || currentPath == '/login';
        final isRegistering = currentPath == '/student-register';
        final isOnboarding = currentPath.startsWith('/student-onboarding');
        final isPublicMeetingVote =
            currentPath.startsWith('/meeting-vote/') ||
            currentFragment.startsWith('/meeting-vote/') ||
            fullLocation.contains('/meeting-vote/');
        final isPublicSurvey = currentPath.startsWith('/survey/');
        final isPrivacyPolicy = currentPath == '/privacy-policy';
        final user = authProvider.currentUser;

        // Wait for auth bootstrap before deciding redirects, especially for
        // direct-entry public web routes like meeting vote links.
        if (!authProvider.isInitialized) {
          return null;
        }

        // Allow unauthenticated access to login, register, onboarding, and
        // tokenized meeting vote pages.
        if (!authProvider.isAuthenticated &&
            !isLoggingIn &&
            !isRegistering &&
            !isOnboarding &&
            !isPublicMeetingVote &&
            !isPublicSurvey &&
            !isPrivacyPolicy) {
          return '/';
        }

        // Redirect authenticated users from login/register pages
        if (authProvider.isAuthenticated && (isLoggingIn || isRegistering)) {
          // Check if student worker needs onboarding
          if (user?.role == 'studentWorker') {
            // Check if student profile exists in Firestore
            final profileDoc = await FirebaseFirestore.instance
                .collection('student_profiles')
                .doc(user!.id)
                .get();

            if (!profileDoc.exists) {
              return '/student-onboarding';
            }
            return '/student-dashboard';
          }
          return '/admin-hub';
        }

        // If student is going to dashboard, let them through (no redirect)
        if (user?.role == 'studentWorker' && currentPath == '/student-dashboard') {
          return null;
        }

        // Student workers can only access student routes
        if (user?.role == 'studentWorker') {
          final studentRoutes = [
            '/student-dashboard',
            '/student-reports',
            '/student-report',
            '/student-report/new',
            '/student-monthly-report-detail',
            '/student-onboarding',
            '/student-profile',
            '/settings',
          ];
          if (!studentRoutes.any((route) => currentPath.startsWith(route))) {
            return '/student-dashboard';
          }
        }

        // Staff records and salary/benefits screens hold sensitive HR/
        // financial data — restrict to admins only.
        final staffOrSalaryRoutes = ['/admin/staff', '/admin/salary-benefits'];
        if (user?.role != 'admin' &&
            staffOrSalaryRoutes.any((route) => currentPath.startsWith(route))) {
          return '/admin-hub';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: '/privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: '/student-register',
          builder: (context, state) => const StudentRegistrationScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) {
            final type = state.uri.queryParameters['type'];
            return ReportsListScreen(initialReportType: type);
          },
        ),
        GoRoute(
          path: '/reports/new',
          builder: (context, state) => const ChooseReportTypeScreen(),
        ),
        GoRoute(
          path: '/reports/new/petty-cash',
          builder: (context, state) =>
              const NewReportScreen(reportType: 'petty_cash'),
        ),
        GoRoute(
          path: '/reports/new/advance-settlement',
          builder: (context, state) {
            final cashAdvanceId = state.uri.queryParameters['cashAdvanceId'];
            final purchaseRequisitionId =
                state.uri.queryParameters['purchaseRequisitionId'];
            return NewReportScreen(
              reportType: 'advance_settlement',
              cashAdvanceId: cashAdvanceId,
              purchaseRequisitionId: purchaseRequisitionId,
            );
          },
        ),
        GoRoute(
          path: '/reports/new/project',
          builder: (context, state) => const NewProjectReportScreen(),
        ),
        GoRoute(
          path: '/reports/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final autoAdd =
                state.extra is Map &&
                (state.extra as Map)['action'] == 'addTransaction';
            return ReportDetailScreen(
              reportId: id,
              autoLaunchAddTransaction: autoAdd == true,
            );
          },
        ),
        GoRoute(
          path: '/project-reports/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final autoAdd =
                state.extra is Map &&
                (state.extra as Map)['action'] == 'addTransaction';
            return ProjectReportDetailScreen(
              reportId: id,
              autoLaunchAddTransaction: autoAdd == true,
            );
          },
        ),
        GoRoute(
          path: '/approvals',
          builder: (context, state) => const ApprovalsScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsSummaryScreen(),
        ),
        // Income report routes
        GoRoute(
          path: '/income',
          builder: (context, state) => const IncomeReportsScreen(),
        ),
        GoRoute(
          path: '/income/new',
          builder: (context, state) => const NewIncomeReportScreen(),
        ),
        GoRoute(
          path: '/income/:reportId',
          builder: (context, state) {
            final reportId = state.pathParameters['reportId']!;
            return IncomeReportDetailScreen(reportId: reportId);
          },
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreenImpl(),
        ),
        // Hub Routes
        GoRoute(
          path: '/admin-hub',
          builder: (context, state) => const AdminHubScreen(),
        ),
        GoRoute(
          path: '/finance-dashboard',
          builder: (context, state) => const FinanceDashboardScreen(),
        ),
        GoRoute(
          path: '/finance-ai-report',
          builder: (context, state) => const FinanceAiReportScreen(),
        ),
        GoRoute(
          path: '/student-labor-dashboard',
          builder: (context, state) => const StudentLaborDashboardScreen(),
        ),
        GoRoute(
          path: '/student-labor/budget',
          builder: (context, state) => const StudentLaborBudgetScreen(),
        ),
        GoRoute(
          path: '/finance/production-budget',
          builder: (context, state) => const ProductionLanguageBudgetScreen(),
        ),
        GoRoute(
          path: '/hr-dashboard',
          builder: (context, state) => const HrDashboardScreen(),
        ),
        GoRoute(
          path: '/inventory-dashboard',
          builder: (context, state) => const InventoryDashboardScreen(),
        ),
        // Media Production Routes
        GoRoute(
          path: '/media-dashboard',
          builder: (context, state) => const MediaDashboardScreen(),
        ),
        GoRoute(
          path: '/media/productions',
          builder: (context, state) => const MediaProductionsScreen(),
        ),
        GoRoute(
          path: '/media/productions/add',
          builder: (context, state) => const AddEditProductionScreen(),
        ),
        GoRoute(
          path: '/media/productions/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return MediaProductionDetailScreen(productionId: id);
          },
        ),
        GoRoute(
          path: '/media/productions/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AddEditProductionScreen(productionId: id);
          },
        ),
        GoRoute(
          path: '/media/productions/:id/engagement/add',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AddEditEngagementScreen(productionId: id);
          },
        ),
        GoRoute(
          path: '/media/engagement',
          builder: (context, state) => const MediaEngagementScreen(),
        ),
        GoRoute(
          path: '/media/engagement/add',
          builder: (context, state) => const AddEditEngagementScreen(),
        ),
        GoRoute(
          path: '/media/reports/annual',
          builder: (context, state) => const MediaAnnualReportScreen(),
        ),
        GoRoute(
          path: '/media/stats/yearly',
          builder: (context, state) => const MediaYearlyStatsScreen(),
        ),
        GoRoute(
          path: '/media/stats/period',
          builder: (context, state) => const MediaPeriodReportsScreen(),
        ),
        GoRoute(
          path: '/media/production-budget',
          builder: (context, state) => const MediaProductionBudgetScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/admin/organizations',
          builder: (context, state) => const OrganizationManagementScreen(),
        ),
        GoRoute(
          path: '/admin/staff',
          builder: (context, state) => const StaffManagementScreen(),
        ),
        GoRoute(
          path: '/admin/staff/add',
          builder: (context, state) => const AddEditStaffScreen(),
        ),
        GoRoute(
          path: '/admin/staff/edit/:staffId',
          builder: (context, state) {
            final staffId = state.pathParameters['staffId']!;
            return AddEditStaffScreen(staffId: staffId);
          },
        ),
        GoRoute(
          path: '/admin/staff/details/:staffId',
          builder: (context, state) {
            final staffId = state.pathParameters['staffId']!;
            return StaffDetailsScreen(staffId: staffId);
          },
        ),
        GoRoute(
          path: '/admin/payment-rates',
          builder: (context, state) => const PaymentRateScreen(),
        ),
        GoRoute(
          path: '/admin/salary-benefits',
          builder: (context, state) => const SalaryBenefitsManagementScreen(),
        ),
        GoRoute(
          path: '/admin/salary-benefits/edit',
          builder: (context, state) => const AddEditSalaryBenefitsScreen(),
        ),
        GoRoute(
          path: '/admin/salary-benefits/history',
          builder: (context, state) => const SalaryBenefitsHistoryScreen(),
        ),
        GoRoute(
          path: '/admin/employment-letter-template',
          builder: (context, state) => const EmploymentLetterTemplateScreen(),
        ),
        GoRoute(
          path: '/admin/employment-letter-template/edit',
          builder: (context, state) =>
              const AddEditEmploymentLetterTemplateScreen(),
        ),
        GoRoute(
          path: '/admin/employment-letter/send',
          builder: (context, state) => const SendEmploymentLetterScreen(),
        ),
        GoRoute(
          path: '/admin/student-reports',
          builder: (context, state) => const AdminStudentReportsScreen(),
        ),
        GoRoute(
          path: '/admin/student-reports/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final month = state.uri.queryParameters['month'] ?? '';
            final monthDisplay =
                state.uri.queryParameters['monthDisplay'] ?? '';
            return AdminStudentReportDetailScreen(
              reportId: id,
              month: month,
              monthDisplay: monthDisplay,
            );
          },
        ),
        GoRoute(
          path: '/student-dashboard',
          builder: (context, state) => const StudentDashboardScreen(),
        ),
        GoRoute(
          path: '/student-profile',
          builder: (context, state) => const StudentProfileScreen(),
        ),
        GoRoute(
          path: '/student-onboarding',
          builder: (context, state) {
            // Try to get data from query parameters first (from registration)
            final queryUserId = state.uri.queryParameters['userId'];
            final queryUserName = state.uri.queryParameters['userName'];
            final queryUserEmail = state.uri.queryParameters['userEmail'];
            final queryWorkerType = state.uri.queryParameters['workerType'];

            // Fallback to authProvider if query params not available
            final user = authProvider.currentUser;

            // Use query params if available, otherwise use current user
            final userId = queryUserId ?? user?.id;
            final userName = queryUserName ?? user?.name;
            final userEmail = queryUserEmail ?? user?.email;
            final workerType = queryWorkerType ?? user?.workerType ?? 'student';

            if (userId == null || userName == null || userEmail == null) {
              // If we still don't have user data, show loading
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return StudentOnboardingScreen(
              userId: userId,
              userName: userName,
              userEmail: userEmail,
              workerType: workerType,
            );
          },
        ),
        GoRoute(
          path: '/student-reports',
          builder: (context, state) => const StudentReportsListScreen(),
        ),
        GoRoute(
          path: '/student-report',
          builder: (context, state) {
            final month = state.uri.queryParameters['month'];
            final monthDisplay = state.uri.queryParameters['monthDisplay'];
            return StudentReportScreen(
              initialMonth: month,
              initialMonthDisplay: monthDisplay,
            );
          },
        ),
        GoRoute(
          path: '/student-report/new',
          builder: (context, state) => const NewStudentReportScreen(),
        ),
        GoRoute(
          path: '/student-monthly-report-detail',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return StudentMonthlyReportDetailScreen(
              reportId: extra['reportId'] as String,
              month: extra['month'] as String,
              monthDisplay: extra['monthDisplay'] as String,
            );
          },
        ),
        // Traveling Reports Routes
        GoRoute(
          path: '/traveling-reports',
          builder: (context, state) => const TravelingReportsScreen(),
        ),
        GoRoute(
          path: '/traveling-reports/:reportId',
          builder: (context, state) {
            final reportId = state.pathParameters['reportId']!;
            return TravelingReportDetailScreen(reportId: reportId);
          },
        ),
        // Transportation Request Routes
        GoRoute(
          path: '/transportation-requests',
          builder: (context, state) => const TransportationRequestsScreen(),
        ),
        GoRoute(
          path: '/transportation-requests/:requestId',
          builder: (context, state) {
            final requestId = state.pathParameters['requestId']!;
            return TransportationRequestDetailScreen(requestId: requestId);
          },
        ),
        GoRoute(
          path: '/admin/budget',
          builder: (context, state) => const BudgetListScreen(),
        ),
        GoRoute(
          path: '/admin/budget/:yearId',
          builder: (context, state) {
            final yearId = state.pathParameters['yearId']!;
            return BudgetYearDetailScreen(budgetYearId: yearId);
          },
        ),
        GoRoute(
          path: '/admin/traveling-reports',
          builder: (context, state) => const AdminTravelingReportsScreen(),
        ),
        GoRoute(
          path: '/admin/income',
          builder: (context, state) => const AdminIncomeReportsScreen(),
        ),
        GoRoute(
          path: '/admin/income/:reportId',
          builder: (context, state) {
            final reportId = state.pathParameters['reportId']!;
            return IncomeReportDetailScreen(reportId: reportId);
          },
        ),
        GoRoute(
          path: '/admin/traveling-reports/:reportId',
          builder: (context, state) {
            final reportId = state.pathParameters['reportId']!;
            return AdminTravelingReportDetailScreen(reportId: reportId);
          },
        ),
        GoRoute(
          path: '/hr/employee-onboarding',
          builder: (context, state) => const EmployeeOnboardingScreen(),
        ),
        GoRoute(
          path: '/hr',
          builder: (context, state) => const HrManagementScreen(),
        ),
        GoRoute(
          path: '/user-profile',
          builder: (context, state) => const UserProfileScreen(),
        ),
        GoRoute(
          path: '/hr/data-submission',
          builder: (context, state) => const HrDataSubmissionScreen(),
        ),
        GoRoute(
          path: '/hr/my-data',
          builder: (context, state) => const MyHrDataScreen(),
        ),
        GoRoute(
          path: '/hr/data-submissions',
          builder: (context, state) => const HrDataSubmissionsScreen(),
        ),
        GoRoute(
          path: '/hr/leave-request',
          builder: (context, state) => const AnnualLeaveRequestScreen(),
        ),
        GoRoute(
          path: '/hr/leave-requests',
          builder: (context, state) => const AnnualLeaveRequestsScreen(),
        ),
        GoRoute(
          path: '/hr/leave-stats',
          builder: (context, state) => const AnnualLeaveStatsScreen(),
        ),
        // Purchase Requisition Routes
        GoRoute(
          path: '/purchase-requisitions',
          builder: (context, state) => const PurchaseRequisitionsScreen(),
        ),
        GoRoute(
          path: '/purchase-requisitions/:requisitionId',
          builder: (context, state) {
            final requisitionId = state.pathParameters['requisitionId']!;
            return PurchaseRequisitionDetailScreen(
              requisitionId: requisitionId,
            );
          },
        ),
        // Cash Advance Routes
        GoRoute(
          path: '/cash-advances',
          builder: (context, state) {
            final view = state.uri.queryParameters['view'];
            final initialViewMode = view == 'table'
                ? CashAdvancesViewMode.table
                : null;
            return CashAdvancesScreen(initialViewMode: initialViewMode);
          },
        ),
        GoRoute(
          path: '/cash-advances/new',
          builder: (context, state) {
            final prId = state.uri.queryParameters['purchaseRequisitionId'];
            final purpose = state.uri.queryParameters['purpose'];
            final amountStr = state.uri.queryParameters['amount'];
            final department = state.uri.queryParameters['department'];
            return NewCashAdvanceScreen(
              purchaseRequisitionId: prId,
              initialPurpose: purpose,
              initialAmount: amountStr != null
                  ? double.tryParse(amountStr)
                  : null,
              initialDepartment: department,
            );
          },
        ),
        GoRoute(
          path: '/cash-advances/:advanceId',
          builder: (context, state) {
            final advanceId = state.pathParameters['advanceId']!;
            return CashAdvanceDetailScreen(advanceId: advanceId);
          },
        ),
        GoRoute(
          path: '/cash-advances/:advanceId/edit',
          builder: (context, state) {
            final advanceId = state.pathParameters['advanceId']!;
            return NewCashAdvanceScreen(advanceId: advanceId);
          },
        ),
        // Medical Bill Reimbursement Routes
        GoRoute(
          path: '/medical-reimbursement',
          builder: (context, state) => const MedicalReimbursementListScreen(),
        ),
        GoRoute(
          path: '/medical-reimbursement/:reimbursementId',
          builder: (context, state) {
            final reimbursementId = state.pathParameters['reimbursementId']!;
            return MedicalReimbursementDetailScreen(
              reimbursementId: reimbursementId,
            );
          },
        ),
        // Expense Claim Routes
        GoRoute(
          path: '/expense-claims',
          builder: (context, state) => const ExpenseClaimsListScreen(),
        ),
        GoRoute(
          path: '/expense-claims/new',
          builder: (context, state) => const NewExpenseClaimScreen(),
        ),
        GoRoute(
          path: '/expense-claims/:claimId',
          builder: (context, state) {
            final claimId = state.pathParameters['claimId']!;
            return ExpenseClaimDetailScreen(claimId: claimId);
          },
        ),
        // Payment Voucher Routes
        GoRoute(
          path: '/payment-vouchers',
          builder: (context, state) => const PaymentVouchersScreen(),
        ),
        GoRoute(
          path: '/payment-vouchers/new',
          builder: (context, state) => const NewPaymentVoucherScreen(),
        ),
        GoRoute(
          path: '/payment-vouchers/:voucherId',
          builder: (context, state) {
            final voucherId = state.pathParameters['voucherId']!;
            return PaymentVoucherDetailScreen(voucherId: voucherId);
          },
        ),
        GoRoute(
          path: '/payment-vouchers/:voucherId/edit',
          builder: (context, state) {
            final voucherId = state.pathParameters['voucherId']!;
            return EditPaymentVoucherScreen(voucherId: voucherId);
          },
        ),
        // Internal Debit Note Routes
        GoRoute(
          path: '/internal-debit-notes',
          builder: (context, state) => const InternalDebitNotesScreen(),
        ),
        GoRoute(
          path: '/internal-debit-notes/new',
          builder: (context, state) => const NewInternalDebitNoteScreen(),
        ),
        GoRoute(
          path: '/internal-debit-notes/:noteId',
          builder: (context, state) {
            final noteId = state.pathParameters['noteId']!;
            return InternalDebitNoteDetailScreen(noteId: noteId);
          },
        ),
        GoRoute(
          path: '/internal-debit-notes/:noteId/edit',
          builder: (context, state) {
            final noteId = state.pathParameters['noteId']!;
            return EditInternalDebitNoteScreen(noteId: noteId);
          },
        ),
        // Equipment Inventory Routes
        GoRoute(
          path: '/inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/inventory/add',
          builder: (context, state) => const AddEditEquipmentScreen(),
        ),
        GoRoute(
          path: '/inventory/edit/:equipmentId',
          builder: (context, state) {
            final equipmentId = state.pathParameters['equipmentId']!;
            return AddEditEquipmentScreen(equipmentId: equipmentId);
          },
        ),
        GoRoute(
          path: '/inventory/:equipmentId',
          builder: (context, state) {
            final equipmentId = state.pathParameters['equipmentId']!;
            return EquipmentDetailScreen(equipmentId: equipmentId);
          },
        ),
        GoRoute(
          path: '/inventory/scan',
          builder: (context, state) => const QrScanScreen(),
        ),
        // Meeting Routes
        GoRoute(
          path: '/meetings-dashboard',
          builder: (context, state) => const MeetingsDashboardScreen(),
        ),
        GoRoute(
          path: '/meeting-vote/:token',
          builder: (context, state) {
            final token = state.pathParameters['token']!;
            final pin = state.uri.queryParameters['pin'];
            return MeetingVoteScreen(token: token, adminPin: pin);
          },
        ),
        GoRoute(
          path: '/meetings/list',
          builder: (context, state) {
            final type = state.uri.queryParameters['type'];
            final status = state.uri.queryParameters['status'];
            return MeetingsListScreen(filterType: type, filterStatus: status);
          },
        ),
        GoRoute(
          path: '/meetings/new',
          builder: (context, state) {
            final type = state.uri.queryParameters['type'];
            return NewMeetingScreen(preselectedType: type);
          },
        ),
        GoRoute(
          path: '/meetings/:meetingId/edit',
          builder: (context, state) {
            final meetingId = state.pathParameters['meetingId']!;
            return EditMeetingScreen(meetingId: meetingId);
          },
        ),
        GoRoute(
          path: '/meetings/action-items',
          builder: (context, state) {
            final meetingId = state.uri.queryParameters['meetingId'];
            return ActionItemsScreen(meetingId: meetingId);
          },
        ),
        GoRoute(
          path: '/meetings/committee-members',
          builder: (context, state) => const MeetingMembersScreen(),
        ),
        GoRoute(
          path: '/meetings/minutes/search',
          builder: (context, state) => const MinutesSearchScreen(),
        ),
        GoRoute(
          path: '/meetings/:meetingId/agenda/edit',
          builder: (context, state) {
            final meetingId = state.pathParameters['meetingId']!;
            return EditAgendaScreen(meetingId: meetingId);
          },
        ),
        GoRoute(
          path: '/meetings/:meetingId/minutes/edit',
          builder: (context, state) {
            final meetingId = state.pathParameters['meetingId']!;
            return EditMinutesScreen(meetingId: meetingId);
          },
        ),
        GoRoute(
          path: '/meetings/:meetingId',
          builder: (context, state) {
            final meetingId = state.pathParameters['meetingId']!;
            final tab = state.uri.queryParameters['tab'];
            return MeetingDetailScreen(meetingId: meetingId, initialTab: tab);
          },
        ),
        // ADCOM Agenda Routes
        GoRoute(
          path: '/admin/adcom-agendas',
          builder: (context, state) => const AdcomAgendaListScreen(),
        ),
        GoRoute(
          path: '/admin/adcom-agenda/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final meetingId = state.uri.queryParameters['meetingId'];
            return AdcomAgendaEditScreen(
              agendaId: id,
              returnToMeetingId: meetingId,
            );
          },
        ),
        GoRoute(
          path: '/admin/adcom-agenda/:id/view',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final meetingId = state.uri.queryParameters['meetingId'];
            return AdcomAgendaViewScreen(
              agendaId: id,
              returnToMeetingId: meetingId,
            );
          },
        ),
        GoRoute(
          path: '/admin/adcom-agenda/:id/print',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final meetingId = state.uri.queryParameters['meetingId'];
            return AdcomAgendaViewScreen(
              agendaId: id,
              isPrintMode: true,
              returnToMeetingId: meetingId,
            );
          },
        ),
        // ADCOM Minutes Routes
        GoRoute(
          path: '/admin/adcom-minutes/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final meetingId = state.uri.queryParameters['meetingId'];
            return AdcomMinutesEditScreen(
              minutesId: id,
              returnToMeetingId: meetingId,
            );
          },
        ),
        GoRoute(
          path: '/admin/adcom-minutes/:id/view',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final meetingId = state.uri.queryParameters['meetingId'];
            return AdcomMinutesViewScreen(
              minutesId: id,
              returnToMeetingId: meetingId,
            );
          },
        ),
        GoRoute(
          path: '/admin/adcom-minutes/:id/print',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final meetingId = state.uri.queryParameters['meetingId'];
            return AdcomMinutesViewScreen(
              minutesId: id,
              isPrintMode: true,
              returnToMeetingId: meetingId,
            );
          },
        ),
        // Meeting Template Routes
        GoRoute(
          path: '/admin/meeting-templates',
          builder: (context, state) => const MeetingTemplateListScreen(),
        ),
        GoRoute(
          path: '/admin/meeting-template/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return MeetingTemplateEditScreen(templateId: id);
          },
        ),
        GoRoute(
          path: '/survey/:id',
          builder: (context, state) =>
              SurveyFillScreen(surveyId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/admin/surveys',
          builder: (context, state) => const AdminSurveysScreen(),
        ),
        GoRoute(
          path: '/admin/surveys/:id/responses',
          builder: (context, state) => AdminSurveyResponsesScreen(
            surveyId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/admin/surveys/:id/edit',
          builder: (context, state) => AdminSurveyEditScreen(
            surveyId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
  }
}
