import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/enums.dart';
import '../../models/traveling_report.dart';
import '../../models/income_report.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/edit_traveling_report_dialog.dart';

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final Color lightColor;

  _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.lightColor,
  });
}

class _ActionData {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onPressed;

  _ActionData({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReports();
      context.read<ProjectReportProvider>().loadProjectReports();
      context.read<TransactionProvider>().loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reportProvider = context.watch<ReportProvider>();
    final projectReportProvider = context.watch<ProjectReportProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final user = authProvider.currentUser;

    final allReports = reportProvider.reports;
    final allProjectReports = projectReportProvider.projectReports;
    final allTransactions = transactionProvider.transactions;

    final myReports = user != null
        ? allReports.where((r) => r.custodianId == user.id).toList()
        : [];
    final draftReports = allReports
        .where((r) => r.status == ReportStatus.draft.name)
        .toList();
    final pendingApprovals = transactionProvider.getPendingApprovals();

    // Calculate petty cash totals
    final pettyCashReceived = allReports.fold<double>(
      0.0,
      (sum, report) => sum + report.openingBalance,
    );
    final pettyCashUsed = allReports.fold<double>(
      0.0,
      (sum, report) => sum + report.totalDisbursements,
    );

    // Calculate project totals
    final projectBudgetTotal = allProjectReports.fold<double>(
      0.0,
      (sum, report) => sum + report.budget,
    );

    // Calculate actual project expenses from transactions
    final projectExpensesTotal = allProjectReports.fold<double>(0.0, (
      sum,
      report,
    ) {
      final reportTransactions = allTransactions.where(
        (t) =>
            t.projectId == report.id &&
            (t.statusEnum == TransactionStatus.approved ||
                t.statusEnum == TransactionStatus.processed),
      );
      final reportTotal = reportTransactions.fold<double>(
        0.0,
        (txSum, tx) => txSum + tx.amount,
      );
      return sum + reportTotal;
    });

    return StreamBuilder<List<IncomeReport>>(
      stream: FirestoreService().incomeReportsStream(),
      builder: (context, incomeSnapshot) {
        final incomeReports = incomeSnapshot.data ?? [];
        final totalIncomeAmount = incomeReports.fold<double>(
          0.0,
          (sum, r) => sum + r.totalIncome,
        );
        final pendingIncomeReports = incomeReports
            .where((r) => r.status == 'submitted')
            .length;

        return StreamBuilder<List<TravelingReport>>(
          stream: FirestoreService().travelingReportsStream(),
          builder: (context, travelingSnapshot) {
            final allTravelingReports = travelingSnapshot.data ?? [];
            // Filter pending reports, excluding admin's own reports
            final pendingTravelingReports = allTravelingReports
                .where(
                  (r) => r.status == 'submitted' && r.reporterId != user?.id,
                )
                .toList();

            final totalMileageKm = allTravelingReports.fold<double>(
              0.0,
              (sum, r) => sum + r.totalKM,
            );
            final totalMileageAmount = allTravelingReports.fold<double>(
              0.0,
              (sum, r) => sum + r.mileageAmount,
            );

            return Scaffold(
              backgroundColor: Colors.grey[50],
              appBar: _buildResponsiveAppBar(context, user),
              body: ResponsiveBuilder(
                mobile: _buildMobileLayout(
                  context,
                  allReports,
                  myReports,
                  draftReports,
                  pendingApprovals,
                  pettyCashReceived,
                  pettyCashUsed,
                  projectBudgetTotal,
                  projectExpensesTotal,
                  authProvider,
                  pendingTravelingReports,
                  allTravelingReports,
                  totalIncomeAmount,
                  incomeReports.length,
                  pendingIncomeReports,
                  totalMileageKm,
                  totalMileageAmount,
                ),
                tablet: _buildTabletLayout(
                  context,
                  allReports,
                  myReports,
                  draftReports,
                  pendingApprovals,
                  pettyCashReceived,
                  pettyCashUsed,
                  projectBudgetTotal,
                  projectExpensesTotal,
                  authProvider,
                  pendingTravelingReports,
                  allTravelingReports,
                  totalIncomeAmount,
                  incomeReports.length,
                  pendingIncomeReports,
                  totalMileageKm,
                  totalMileageAmount,
                ),
                desktop: _buildDesktopLayout(
                  context,
                  allReports,
                  myReports,
                  draftReports,
                  pendingApprovals,
                  pettyCashReceived,
                  pettyCashUsed,
                  projectBudgetTotal,
                  projectExpensesTotal,
                  authProvider,
                  pendingTravelingReports,
                  allTravelingReports,
                  totalIncomeAmount,
                  incomeReports.length,
                  pendingIncomeReports,
                  totalMileageKm,
                  totalMileageAmount,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIncomeMileageSummary(
    BuildContext context,
    double totalIncomeAmount,
    int incomeReportCount,
    int pendingIncomeReports,
    double totalMileageKm,
    double totalMileageAmount,
  ) {
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );
    final numberFormat = NumberFormat('#,##0');

    Widget buildTile({
      required String title,
      required String value,
      required String subtitle,
      required IconData icon,
      required List<Color> gradient,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.ssid_chart, color: Colors.green.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Income & Mileage',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;
            final tiles = [
              buildTile(
                title: 'Total Income',
                value: currencyFormat.format(totalIncomeAmount),
                subtitle: '$incomeReportCount reports recorded',
                icon: Icons.account_balance_wallet,
                gradient: [Colors.green.shade400, Colors.green.shade700],
              ),
              buildTile(
                title: 'Pending Income',
                value: numberFormat.format(pendingIncomeReports),
                subtitle: 'Awaiting approval',
                icon: Icons.pending_actions,
                gradient: [Colors.orange.shade400, Colors.orange.shade700],
              ),
              buildTile(
                title: 'Mileage (KM)',
                value: numberFormat.format(totalMileageKm.round()),
                subtitle: 'Total distance logged',
                icon: Icons.alt_route,
                gradient: [Colors.blue.shade400, Colors.blue.shade700],
              ),
              buildTile(
                title: 'Mileage Amount',
                value: currencyFormat.format(totalMileageAmount),
                subtitle: 'Calculated reimbursements',
                icon: Icons.directions_car_filled,
                gradient: [Colors.indigo.shade400, Colors.indigo.shade700],
              ),
            ];

            if (isMobile) {
              return Column(
                children: [
                  for (int i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    tiles[i],
                  ],
                ],
              );
            }

            return GridView.count(
              crossAxisCount: constraints.maxWidth > 1100 ? 4 : 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.0,
              physics: const NeverScrollableScrollPhysics(),
              children: tiles,
            );
          },
        ),
      ],
    );
  }

  AppBar _buildResponsiveAppBar(BuildContext context, dynamic user) {
    return AppBar(
      elevation: ResponsiveHelper.isDesktop(context) ? 1 : 0,
      title: Text(
        'Dashboard',
        style: ResponsiveHelper.getResponsiveTextTheme(context).titleLarge,
      ),
      actions: [
        if (!ResponsiveHelper.isMobile(context))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user?.name ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user != null
                        ? UserRole.values
                              .firstWhere(
                                (e) => e.name == user.role.trim().toLowerCase(),
                                orElse: () => UserRole.requester,
                              )
                              .displayName
                        : '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
          tooltip: 'Settings',
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await context.read<AuthProvider>().logout();
          },
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List allReports,
    List myReports,
    List draftReports,
    List pendingApprovals,
    double pettyCashReceived,
    double pettyCashUsed,
    double projectBudgetTotal,
    double projectExpensesTotal,
    dynamic authProvider,
    List<TravelingReport> pendingTravelingReports,
    List<TravelingReport> allTravelingReports,
    double totalIncomeAmount,
    int incomeReportCount,
    int pendingIncomeReports,
    double totalMileageKm,
    double totalMileageAmount,
  ) {
    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(context, authProvider.currentUser?.name ?? ''),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildStatCards(
              context,
              allReports.length,
              myReports.length,
              draftReports.length,
              pendingApprovals.length,
              pendingTravelingReports.length,
              authProvider.canApprove(),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildFinancialSummary(
              context,
              pettyCashReceived,
              pettyCashUsed,
              projectBudgetTotal,
              projectExpensesTotal,
            ),
            if (authProvider.canManageUsers()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildIncomeMileageSummary(
                context,
                totalIncomeAmount,
                incomeReportCount,
                pendingIncomeReports,
                totalMileageKm,
                totalMileageAmount,
              ),
            ],
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildQuickActions(context, authProvider),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildPettyCashReports(context, myReports),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildProjectReports(context),
            if (authProvider.canApprove()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildMileageSummary(context, allTravelingReports),
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildPendingApprovals(context, pendingApprovals),
              if (pendingTravelingReports.isNotEmpty) ...[
                SizedBox(height: ResponsiveHelper.getSpacing(context)),
                _buildPendingTravelingReports(context, pendingTravelingReports),
              ],
            ],
            if (authProvider.canManageUsers()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildStudentReports(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    List allReports,
    List myReports,
    List draftReports,
    List pendingApprovals,
    double pettyCashReceived,
    double pettyCashUsed,
    double projectBudgetTotal,
    double projectExpensesTotal,
    dynamic authProvider,
    List<TravelingReport> pendingTravelingReports,
    List<TravelingReport> allTravelingReports,
    double totalIncomeAmount,
    int incomeReportCount,
    int pendingIncomeReports,
    double totalMileageKm,
    double totalMileageAmount,
  ) {
    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(context, authProvider.currentUser?.name ?? ''),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildStatCards(
                        context,
                        allReports.length,
                        myReports.length,
                        draftReports.length,
                        pendingApprovals.length,
                        pendingTravelingReports.length,
                        authProvider.canApprove(),
                      ),
                      SizedBox(height: ResponsiveHelper.getSpacing(context)),
                      _buildQuickActions(context, authProvider),
                      if (authProvider.canManageUsers()) ...[
                        SizedBox(height: ResponsiveHelper.getSpacing(context)),
                        _buildIncomeMileageSummary(
                          context,
                          totalIncomeAmount,
                          incomeReportCount,
                          pendingIncomeReports,
                          totalMileageKm,
                          totalMileageAmount,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: _buildFinancialSummary(
                    context,
                    pettyCashReceived,
                    pettyCashUsed,
                    projectBudgetTotal,
                    projectExpensesTotal,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildPettyCashReports(context, myReports),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildProjectReports(context),
            if (authProvider.canApprove()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildMileageSummary(context, allTravelingReports),
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildPendingApprovals(context, pendingApprovals),
              if (pendingTravelingReports.isNotEmpty) ...[
                SizedBox(height: ResponsiveHelper.getSpacing(context)),
                _buildPendingTravelingReports(context, pendingTravelingReports),
              ],
            ],
            if (authProvider.canManageUsers()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildStudentReports(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List allReports,
    List myReports,
    List draftReports,
    List pendingApprovals,
    double pettyCashReceived,
    double pettyCashUsed,
    double projectBudgetTotal,
    double projectExpensesTotal,
    dynamic authProvider,
    List<TravelingReport> pendingTravelingReports,
    List<TravelingReport> allTravelingReports,
    double totalIncomeAmount,
    int incomeReportCount,
    int pendingIncomeReports,
    double totalMileageKm,
    double totalMileageAmount,
  ) {
    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(context, authProvider.currentUser?.name ?? ''),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            // Top section with stats and financial summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildStatCards(
                    context,
                    allReports.length,
                    myReports.length,
                    draftReports.length,
                    pendingApprovals.length,
                    pendingTravelingReports.length,
                    authProvider.canApprove(),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: _buildFinancialSummary(
                    context,
                    pettyCashReceived,
                    pettyCashUsed,
                    projectBudgetTotal,
                    projectExpensesTotal,
                  ),
                ),
              ],
            ),
            if (authProvider.canManageUsers()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildIncomeMileageSummary(
                context,
                totalIncomeAmount,
                incomeReportCount,
                pendingIncomeReports,
                totalMileageKm,
                totalMileageAmount,
              ),
            ],
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildQuickActions(context, authProvider),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            // Bottom section with reports in columns
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPettyCashReports(context, myReports)),
                const SizedBox(width: 24),
                Expanded(child: _buildProjectReports(context)),
              ],
            ),
            if (authProvider.canApprove()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildMileageSummary(context, allTravelingReports),
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildPendingApprovals(context, pendingApprovals),
              if (pendingTravelingReports.isNotEmpty) ...[
                SizedBox(height: ResponsiveHelper.getSpacing(context)),
                _buildPendingTravelingReports(context, pendingTravelingReports),
              ],
            ],
            if (authProvider.canManageUsers()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildStudentReports(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, String userName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s your financial overview',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.dashboard, size: 48, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(
    BuildContext context,
    int totalReports,
    int myReports,
    int draftReports,
    int pendingApprovals,
    int pendingTravelingReports,
    bool canApprove,
  ) {
    final stats = [
      _StatData(
        title: 'Total Reports',
        value: totalReports.toString(),
        icon: Icons.description,
        gradient: [Colors.blue.shade400, Colors.blue.shade600],
        lightColor: Colors.blue.shade50,
      ),
      _StatData(
        title: 'My Reports',
        value: myReports.toString(),
        icon: Icons.person,
        gradient: [Colors.green.shade400, Colors.green.shade600],
        lightColor: Colors.green.shade50,
      ),
      _StatData(
        title: 'Draft Reports',
        value: draftReports.toString(),
        icon: Icons.edit_document,
        gradient: [Colors.orange.shade400, Colors.orange.shade600],
        lightColor: Colors.orange.shade50,
      ),
      if (canApprove)
        _StatData(
          title: 'Pending Approvals',
          value: pendingApprovals.toString(),
          icon: Icons.pending_actions,
          gradient: [Colors.red.shade400, Colors.red.shade600],
          lightColor: Colors.red.shade50,
        ),
      if (canApprove && pendingTravelingReports > 0)
        _StatData(
          title: 'Traveling Reports',
          value: pendingTravelingReports.toString(),
          icon: Icons.flight_takeoff,
          gradient: [Colors.purple.shade400, Colors.purple.shade600],
          lightColor: Colors.purple.shade50,
        ),
    ];

    // Custom responsive grid implementation to avoid overflow issues within SingleChildScrollView
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(
      context,
      maxColumns: ResponsiveHelper.isMobile(context) ? 2 : 4,
      minItemWidth: 200,
    );

    // Split the stats into rows based on the calculated cross axis count
    final rows = <List<_StatData>>[];
    for (int i = 0; i < stats.length; i += crossAxisCount) {
      rows.add(
        stats.sublist(
          i,
          i + crossAxisCount > stats.length ? stats.length : i + crossAxisCount,
        ),
      );
    }

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveHelper.getSpacing(
                  context,
                  mobile: 12,
                  tablet: 16,
                  desktop: 16,
                ),
              ),
              child: Row(
                children: row.asMap().entries.map((entry) {
                  int index = entry.key;
                  _StatData stat = entry.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < row.length - 1
                            ? ResponsiveHelper.getSpacing(
                                context,
                                mobile: 12,
                                tablet: 16,
                                desktop: 16,
                              )
                            : 0,
                      ),
                      child: _buildModernStatCard(context, stat),
                    ),
                  );
                }).toList(),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildModernStatCard(BuildContext context, _StatData stat) {
    final borderRadius = ResponsiveHelper.getBorderRadius(context);
    final elevation = ResponsiveHelper.getCardElevation(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: ResponsiveHelper.isMobile(context) ? -15 : -20,
            top: ResponsiveHelper.isMobile(context) ? -15 : -20,
            child: Container(
              width: ResponsiveHelper.isMobile(context) ? 80 : 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: stat.gradient.map((c) => c.withOpacity(0.1)).toList(),
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: stat.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(stat.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stat.value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: stat.gradient[1],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(
    BuildContext context,
    double pettyCashReceived,
    double pettyCashUsed,
    double projectBudget,
    double projectExpenses,
  ) {
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: Colors.purple.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Financial Summary',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            if (isMobile) {
              return Column(
                children: [
                  _buildFinancialCard(
                    'Petty Cash',
                    Icons.account_balance_wallet,
                    [Colors.blue.shade400, Colors.blue.shade600],
                    currencyFormat.format(pettyCashReceived),
                    currencyFormat.format(pettyCashUsed),
                    pettyCashReceived - pettyCashUsed,
                    currencyFormat,
                  ),
                  const SizedBox(height: 16),
                  _buildFinancialCard(
                    'Projects',
                    Icons.business_center,
                    [Colors.green.shade400, Colors.green.shade600],
                    currencyFormat.format(projectBudget),
                    currencyFormat.format(projectExpenses),
                    projectBudget - projectExpenses,
                    currencyFormat,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _buildFinancialCard(
                    'Petty Cash',
                    Icons.account_balance_wallet,
                    [Colors.blue.shade400, Colors.blue.shade600],
                    currencyFormat.format(pettyCashReceived),
                    currencyFormat.format(pettyCashUsed),
                    pettyCashReceived - pettyCashUsed,
                    currencyFormat,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialCard(
                    'Projects',
                    Icons.business_center,
                    [Colors.green.shade400, Colors.green.shade600],
                    currencyFormat.format(projectBudget),
                    currencyFormat.format(projectExpenses),
                    projectBudget - projectExpenses,
                    currencyFormat,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFinancialCard(
    String title,
    IconData icon,
    List<Color> gradient,
    String received,
    String used,
    double balance,
    NumberFormat currencyFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFinancialRow(
            'Received',
            received,
            Icons.arrow_downward,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildFinancialRow('Used', used, Icons.arrow_upward, Colors.red),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                currencyFormat.format(balance),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: balance >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    String amount,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        Text(
          amount,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _showReportSelectionDialog(BuildContext context) {
    final reportProvider = context.read<ReportProvider>();
    final projectReportProvider = context.read<ProjectReportProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade400, Colors.pink.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_card, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Add Transaction'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a report to add the transaction to:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Petty Cash Reports
                if (reportProvider.reports.isNotEmpty) ...[
                  Text(
                    'Petty Cash Reports',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...reportProvider.reports.map((report) {
                    final statusColor = report.status == 'approved'
                        ? Colors.green
                        : report.status == 'pending'
                        ? Colors.orange
                        : Colors.grey;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.blue.shade600,
                      ),
                      title: Text(
                        report.reportNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${report.custodianName} - ${DateFormat('MMM dd, yyyy').format(report.periodStart)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          report.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        context.push(
                          '/reports/${report.id}',
                          extra: {'action': 'addTransaction'},
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                // Project Reports
                if (projectReportProvider.projectReports.isNotEmpty) ...[
                  Text(
                    'Project Reports',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...projectReportProvider.projectReports.map((report) {
                    final statusColor = report.status == 'active'
                        ? Colors.green
                        : report.status == 'completed'
                        ? Colors.blue
                        : Colors.grey;

                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.work, color: Colors.purple.shade600),
                      title: Text(
                        report.projectName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${report.reportNumber} - Budget: ${NumberFormat.currency(symbol: '฿').format(report.budget)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          report.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        context.push(
                          '/project-reports/${report.id}',
                          extra: {'action': 'addTransaction'},
                        );
                      },
                    );
                  }),
                ],
                if (reportProvider.reports.isEmpty &&
                    projectReportProvider.projectReports.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reports available',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              context.go('/reports/new');
                            },
                            child: const Text('Create a report first'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AuthProvider authProvider) {
    final actions = [
      _ActionData(
        label: 'New Report',
        icon: Icons.add_circle_outline,
        gradient: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        onPressed: () => context.go('/reports/new'),
      ),
      _ActionData(
        label: 'Add Transaction',
        icon: Icons.add_card,
        gradient: [Colors.pink.shade400, Colors.pink.shade600],
        onPressed: () => _showReportSelectionDialog(context),
      ),
      _ActionData(
        label: 'View Reports',
        icon: Icons.list_alt,
        gradient: [Colors.blue.shade400, Colors.blue.shade600],
        onPressed: () => context.go('/reports'),
      ),
      _ActionData(
        label: 'Transactions',
        icon: Icons.receipt_long,
        gradient: [Colors.teal.shade400, Colors.teal.shade600],
        onPressed: () => context.go('/transactions'),
      ),
      _ActionData(
        label: 'Traveling Reports',
        icon: Icons.flight_takeoff,
        gradient: [Colors.indigo.shade400, Colors.indigo.shade600],
        onPressed: () => context.go('/traveling-reports'),
      ),
      if (authProvider.canManageUsers())
        _ActionData(
          label: 'Income Reports',
          icon: Icons.account_balance_wallet_outlined,
          gradient: [Colors.green.shade400, Colors.green.shade600],
          onPressed: () => context.go('/admin/income'),
        ),
      if (authProvider.canApprove())
        _ActionData(
          label: 'Approvals',
          icon: Icons.check_circle_outline,
          gradient: [Colors.green.shade400, Colors.green.shade600],
          onPressed: () => context.go('/approvals'),
        ),
      if (authProvider.canManageUsers())
        _ActionData(
          label: 'Manage Users',
          icon: Icons.people_outline,
          gradient: [Colors.orange.shade400, Colors.orange.shade600],
          onPressed: () => context.go('/admin'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.amber.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Quick Actions',
              style: ResponsiveHelper.getResponsiveTextTheme(
                context,
              ).titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(
          height: ResponsiveHelper.getSpacing(
            context,
            mobile: 12,
            tablet: 16,
            desktop: 16,
          ),
        ),
        ResponsiveWrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map(
                (action) => ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: ResponsiveHelper.isMobile(context) ? 150 : 180,
                    maxWidth: ResponsiveHelper.isMobile(context) ? 200 : 250,
                  ),
                  child: _buildActionCard(context, action),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, _ActionData action) {
    final borderRadius = ResponsiveHelper.getBorderRadius(context);

    return InkWell(
      onTap: action.onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: action.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: action.gradient[1].withOpacity(0.3),
              blurRadius: ResponsiveHelper.getCardElevation(context) * 2,
              offset: Offset(0, ResponsiveHelper.getCardElevation(context)),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              color: Colors.white,
              size: ResponsiveHelper.isMobile(context) ? 28 : 32,
            ),
            SizedBox(height: ResponsiveHelper.isMobile(context) ? 6 : 8),
            Text(
              action.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveHelper.isMobile(context) ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPettyCashReports(BuildContext context, List reports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Petty Cash Reports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/reports'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (reports.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No petty cash reports yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first report to get started!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        if (reports.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reports.length > 5 ? 5 : reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(report.statusEnum),
                    child: const Icon(Icons.description, color: Colors.white),
                  ),
                  title: Text(report.reportNumber),
                  subtitle: Text(
                    '${report.department} • ${report.statusEnum.displayName}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${AppConstants.currencySymbol}${report.totalDisbursements.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (String choice) {
                          if (choice == 'edit') {
                            context.go('/reports/${report.id}');
                          } else if (choice == 'delete') {
                            _showDeleteConfirmation(context, report, true);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => context.go('/reports/${report.id}'),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildProjectReports(BuildContext context) {
    final projectReportProvider = context.watch<ProjectReportProvider>();
    final authProvider = context.watch<AuthProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final user = authProvider.currentUser;

    final allProjectReports = projectReportProvider.projectReports;
    final allTransactions = transactionProvider.transactions;
    final myProjectReports = user != null
        ? allProjectReports.where((r) => r.custodianId == user.id).toList()
        : [];

    // Helper function to calculate actual expenses from transactions
    double getProjectExpenses(String projectId) {
      return allTransactions
          .where(
            (t) =>
                t.projectId == projectId &&
                (t.statusEnum == TransactionStatus.approved ||
                    t.statusEnum == TransactionStatus.processed),
          )
          .fold<double>(0.0, (sum, t) => sum + t.amount);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.green.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.business_center,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Project Reports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/reports'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (myProjectReports.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No project reports yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first project to get started!',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        if (myProjectReports.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: myProjectReports.length > 5
                ? 5
                : myProjectReports.length,
            itemBuilder: (context, index) {
              final report = myProjectReports[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(report.statusEnum),
                    child: const Icon(Icons.folder, color: Colors.white),
                  ),
                  title: Text(report.reportNumber),
                  subtitle: Text(
                    '${report.projectName} • ${report.statusEnum.displayName}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${AppConstants.currencySymbol}${getProjectExpenses(report.id).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'of ${AppConstants.currencySymbol}${report.budget.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (String choice) {
                          if (choice == 'edit') {
                            context.go('/project-reports/${report.id}');
                          } else if (choice == 'delete') {
                            _showDeleteConfirmation(context, report, false);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => context.go('/project-reports/${report.id}'),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPendingApprovals(BuildContext context, List transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Approvals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.go('/approvals'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No pending approvals')),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length > 5 ? 5 : transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.pending, color: Colors.white),
                  ),
                  title: Text(transaction.description),
                  subtitle: Text(
                    '${transaction.category.expenseCategoryDisplayName} • ${transaction.receiptNo}',
                  ),
                  trailing: Text(
                    '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () => context.go('/approvals'),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMileageSummary(
    BuildContext context,
    List<TravelingReport> reports,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MMM dd, yyyy');

    // Use all reports (show all traveling reports)
    final reportsWithMileage = List<TravelingReport>.from(reports);

    // Calculate totals from all reports
    final totalKM = reportsWithMileage.fold<double>(
      0.0,
      (total, report) => total + report.totalKM,
    );
    final totalMileageAmount = reportsWithMileage.fold<double>(
      0.0,
      (total, report) => total + report.mileageAmount,
    );

    // Sort by date (newest first)
    reportsWithMileage.sort((a, b) => b.reportDate.compareTo(a.reportDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with gradient
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade50, Colors.teal.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.speed,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mileage Summary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin/traveling-reports'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Summary cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.route,
                          color: Colors.teal.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Distance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currencyFormat.format(totalKM)} KM',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payments,
                          color: Colors.teal.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Mileage Cost',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppConstants.currencySymbol}${currencyFormat.format(totalMileageAmount)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: Colors.teal.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Reports',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${reportsWithMileage.length}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Recent mileage reports list
        if (reportsWithMileage.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.speed, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No traveling reports found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a traveling report to see mileage data here',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        if (reportsWithMileage.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reportsWithMileage.length > 5
                ? 5
                : reportsWithMileage.length,
            itemBuilder: (context, index) {
              final report = reportsWithMileage[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    report.reportNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.reporterName} • ${dateFormat.format(report.reportDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${report.totalKM.toStringAsFixed(1)} KM',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.placeName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${AppConstants.currencySymbol}${currencyFormat.format(report.mileageAmount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      Text(
                        '@5/KM',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  onTap: () =>
                      context.push('/admin/traveling-reports/${report.id}'),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPendingTravelingReports(
    BuildContext context,
    List<TravelingReport> reports,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.purple.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pending Traveling Reports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin/traveling-reports'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (reports.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending traveling reports',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (reports.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reports.length > 5 ? 5 : reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    report.reportNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.reporterName} • ${dateFormat.format(report.reportDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.purpose,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '฿${currencyFormat.format(report.grandTotal)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            report.placeName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (String choice) {
                          if (choice == 'view') {
                            context.push(
                              '/admin/traveling-reports/${report.id}',
                            );
                          } else if (choice == 'edit') {
                            _editTravelingReport(context, report);
                          } else if (choice == 'changeStatus') {
                            _changeTravelingReportStatus(context, report);
                          } else if (choice == 'approve') {
                            _approveTravelingReport(context, report);
                          } else if (choice == 'reject') {
                            _rejectTravelingReport(context, report);
                          } else if (choice == 'delete') {
                            _deleteTravelingReport(context, report);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 20),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Edit Report',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'changeStatus',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  size: 20,
                                  color: Colors.purple,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Change Status',
                                  style: TextStyle(color: Colors.purple),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'approve',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Approve',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'reject',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cancel,
                                  size: 20,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Reject',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () =>
                      context.push('/admin/traveling-reports/${report.id}'),
                ),
              );
            },
          ),
      ],
    );
  }

  void _approveTravelingReport(BuildContext context, TravelingReport report) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Traveling Report'),
        content: Text(
          'Are you sure you want to approve report ${report.reportNumber} from ${report.reporterName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirestoreService().approveTravelingReport(
                  report.id,
                  user.name,
                );
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report approved successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error approving report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectTravelingReport(BuildContext context, TravelingReport report) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    final reasonController = TextEditingController();

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Traveling Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject report ${report.reportNumber} from ${report.reporterName}?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
                hintText: 'Please provide a reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await FirestoreService().rejectTravelingReport(
                  report.id,
                  reasonController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report rejected'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error rejecting report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _deleteTravelingReport(BuildContext context, TravelingReport report) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Traveling Report'),
        content: Text(
          'Are you sure you want to delete report ${report.reportNumber} from ${report.reporterName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirestoreService().deleteTravelingReport(report.id);

                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Traveling report deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTravelingReport(
    BuildContext context,
    TravelingReport report,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditTravelingReportDialog(
        report: report,
        reporterId: report.reporterId,
        reporterName: report.reporterName,
      ),
    );

    if (result != null && context.mounted) {
      try {
        final updatedReport = report.copyWith(
          department: result['department'] as String,
          reportDate: result['reportDate'] as DateTime,
          purpose: result['purpose'] as String,
          placeName: result['placeName'] as String,
          departureTime: result['departureTime'] as DateTime,
          destinationTime: result['destinationTime'] as DateTime,
          totalMembers: result['totalMembers'] as int,
          travelLocation: result['travelLocation'] as String,
          mileageStart: result['mileageStart'] as double,
          mileageEnd: result['mileageEnd'] as double,
          notes: result['notes'] as String,
        );

        await FirestoreService().saveTravelingReport(updatedReport);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Traveling report updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _changeTravelingReportStatus(
    BuildContext context,
    TravelingReport report,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    String? selectedStatus = report.status;
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Report Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report: ${report.reportNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('DRAFT')),
                  DropdownMenuItem(
                    value: 'submitted',
                    child: Text('SUBMITTED'),
                  ),
                  DropdownMenuItem(value: 'approved', child: Text('APPROVED')),
                  DropdownMenuItem(value: 'rejected', child: Text('REJECTED')),
                  DropdownMenuItem(value: 'closed', child: Text('CLOSED')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value;
                  });
                },
              ),
              if (selectedStatus == 'rejected') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason',
                    border: OutlineInputBorder(),
                    hintText: 'Required for rejected status...',
                  ),
                  maxLines: 3,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedStatus == 'rejected' &&
                    reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a rejection reason'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedStatus != null && context.mounted) {
      try {
        final updates = <String, dynamic>{'status': selectedStatus};

        if (selectedStatus == 'approved') {
          updates['approvedAt'] = FieldValue.serverTimestamp();
          updates['approvedBy'] = user.name;
          updates['rejectionReason'] = null;
        } else if (selectedStatus == 'rejected') {
          updates['rejectedAt'] = FieldValue.serverTimestamp();
          updates['rejectedBy'] = user.name;
          updates['rejectionReason'] = reasonController.text.trim();
          updates['approvedAt'] = null;
          updates['approvedBy'] = null;
        } else if (selectedStatus == 'submitted') {
          updates['submittedAt'] = FieldValue.serverTimestamp();
          updates['submittedBy'] = user.name;
        }

        await FirebaseFirestore.instance
            .collection('traveling_reports')
            .doc(report.id)
            .update(updates);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Status updated to ${selectedStatus!.toUpperCase()}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _approveStudentReport(
    BuildContext context,
    String reportId,
    String studentName,
    String monthDisplay,
  ) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Student Report'),
        content: Text('Approve report for $studentName ($monthDisplay)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('student_monthly_reports')
                    .doc(reportId)
                    .update({
                      'status': 'approved',
                      'approvedAt': FieldValue.serverTimestamp(),
                      'approvedBy': user.name,
                    });

                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student report approved successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error approving report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectStudentReport(
    BuildContext context,
    String reportId,
    String studentName,
    String monthDisplay,
  ) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    final reasonController = TextEditingController();

    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Student Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject report for $studentName ($monthDisplay)?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
                hintText: 'Please provide a reason...',
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('student_monthly_reports')
                    .doc(reportId)
                    .update({
                      'status': 'rejected',
                      'rejectedAt': FieldValue.serverTimestamp(),
                      'rejectedBy': user.name,
                      'rejectionReason': reasonController.text.trim(),
                    });

                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student report rejected'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error rejecting report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _deleteStudentReport(
    BuildContext context,
    String reportId,
    String studentName,
    String monthDisplay,
  ) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student Report'),
        content: Text(
          'Are you sure you want to delete the report for $studentName ($monthDisplay)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('student_monthly_reports')
                    .doc(reportId)
                    .delete();

                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student report deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Colors.grey;
      case ReportStatus.submitted:
        return Colors.blue;
      case ReportStatus.underReview:
        return Colors.orange;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.closed:
        return Colors.purple;
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    dynamic report,
    bool isPettyCash,
  ) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete report ${report.reportNumber}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                if (isPettyCash) {
                  await context.read<ReportProvider>().deleteReport(report.id);
                } else {
                  await context
                      .read<ProjectReportProvider>()
                      .deleteProjectReport(report.id);
                }
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentReports(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .orderBy('month', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final reports = snapshot.data!.docs;

        if (reports.isEmpty) {
          return const SizedBox.shrink();
        }

        final currencyFormat = NumberFormat.currency(
          symbol: '${AppConstants.currencySymbol} ',
        );
        final dateFormat = DateFormat('MMMM yyyy');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assignment,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Student Reports',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/admin/student-reports'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View All'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final reportDoc = reports[index];
                final reportData = reportDoc.data() as Map<String, dynamic>;
                final studentName = reportData['studentName'] ?? 'Unknown';
                final month = reportData['month'] ?? '';
                final status = reportData['status'] ?? 'draft';
                final totalHours = (reportData['totalHours'] ?? 0.0).toDouble();
                final totalAmount = (reportData['totalAmount'] ?? 0.0)
                    .toDouble();

                // Format month display (YYYY-MM to Month Year)
                String monthDisplay = month;
                try {
                  final parts = month.split('-');
                  if (parts.length == 2) {
                    final monthDate = DateTime(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                    );
                    monthDisplay = dateFormat.format(monthDate);
                  }
                } catch (e) {
                  // Keep original month string if parsing fails
                }

                Color statusColor;
                switch (status) {
                  case 'approved':
                    statusColor = Colors.green;
                    break;
                  case 'rejected':
                    statusColor = Colors.red;
                    break;
                  case 'submitted':
                    statusColor = Colors.orange;
                    break;
                  default:
                    statusColor = Colors.grey;
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor,
                      child: Text(
                        studentName.isNotEmpty
                            ? studentName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(studentName),
                    subtitle: Text(
                      '$monthDisplay • ${status.toUpperCase()} • ${totalHours.toStringAsFixed(1)}h',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currencyFormat.format(totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (String choice) {
                            if (choice == 'view') {
                              context.push(
                                '/admin/student-reports/${reportDoc.id}?month=$month&monthDisplay=${Uri.encodeComponent(monthDisplay)}',
                              );
                            } else if (choice == 'approve') {
                              _approveStudentReport(
                                context,
                                reportDoc.id,
                                studentName,
                                monthDisplay,
                              );
                            } else if (choice == 'reject') {
                              _rejectStudentReport(
                                context,
                                reportDoc.id,
                                studentName,
                                monthDisplay,
                              );
                            } else if (choice == 'delete') {
                              _deleteStudentReport(
                                context,
                                reportDoc.id,
                                studentName,
                                monthDisplay,
                              );
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility, size: 20),
                                  SizedBox(width: 8),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                            if (status == 'submitted')
                              const PopupMenuItem<String>(
                                value: 'approve',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Approve',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                            if (status == 'submitted')
                              const PopupMenuItem<String>(
                                value: 'reject',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      size: 20,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Reject',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ],
                                ),
                              ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => context.push(
                      '/admin/student-reports/${reportDoc.id}?month=$month&monthDisplay=${Uri.encodeComponent(monthDisplay)}',
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
