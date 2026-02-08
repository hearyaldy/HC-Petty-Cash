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
  int _totalReports = 0;
  int _totalIncomeReports = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
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
        final totalDisbursements =
            (data['totalDisbursements'] ?? 0).toDouble();

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
          _totalReports = allReportsQuery.docs.length;
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
