import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
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
import 'screens/student/student_monthly_report_detail_screen.dart';
import 'screens/student/new_student_report_screen.dart';
import 'screens/traveling/traveling_reports_screen.dart';
import 'screens/traveling/traveling_report_detail_screen.dart';
import 'screens/admin/admin_traveling_reports_screen.dart';
import 'screens/admin/admin_traveling_report_detail_screen.dart';
import 'screens/admin/admin_income_reports_screen.dart';
import 'screens/hr/employee_onboarding_screen.dart';
import 'screens/hr/hr_data_submission_screen.dart';
import 'screens/hr/hr_management_screen.dart';
import 'screens/hr/my_hr_data_screen.dart';
import 'screens/hr/hr_data_submissions_screen.dart';
import 'screens/hr/annual_leave_request_screen.dart';
import 'screens/hr/annual_leave_requests_screen.dart';
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
import 'screens/meetings/new_meeting_screen.dart';
import 'screens/meetings/edit_meeting_screen.dart';
import 'screens/meetings/meeting_detail_screen.dart';
import 'screens/meetings/action_items_screen.dart';
import 'screens/meetings/edit_agenda_screen.dart';
import 'screens/meetings/edit_minutes_screen.dart';
import 'screens/hub/admin_hub_screen.dart';
import 'screens/hub/finance_dashboard_screen.dart';
import 'screens/hub/finance_ai_report_screen.dart';
import 'screens/hub/student_labor_dashboard_screen.dart';
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
import 'screens/hub/media_dashboard_screen.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          return MaterialApp.router(
            title: AppConstants.appName,
            theme: ResponsiveTheme.getTheme(context),
            darkTheme: ResponsiveTheme.getTheme(context),
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
    return GoRouter(
      refreshListenable: authProvider,
      redirect: (context, state) async {
        final isLoggingIn = state.matchedLocation == '/';
        final isRegistering = state.matchedLocation == '/student-register';
        final isOnboarding = state.matchedLocation.startsWith(
          '/student-onboarding',
        );
        final isGoingToStudentDashboard =
            state.matchedLocation == '/student-dashboard';
        final user = authProvider.currentUser;

        // Allow unauthenticated access to login, register, and onboarding
        if (!authProvider.isAuthenticated &&
            !isLoggingIn &&
            !isRegistering &&
            !isOnboarding) {
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
        if (user?.role == 'studentWorker' && isGoingToStudentDashboard) {
          return null;
        }

        // Student workers can only access student routes
        if (user?.role == 'studentWorker') {
          final studentRoutes = [
            '/student-dashboard',
            '/student-report',
            '/student-report/new',
            '/student-monthly-report-detail',
            '/student-onboarding',
            '/settings',
          ];
          if (!studentRoutes.any(
            (route) => state.matchedLocation.startsWith(route),
          )) {
            return '/student-dashboard';
          }
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
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
            return NewReportScreen(
              reportType: 'advance_settlement',
              cashAdvanceId: cashAdvanceId,
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
          path: '/student-onboarding',
          builder: (context, state) {
            // Try to get data from query parameters first (from registration)
            final queryUserId = state.uri.queryParameters['userId'];
            final queryUserName = state.uri.queryParameters['userName'];
            final queryUserEmail = state.uri.queryParameters['userEmail'];

            // Fallback to authProvider if query params not available
            final user = authProvider.currentUser;

            // Use query params if available, otherwise use current user
            final userId = queryUserId ?? user?.id;
            final userName = queryUserName ?? user?.name;
            final userEmail = queryUserEmail ?? user?.email;

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
            );
          },
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
            final initialViewMode =
                view == 'table' ? CashAdvancesViewMode.table : null;
            return CashAdvancesScreen(initialViewMode: initialViewMode);
          },
        ),
        GoRoute(
          path: '/cash-advances/new',
          builder: (context, state) => const NewCashAdvanceScreen(),
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
      ],
    );
  }
}
