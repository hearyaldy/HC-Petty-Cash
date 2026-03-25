import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/constants.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  int _pendingReports = 0;
  int _pendingTransactions = 0;
  int _pendingTravelReports = 0;
  int _pendingIncomeReports = 0;

  // Financial statistics
  double _totalPettyCashReceived = 0;
  double _totalPettyCashUsed = 0;
  double _totalAdvanceReceived = 0;
  double _totalAdvanceUsed = 0;
  double _totalProjectBudget = 0;
  double _totalProjectExpenses = 0;
  double _totalIncomeAmount = 0;
  double _totalMileageAmount = 0;
  int _totalIncomeReports = 0;

  // AI report state
  final Set<_AiReportScope> _aiReportScopes = {
    _AiReportScope.transactions,
    _AiReportScope.pettyCashReports,
  };
  _AiReportRange _aiReportRange = _AiReportRange.month;
  _AiReportPreset _aiReportPreset = _AiReportPreset.thisMonth;
  DateTime? _aiCustomStart;
  DateTime? _aiCustomEnd;
  bool _aiReportLoading = false;
  String? _aiReportError;
  List<_TrendPoint> _aiTrendPoints = [];
  Map<String, double> _aiCategoryTotals = {};
  _CashFlowSummary _aiCashFlow = const _CashFlowSummary(0, 0, 0);
  String _aiSummaryText = 'Select filters and generate a report.';

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _applyPreset(_aiReportPreset);
  }

  Future<void> _loadCounts() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Pending counts
      final reportsQuery = await firestore
          .collection('reports')
          .where('status', isEqualTo: 'submitted')
          .get();

      final transactionsQuery = await firestore
          .collection('transactions')
          .where('status', isEqualTo: 'submitted')
          .get();

      final travelQuery = await firestore
          .collection('traveling_reports')
          .where('status', isEqualTo: 'submitted')
          .get();

      final incomeQuery = await firestore
          .collection('income_reports')
          .where('status', isEqualTo: 'submitted')
          .get();

      // Load all reports for financial summaries
      final allReportsQuery = await firestore.collection('reports').get();
      final allProjectReportsQuery = await firestore
          .collection('project_reports')
          .get();
      final allIncomeReportsQuery = await firestore
          .collection('income_reports')
          .get();
      final allTravelingQuery = await firestore
          .collection('traveling_reports')
          .get();

      // Calculate petty cash totals
      double pettyCashReceived = 0;
      double pettyCashUsed = 0;
      double advanceReceived = 0;
      double advanceUsed = 0;
      for (var doc in allReportsQuery.docs) {
        final data = doc.data();
        final reportType = (data['reportType'] as String?) ?? 'petty_cash';
        final openingBalance = (data['openingBalance'] ?? 0).toDouble();
        final totalDisbursements = (data['totalDisbursements'] ?? 0).toDouble();

        if (reportType == 'advance_settlement') {
          advanceReceived += openingBalance;
          advanceUsed += totalDisbursements;
        } else {
          pettyCashReceived += openingBalance;
          pettyCashUsed += totalDisbursements;
        }
      }

      // Calculate project budget totals
      double projectBudget = 0;
      double projectExpenses = 0;
      for (var doc in allProjectReportsQuery.docs) {
        projectBudget += (doc.data()['budget'] ?? 0).toDouble();
        projectExpenses += (doc.data()['totalExpenses'] ?? 0).toDouble();
      }

      // Calculate income totals
      double incomeAmount = 0;
      for (var doc in allIncomeReportsQuery.docs) {
        incomeAmount += (doc.data()['totalIncome'] ?? 0).toDouble();
      }

      // Calculate mileage totals
      double mileageAmount = 0;
      for (var doc in allTravelingQuery.docs) {
        mileageAmount += (doc.data()['mileageAmount'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _pendingReports = reportsQuery.docs.length;
          _pendingTransactions = transactionsQuery.docs.length;
          _pendingTravelReports = travelQuery.docs.length;
          _pendingIncomeReports = incomeQuery.docs.length;
          _totalPettyCashReceived = pettyCashReceived;
          _totalPettyCashUsed = pettyCashUsed;
          _totalAdvanceReceived = advanceReceived;
          _totalAdvanceUsed = advanceUsed;
          _totalProjectBudget = projectBudget;
          _totalProjectExpenses = projectExpenses;
          _totalIncomeAmount = incomeAmount;
          _totalMileageAmount = mileageAmount;
          _totalIncomeReports = allIncomeReportsQuery.docs.length;
        });
      }
    } catch (e) {
      // Silently handle errors
      debugPrint('Error loading finance stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isAdmin = user?.role == 'admin';
    final canApprove = authProvider.canApprove();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCounts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeaderBanner(),
                  const SizedBox(height: 24),
                  _buildFinancialOverview(),
                  const SizedBox(height: 24),
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildMenuSection(context, isAdmin, canApprove),
                  const SizedBox(height: 24),
                  _buildQuickActionsSection(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade400,
            Colors.blue.shade600,
            Colors.blue.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top action bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeaderActionButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back to Admin Hub',
                      onPressed: () => context.go('/admin-hub'),
                    ),
                    Row(
                      children: [
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh',
                          onPressed: _loadCounts,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Main content
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Finance Hub',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage reports, transactions & approvals',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildBannerStat('$_pendingReports', 'Reports'),
                              const SizedBox(width: 24),
                              _buildBannerStat(
                                '$_pendingTransactions',
                                'Transactions',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildBannerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialOverview() {
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 2,
    );
    final pettyCashBalance = _totalPettyCashReceived - _totalPettyCashUsed;
    final advanceBalance = _totalAdvanceReceived - _totalAdvanceUsed;
    final projectRemaining = _totalProjectBudget - _totalProjectExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        // Petty Cash Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
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
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Petty Cash Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      'Received',
                      currencyFormat.format(_totalPettyCashReceived),
                      Colors.green,
                      Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      'Used',
                      currencyFormat.format(_totalPettyCashUsed),
                      Colors.orange,
                      Icons.arrow_upward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      'Balance',
                      currencyFormat.format(pettyCashBalance),
                      pettyCashBalance >= 0 ? Colors.blue : Colors.red,
                      Icons.account_balance,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Advance Settlement Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
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
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.request_page,
                      color: Colors.orange.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Advance Settlement Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      'Advanced',
                      currencyFormat.format(_totalAdvanceReceived),
                      Colors.orange,
                      Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      'Used',
                      currencyFormat.format(_totalAdvanceUsed),
                      Colors.deepOrange,
                      Icons.arrow_upward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      'Balance',
                      currencyFormat.format(advanceBalance),
                      advanceBalance >= 0 ? Colors.blue : Colors.red,
                      Icons.account_balance,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Project Budget Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.work,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Project Budget Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      'Total Budget',
                      currencyFormat.format(_totalProjectBudget),
                      Colors.blue,
                      Icons.pie_chart,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      'Expenses',
                      currencyFormat.format(_totalProjectExpenses),
                      Colors.orange,
                      Icons.shopping_cart,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      'Remaining',
                      currencyFormat.format(projectRemaining),
                      projectRemaining >= 0 ? Colors.green : Colors.red,
                      Icons.savings,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Income & Mileage Summary
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.shade200,
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
                        Icon(
                          Icons.trending_up,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Income',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(_totalIncomeAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalIncomeReports reports',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
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
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.shade200,
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
                        Icon(
                          Icons.directions_car,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Mileage',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(_totalMileageAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_pendingTravelReports pending',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Pending Reports',
            _pendingReports,
            Colors.blue,
            Icons.description,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Pending Transactions',
            _pendingTransactions,
            Colors.green,
            Icons.receipt_long,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    bool isAdmin,
    bool canApprove,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);

    final menuItems = <_MenuItem>[
      _MenuItem(
        title: 'Reports',
        subtitle: 'View all financial reports',
        icon: Icons.description,
        color: Colors.blue,
        route: '/reports',
        badge: _pendingReports > 0 ? _pendingReports : null,
      ),
      _MenuItem(
        title: 'Advance Settlement',
        subtitle: 'View advance reports in table',
        icon: Icons.request_page,
        color: Colors.orange,
        route: '/reports?type=advance_settlement',
        onTap: (context) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('reports_view_mode', 'tableRow');
          if (context.mounted) {
            context.push('/reports?type=advance_settlement');
          }
        },
      ),
      _MenuItem(
        title: 'Transactions',
        subtitle: 'Transaction summary',
        icon: Icons.receipt_long,
        color: Colors.green,
        route: '/transactions',
        badge: _pendingTransactions > 0 ? _pendingTransactions : null,
      ),
      _MenuItem(
        title: 'Finance Analysis',
        subtitle: 'Charts and text insights',
        icon: Icons.auto_graph,
        color: Colors.indigo,
        route: '/finance-ai-report',
      ),
      _MenuItem(
        title: 'Approvals',
        subtitle: 'Pending approvals',
        icon: Icons.approval,
        color: Colors.orange,
        route: '/approvals',
        badge: (_pendingReports + _pendingTransactions) > 0
            ? _pendingReports + _pendingTransactions
            : null,
        visible: canApprove,
      ),
      _MenuItem(
        title: 'Travel Reports',
        subtitle: 'Traveling expenses',
        icon: Icons.flight_takeoff,
        color: Colors.indigo,
        route: isAdmin ? '/admin/traveling-reports' : '/traveling-reports',
        badge: _pendingTravelReports > 0 && isAdmin
            ? _pendingTravelReports
            : null,
      ),
      _MenuItem(
        title: 'Income Reports',
        subtitle: 'Income tracking',
        icon: Icons.trending_up,
        color: Colors.teal,
        route: isAdmin ? '/admin/income' : '/income',
        badge: _pendingIncomeReports > 0 && isAdmin
            ? _pendingIncomeReports
            : null,
      ),
      _MenuItem(
        title: 'Purchase Requests',
        subtitle: 'PR management',
        icon: Icons.shopping_cart,
        color: Colors.purple,
        route: '/purchase-requisitions',
      ),
      _MenuItem(
        title: 'Cash Advances',
        subtitle: 'Request cash advance',
        icon: Icons.request_quote,
        color: Colors.indigo,
        route: '/cash-advances?view=table',
      ),
      _MenuItem(
        title: 'Medical Reimbursement',
        subtitle: 'Medical bill claims',
        icon: Icons.local_hospital,
        color: Colors.teal,
        route: '/medical-reimbursement',
      ),
      _MenuItem(
        title: 'Payment Vouchers',
        subtitle: 'Issue & track payments',
        icon: Icons.receipt,
        color: Colors.deepPurple,
        route: '/payment-vouchers',
      ),
    ];

    final visibleItems = menuItems.where((item) => item.visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finance Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: visibleItems.length,
          itemBuilder: (context, index) {
            final item = visibleItems[index];
            return _buildMenuCard(context, item);
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, _MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (item.onTap != null) {
            await item.onTap!(context);
          } else {
            context.push(item.route);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionChip(
                context,
                icon: Icons.add_chart,
                label: 'New Report',
                route: '/reports/new',
                color: Colors.blue,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.receipt_long,
                label: 'View Transactions',
                route: '/transactions',
                color: Colors.green,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.flight_takeoff,
                label: 'Travel Report',
                route: '/traveling-reports',
                color: Colors.indigo,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.trending_up,
                label: 'Income Report',
                route: '/income/new',
                color: Colors.teal,
              ),
              _buildQuickActionChip(
                context,
                icon: Icons.add_card,
                label: 'New Voucher',
                route: '/payment-vouchers/new',
                color: Colors.deepPurple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      onPressed: () => context.push(route),
    );
  }

  Widget _buildScopeChip(String label, _AiReportScope scope) {
    final isSelected = _aiReportScopes.contains(scope);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _aiReportScopes.add(scope);
          } else {
            _aiReportScopes.remove(scope);
          }
        });
      },
      selectedColor: Colors.indigo.shade600,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildPresetChip(String label, _AiReportPreset preset) {
    final isSelected = _aiReportPreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyPreset(preset),
      selectedColor: Colors.indigo.shade600,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildChartSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTrendChart(List<_TrendPoint> points) {
    if (points.isEmpty) {
      return _buildEmptyChart();
    }
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _TrendLinePainter(points),
        child: Container(),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, double> data) {
    if (data.isEmpty) {
      return _buildEmptyChart();
    }
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxValue = top.first.value;

    return Column(
      children: top.map((entry) {
        final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                NumberFormat.compactCurrency(
                  symbol: AppConstants.currencySymbol,
                ).format(entry.value),
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCashFlowChart(_CashFlowSummary cashFlow) {
    final maxValue = [
      cashFlow.opening,
      cashFlow.disbursed,
      cashFlow.closing,
    ].fold<double>(0, (max, v) => v > max ? v : max);
    if (maxValue == 0) {
      return _buildEmptyChart();
    }

    Widget buildBar(String label, double value, Color color) {
      final ratio = maxValue == 0 ? 0.0 : value / maxValue;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              NumberFormat.compactCurrency(
                symbol: AppConstants.currencySymbol,
              ).format(value),
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        buildBar('Opening', cashFlow.opening, Colors.blue.shade400),
        buildBar('Disbursed', cashFlow.disbursed, Colors.red.shade400),
        buildBar('Closing', cashFlow.closing, Colors.green.shade500),
      ],
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'No data for the selected range',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }

  String _formatRangeLabel() {
    final range = _resolveRange();
    final format = DateFormat('MMM d, y');
    return 'Range: ${format.format(range.start)} - ${format.format(range.end)}';
  }

  void _applyPreset(_AiReportPreset preset) {
    setState(() {
      _aiReportPreset = preset;
      _aiReportError = null;
    });

    final now = DateTime.now();
    if (preset == _AiReportPreset.thisMonth) {
      _aiReportRange = _AiReportRange.month;
      _aiCustomStart = DateTime(now.year, now.month, 1);
      _aiCustomEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (preset == _AiReportPreset.lastMonth) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      _aiReportRange = _AiReportRange.month;
      _aiCustomStart = lastMonth;
      _aiCustomEnd = DateTime(
        lastMonth.year,
        lastMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    } else if (preset == _AiReportPreset.ytd) {
      _aiReportRange = _AiReportRange.year;
      _aiCustomStart = DateTime(now.year, 1, 1);
      _aiCustomEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  void _applyRangeDefault() {
    final now = DateTime.now();
    if (_aiReportRange == _AiReportRange.month) {
      _aiCustomStart = DateTime(now.year, now.month, 1);
      _aiCustomEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (_aiReportRange == _AiReportRange.quarter) {
      final quarter = ((now.month - 1) ~/ 3) + 1;
      final startMonth = (quarter - 1) * 3 + 1;
      _aiCustomStart = DateTime(now.year, startMonth, 1);
      _aiCustomEnd = DateTime(now.year, startMonth + 3, 0, 23, 59, 59);
    } else if (_aiReportRange == _AiReportRange.year) {
      _aiCustomStart = DateTime(now.year, 1, 1);
      _aiCustomEnd = DateTime(now.year, 12, 31, 23, 59, 59);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    if (_aiReportRange == _AiReportRange.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5, 1, 1),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _aiCustomStart != null && _aiCustomEnd != null
            ? DateTimeRange(start: _aiCustomStart!, end: _aiCustomEnd!)
            : null,
      );
      if (range != null) {
        setState(() {
          _aiCustomStart = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          _aiCustomEnd = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
            23,
            59,
            59,
          );
          _aiReportPreset = _AiReportPreset.none;
        });
      }
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _aiCustomStart ?? now,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      _aiReportPreset = _AiReportPreset.none;
      if (_aiReportRange == _AiReportRange.month) {
        _aiCustomStart = DateTime(picked.year, picked.month, 1);
        _aiCustomEnd = DateTime(picked.year, picked.month + 1, 0, 23, 59, 59);
      } else if (_aiReportRange == _AiReportRange.quarter) {
        final quarter = ((picked.month - 1) ~/ 3) + 1;
        final startMonth = (quarter - 1) * 3 + 1;
        _aiCustomStart = DateTime(picked.year, startMonth, 1);
        _aiCustomEnd = DateTime(picked.year, startMonth + 3, 0, 23, 59, 59);
      } else if (_aiReportRange == _AiReportRange.year) {
        _aiCustomStart = DateTime(picked.year, 1, 1);
        _aiCustomEnd = DateTime(picked.year, 12, 31, 23, 59, 59);
      }
    });
  }

  _AiDateRange _resolveRange() {
    final now = DateTime.now();
    final start = _aiCustomStart ?? DateTime(now.year, now.month, 1);
    final end =
        _aiCustomEnd ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _AiDateRange(start, end);
  }

  Future<void> _generateAiReport() async {
    if (_aiReportScopes.isEmpty) {
      setState(() {
        _aiReportError = 'Select at least one data source.';
      });
      return;
    }

    setState(() {
      _aiReportLoading = true;
      _aiReportError = null;
    });

    try {
      final range = _resolveRange();
      final firestore = FirebaseFirestore.instance;
      final startTs = Timestamp.fromDate(range.start);
      final endTs = Timestamp.fromDate(range.end);

      final trendTotals = <DateTime, double>{};
      final categoryTotals = <String, double>{};

      double cashOpening = 0;
      double cashDisbursed = 0;
      double cashClosing = 0;

      double totalInflow = 0;
      double totalOutflow = 0;
      int totalItems = 0;

      if (_aiReportScopes.contains(_AiReportScope.transactions)) {
        final snapshot = await firestore
            .collection('transactions')
            .where('date', isGreaterThanOrEqualTo: startTs)
            .where('date', isLessThanOrEqualTo: endTs)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final amount = (data['amount'] ?? 0).toDouble();
          final timestamp = data['date'] as Timestamp?;
          final date = timestamp?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, amount, range);

          final category =
              (data['customCategory'] as String?)?.trim().isNotEmpty == true
              ? data['customCategory'] as String
              : (data['category'] as String?) ?? 'Other';
          categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
          totalOutflow += amount;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.pettyCashReports)) {
        final snapshot = await firestore
            .collection('reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final opening = (data['openingBalance'] ?? 0).toDouble();
          final disbursed = (data['totalDisbursements'] ?? 0).toDouble();
          final closing = (data['closingBalance'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, disbursed, range);

          cashOpening += opening;
          cashDisbursed += disbursed;
          cashClosing += closing;
          totalOutflow += disbursed;
          totalInflow += opening;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.projectReports)) {
        final snapshot = await firestore
            .collection('project_reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final expenses = (data['totalExpenses'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, expenses, range);
          totalOutflow += expenses;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.incomeReports)) {
        final snapshot = await firestore
            .collection('income_reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final totalIncome = (data['totalIncome'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, totalIncome, range);
          totalInflow += totalIncome;
          totalItems += 1;
        }
      }

      if (_aiReportScopes.contains(_AiReportScope.travelReports)) {
        final snapshot = await firestore
            .collection('traveling_reports')
            .where('createdAt', isGreaterThanOrEqualTo: startTs)
            .where('createdAt', isLessThanOrEqualTo: endTs)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final mileage = (data['mileageAmount'] ?? 0).toDouble();
          final date =
              (data['createdAt'] as Timestamp?)?.toDate() ?? range.start;
          _accumulateTrend(trendTotals, date, mileage, range);
          totalOutflow += mileage;
          totalItems += 1;
        }
      }

      final trendPoints = _buildTrendPoints(trendTotals);
      final summary = _buildSummaryText(
        totalInflow: totalInflow,
        totalOutflow: totalOutflow,
        totalItems: totalItems,
        categoryTotals: categoryTotals,
        range: range,
      );

      setState(() {
        _aiTrendPoints = trendPoints;
        _aiCategoryTotals = categoryTotals;
        _aiCashFlow = _CashFlowSummary(cashOpening, cashDisbursed, cashClosing);
        _aiSummaryText = summary;
      });
    } catch (e) {
      setState(() {
        _aiReportError = 'Failed to generate report: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _aiReportLoading = false;
        });
      }
    }
  }

  void _accumulateTrend(
    Map<DateTime, double> trendTotals,
    DateTime date,
    double amount,
    _AiDateRange range,
  ) {
    final spanDays = range.end.difference(range.start).inDays;
    final bucket = spanDays <= 40
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month);
    trendTotals[bucket] = (trendTotals[bucket] ?? 0) + amount;
  }

  List<_TrendPoint> _buildTrendPoints(Map<DateTime, double> totals) {
    if (totals.isEmpty) return [];
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spanDays = entries.last.key.difference(entries.first.key).inDays;
    final format = spanDays <= 40
        ? DateFormat('MMM d')
        : DateFormat('MMM yyyy');
    return entries
        .map((e) => _TrendPoint(format.format(e.key), e.value))
        .toList();
  }

  String _buildSummaryText({
    required double totalInflow,
    required double totalOutflow,
    required int totalItems,
    required Map<String, double> categoryTotals,
    required _AiDateRange range,
  }) {
    final format = NumberFormat.compactCurrency(
      symbol: AppConstants.currencySymbol,
    );
    final net = totalInflow - totalOutflow;
    String topCategory = 'N/A';
    if (categoryTotals.isNotEmpty) {
      final top = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCategory = top.first.key;
    }
    return 'Analyzed $totalItems records from '
        '${DateFormat('MMM d, y').format(range.start)} to '
        '${DateFormat('MMM d, y').format(range.end)}. '
        'Inflow ${format.format(totalInflow)}, '
        'Outflow ${format.format(totalOutflow)}, '
        'Net ${format.format(net)}. '
        'Top category: $topCategory.';
  }
}

enum _AiReportScope {
  pettyCashReports,
  transactions,
  projectReports,
  incomeReports,
  travelReports,
}

enum _AiReportRange {
  month,
  quarter,
  year,
  custom;

  String get label {
    switch (this) {
      case _AiReportRange.month:
        return 'Month';
      case _AiReportRange.quarter:
        return 'Quarter';
      case _AiReportRange.year:
        return 'Year';
      case _AiReportRange.custom:
        return 'Custom';
    }
  }
}

enum _AiReportPreset { none, thisMonth, lastMonth, ytd }

class _AiDateRange {
  final DateTime start;
  final DateTime end;

  _AiDateRange(this.start, this.end);
}

class _TrendPoint {
  final String label;
  final double value;

  _TrendPoint(this.label, this.value);
}

class _CashFlowSummary {
  final double opening;
  final double disbursed;
  final double closing;

  const _CashFlowSummary(this.opening, this.disbursed, this.closing);
}

class _TrendLinePainter extends CustomPainter {
  final List<_TrendPoint> points;

  _TrendLinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxValue = points
        .map((p) => p.value)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final minValue = points
        .map((p) => p.value)
        .fold<double>(double.infinity, (min, v) => v < min ? v : min);
    final range = (maxValue - minValue).abs() < 0.01 ? 1 : maxValue - minValue;

    final paint = Paint()
      ..color = Colors.indigo.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = Colors.indigo.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (size.width) * (i / (points.length - 1));
      final normalized = (points[i].value - minValue) / range;
      final y = size.height - (normalized * (size.height - 16)) - 8;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = Colors.indigo.shade600,
      );
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final int? badge;
  final bool visible;
  final Future<void> Function(BuildContext context)? onTap;

  _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.badge,
    this.visible = true,
    this.onTap,
  });
}
