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
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

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
        ),
      ),
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
                        ? UserRole.values.firstWhere(
                            (e) => e.name == user.role.trim().toLowerCase(),
                            orElse: () => UserRole.requester,
                          ).displayName
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
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildQuickActions(context, authProvider),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildPettyCashReports(context, myReports),
            SizedBox(height: ResponsiveHelper.getSpacing(context)),
            _buildProjectReports(context),
            if (authProvider.canApprove()) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context)),
              _buildPendingApprovals(context, pendingApprovals),
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
                        authProvider.canApprove(),
                      ),
                      SizedBox(height: ResponsiveHelper.getSpacing(context)),
                      _buildQuickActions(context, authProvider),
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
              _buildPendingApprovals(context, pendingApprovals),
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
              _buildPendingApprovals(context, pendingApprovals),
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
      rows.add(stats.sublist(i,
        i + crossAxisCount > stats.length ? stats.length : i + crossAxisCount));
    }

    return Column(
      children: rows.map((row) =>
        Padding(
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
      ).toList(),
    );
  }

  Widget _buildModernStatCard(BuildContext context, _StatData stat) {
    final borderRadius = ResponsiveHelper.getBorderRadius(context);
    final elevation = ResponsiveHelper.getCardElevation(context);
    final textTheme = ResponsiveHelper.getResponsiveTextTheme(context);

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

  Widget _buildQuickActions(BuildContext context, AuthProvider authProvider) {
    final actions = [
      _ActionData(
        label: 'New Report',
        icon: Icons.add_circle_outline,
        gradient: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
        onPressed: () => context.go('/reports/new'),
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
    final textTheme = ResponsiveHelper.getResponsiveTextTheme(context);

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
    final user = authProvider.currentUser;

    final allProjectReports = projectReportProvider.projectReports;
    final myProjectReports = user != null
        ? allProjectReports.where((r) => r.custodianId == user.id).toList()
        : [];

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
                            '${AppConstants.currencySymbol}${report.totalExpenses.toStringAsFixed(2)}',
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
                    trailing: Text(
                      currencyFormat.format(totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
