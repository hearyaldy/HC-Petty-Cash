import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import 'screens/admin/payment_rate_screen.dart';
import 'screens/admin/admin_student_reports_screen.dart';
import 'screens/admin/admin_student_report_detail_screen.dart';
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
import 'utils/constants.dart';
import 'utils/logger.dart';
import 'utils/responsive_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  AppLogger.init();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable offline persistence for Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    AppLogger.severe('Firebase initialization error: $e');
    // Continue anyway for demo purposes
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => ProjectReportProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
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
        final isOnboarding = state.matchedLocation.startsWith('/student-onboarding');
        final isGoingToStudentDashboard = state.matchedLocation == '/student-dashboard';
        final user = authProvider.currentUser;

        // Allow unauthenticated access to login, register, and onboarding
        if (!authProvider.isAuthenticated && !isLoggingIn && !isRegistering && !isOnboarding) {
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
          return '/dashboard';
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
          builder: (context, state) => const ReportsListScreen(),
        ),
        GoRoute(
          path: '/reports/new',
          builder: (context, state) => const ChooseReportTypeScreen(),
        ),
        GoRoute(
          path: '/reports/new/petty-cash',
          builder: (context, state) => const NewReportScreen(),
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
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreenImpl(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/admin/payment-rates',
          builder: (context, state) => const PaymentRateScreen(),
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
          path: '/admin/traveling-reports/:reportId',
          builder: (context, state) {
            final reportId = state.pathParameters['reportId']!;
            return AdminTravelingReportDetailScreen(reportId: reportId);
          },
        ),
      ],
    );
  }
}
