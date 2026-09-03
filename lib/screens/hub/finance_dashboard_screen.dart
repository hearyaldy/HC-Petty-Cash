import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/constants.dart';
import '../../widgets/app_drawer.dart';

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
  // ignore: unused_field
  double _totalProjectBudget = 0;
  // ignore: unused_field
  double _totalProjectExpenses = 0;
  double _totalIncomeAmount = 0;
  double _totalMileageAmount = 0;
  int _totalIncomeReports = 0;

  int get _approvalQueueCount => _pendingTransactions + _pendingTravelReports;

  // AI report state
  final Set<_AiReportScope> _aiReportScopes = {
    _AiReportScope.transactions,
    _AiReportScope.pettyCashReports,
  };
  _AiReportRange _aiReportRange = _AiReportRange.month;
  _AiReportPreset _aiReportPreset = _AiReportPreset.thisMonth;
  DateTime? _aiCustomStart;
  DateTime? _aiCustomEnd;
  // ignore: unused_field
  bool _aiReportLoading = false;
  // ignore: unused_field
  String? _aiReportError;
  // ignore: unused_field
  List<_TrendPoint> _aiTrendPoints = [];
  // ignore: unused_field
  Map<String, double> _aiCategoryTotals = {};
  // ignore: unused_field
  _CashFlowSummary _aiCashFlow = const _CashFlowSummary(0, 0, 0);
  // ignore: unused_field
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
          .where('status', whereIn: ['submitted', 'pendingApproval'])
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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _buildWelcomeBanner(context),
                const SizedBox(height: 14),
                _buildPriorityStatusCard(context),
                const SizedBox(height: 14),
                _buildSectionLabel('Overview'),
                const SizedBox(height: 8),
                _buildKpiRow(context),
                const SizedBox(height: 14),
                _buildSectionLabel('Financial Summary'),
                const SizedBox(height: 8),
                _buildFinancialSummaryRow(context),
                const SizedBox(height: 14),
                _buildActivitySnapshotCard(context),
                const SizedBox(height: 14),
                _buildSectionLabel('Finance Management'),
                const SizedBox(height: 8),
                _buildMenuList(context),
                const SizedBox(height: 14),
                _buildSectionLabel('Quick Actions'),
                const SizedBox(height: 8),
                _buildQuickActionsCard(context),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isFinance = user?.role == 'finance';
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 760;
    final isPhone = screenWidth < 430;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // HC logo box
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'HC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Finance Hub',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isPhone
                                  ? 'Reports & Management'
                                  : 'Financial Reports & Management',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isCompact)
                        Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isFinance
                                ? 'FINANCE'
                                : (user?.role.toUpperCase() ?? 'STAFF'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      if (!isCompact)
                        Container(
                          width: 1,
                          height: 20,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 20,
                          ),
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Approvals',
                            onPressed: () => context.push(AppRoutes.approvals),
                          ),
                          if (_approvalQueueCount > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$_approvalQueueCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Refresh',
                        onPressed: _loadCounts,
                      ),
                      if (!isPhone)
                        GestureDetector(
                          onTap: () => context.push('/user-profile'),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _initials(user?.name ?? ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ─── Welcome banner ────────────────────────────────────────────────────────

  Widget _buildWelcomeBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthYear = DateFormat('MMMM yyyy').format(DateTime.now());
    final metrics = [
      ('Pending\nReports', _pendingReports),
      ('Pending\nTx', _pendingTransactions),
      ('Travel\nPending', _pendingTravelReports),
      ('Income\nPending', _pendingIncomeReports),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 1.0],
          colors: [cs.primary.withValues(alpha: 0.85), cs.primary],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finance Hub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Financial Reports & Management · $monthYear',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics
                      .map(
                        (metric) => SizedBox(
                          width: constraints.maxWidth < 420
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                          child: _buildWelcomeStat(
                            metric.$1,
                            metric.$2,
                            compact: true,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Finance Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Financial Reports & Management · $monthYear',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    _buildWelcomeStat(metrics[i].$1, metrics[i].$2),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWelcomeStat(String label, int value, {bool compact = false}) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 20 : 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 10,
          ),
        ),
      ],
    );

    if (!compact) {
      return child;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _buildPriorityStatusCard(BuildContext context) {
    final totalPending = _approvalQueueCount;
    final needsAttention = totalPending > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: needsAttention ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: needsAttention ? Colors.red.shade100 : Colors.green.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: (needsAttention ? Colors.red : Colors.green).withValues(
              alpha: 0.08,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: needsAttention
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  needsAttention
                      ? Icons.priority_high_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: needsAttention
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      needsAttention
                          ? '$totalPending approvals need attention'
                          : 'Everything looks up to date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: needsAttention
                            ? Colors.red.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      needsAttention
                          ? 'Transactions $_pendingTransactions, travel reports $_pendingTravelReports'
                          : 'No pending approvals are waiting right now.',
                      style: TextStyle(
                        fontSize: 11,
                        color: needsAttention
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final action = FilledButton.tonalIcon(
            onPressed: totalPending > 0
                ? () => context.push(AppRoutes.approvals)
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(totalPending > 0 ? 'Open approvals' : 'All clear'),
            style: FilledButton.styleFrom(
              backgroundColor: needsAttention
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              foregroundColor: needsAttention
                  ? Colors.red.shade800
                  : Colors.green.shade800,
              disabledBackgroundColor: Colors.green.shade100,
              disabledForegroundColor: Colors.green.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 12), action],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }

  // ─── KPI row ───────────────────────────────────────────────────────────────

  Widget _buildKpiRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kpis = [
      (
        label: 'Pending Reports',
        value: _pendingReports,
        icon: Icons.description_outlined,
        color: cs.error,
        bg: cs.error.withValues(alpha: 0.08),
        badge: _pendingReports > 0 ? 'Urgent' : 'Clear',
        isAlert: _pendingReports > 0,
      ),
      (
        label: 'Pending Transactions',
        value: _pendingTransactions,
        icon: Icons.receipt_long_outlined,
        color: Colors.amber.shade700,
        bg: Colors.amber.shade50,
        badge: _pendingTransactions > 0 ? 'Pending' : 'Clear',
        isAlert: _pendingTransactions > 0,
      ),
      (
        label: 'Travel Reports',
        value: _pendingTravelReports,
        icon: Icons.flight_takeoff,
        color: Colors.cyan.shade700,
        bg: Colors.cyan.shade50,
        badge: _pendingTravelReports > 0 ? 'Pending' : 'Clear',
        isAlert: false,
      ),
      (
        label: 'Income Reports',
        value: _pendingIncomeReports,
        icon: Icons.trending_up,
        color: const Color(0xFF059669),
        bg: Colors.green.shade50,
        badge: _pendingIncomeReports > 0 ? 'Pending' : 'Clear',
        isAlert: false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildKpiCard(kpis[0])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildKpiCard(kpis[1])),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildKpiCard(kpis[2])),
                  const SizedBox(width: 10),
                  Expanded(child: _buildKpiCard(kpis[3])),
                ],
              ),
            ],
          );
        }
        return Row(
          children: kpis
              .asMap()
              .entries
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: e.key == 0 ? 0 : 10),
                    child: _buildKpiCard(e.value),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(
    ({
      String label,
      int value,
      IconData icon,
      Color color,
      Color bg,
      String badge,
      bool isAlert,
    })
    kpi,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: kpi.color.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(height: 3.5, color: kpi.color),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kpi.bg, kpi.color.withValues(alpha: 0.14)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(kpi.icon, color: kpi.color, size: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kpi.isAlert ? Colors.red.shade50 : kpi.bg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: kpi.isAlert
                              ? Colors.red.shade200
                              : kpi.color.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        kpi.badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: kpi.isAlert ? Colors.red.shade700 : kpi.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${kpi.value}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: kpi.color,
                    letterSpacing: -1.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kpi.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Financial Summary ─────────────────────────────────────────────────────

  Widget _buildFinancialSummaryRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0', 'en_US');

    final pettyCashBalance = _totalPettyCashReceived - _totalPettyCashUsed;
    final advanceBalance = _totalAdvanceReceived - _totalAdvanceUsed;
    final pettyCashTotal = _totalPettyCashReceived == 0
        ? 1.0
        : _totalPettyCashReceived;
    final advanceTotal = _totalAdvanceReceived == 0
        ? 1.0
        : _totalAdvanceReceived;
    final incomeTotal = _totalIncomeAmount + _totalMileageAmount == 0
        ? 1.0
        : _totalIncomeAmount + _totalMileageAmount;

    return _buildCard(
      context,
      icon: Icons.account_balance_outlined,
      title: 'Financial Summary',
      child: Column(
        children: [
          // Petty Cash
          _buildFTile(
            context,
            color: const Color(0xFF059669),
            label: 'Petty Cash',
            receivedLabel:
                '${AppConstants.currencySymbol} ${fmt.format(_totalPettyCashReceived)}',
            usedLabel:
                '${AppConstants.currencySymbol} ${fmt.format(_totalPettyCashUsed)}',
            balanceLabel:
                '${AppConstants.currencySymbol} ${fmt.format(pettyCashBalance)}',
            progress: (_totalPettyCashUsed / pettyCashTotal).clamp(0.0, 1.0),
            metaLeft:
                'Received: ${AppConstants.currencySymbol} ${fmt.format(_totalPettyCashReceived)}',
            metaRight:
                'Used: ${((_totalPettyCashUsed / pettyCashTotal) * 100).toInt()}%',
          ),
          const SizedBox(height: 8),
          // Advance Settlement
          _buildFTile(
            context,
            color: Colors.amber.shade700,
            label: 'Advance Settlement',
            receivedLabel:
                '${AppConstants.currencySymbol} ${fmt.format(_totalAdvanceReceived)}',
            usedLabel:
                '${AppConstants.currencySymbol} ${fmt.format(_totalAdvanceUsed)}',
            balanceLabel:
                '${AppConstants.currencySymbol} ${fmt.format(advanceBalance)}',
            progress: (_totalAdvanceUsed / advanceTotal).clamp(0.0, 1.0),
            metaLeft:
                'Advanced: ${AppConstants.currencySymbol} ${fmt.format(_totalAdvanceReceived)}',
            metaRight:
                'Used: ${((_totalAdvanceUsed / advanceTotal) * 100).toInt()}%',
          ),
          const SizedBox(height: 8),
          // Income & Mileage
          _buildFTile(
            context,
            color: cs.primary,
            label: 'Income & Mileage',
            receivedLabel:
                '${AppConstants.currencySymbol} ${fmt.format(_totalIncomeAmount)}',
            usedLabel:
                '${AppConstants.currencySymbol} ${fmt.format(_totalMileageAmount)}',
            balanceLabel: '$_totalIncomeReports reports',
            progress: (_totalIncomeAmount / incomeTotal).clamp(0.0, 1.0),
            metaLeft:
                'Income: ${AppConstants.currencySymbol} ${fmt.format(_totalIncomeAmount)}',
            metaRight:
                'Mileage: ${AppConstants.currencySymbol} ${fmt.format(_totalMileageAmount)}',
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySnapshotCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cards = [
      (
        icon: Icons.description_outlined,
        color: cs.primary,
        label: 'Reports Queue',
        value: _pendingReports + _pendingTransactions,
        subtitle: 'Pending reports and transactions',
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF059669),
        label: 'Petty Cash Balance',
        value: (_totalPettyCashReceived - _totalPettyCashUsed).round(),
        subtitle: AppConstants.currencySymbol,
      ),
      (
        icon: Icons.flight_takeoff_rounded,
        color: Colors.cyan.shade700,
        label: 'Travel Pending',
        value: _pendingTravelReports,
        subtitle: 'Awaiting travel processing',
      ),
      (
        icon: Icons.trending_up_rounded,
        color: Colors.amber.shade700,
        label: 'Income Reports',
        value: _totalIncomeReports,
        subtitle: 'Total submitted income reports',
      ),
    ];

    return _buildCard(
      context,
      icon: Icons.insights_outlined,
      title: 'Activity Snapshot',
      badge: 'Live',
      badgeColor: cs.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 520
              ? 1
              : constraints.maxWidth < 900
              ? 2
              : 4;

          return GridView.builder(
            itemCount: cards.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: columns == 1 ? 112 : 148,
            ),
            itemBuilder: (context, index) {
              final card = cards[index];
              final isCurrency = card.label == 'Petty Cash Balance';
              final displayValue = isCurrency
                  ? '${AppConstants.currencySymbol} ${NumberFormat('#,##0', 'en_US').format(card.value)}'
                  : '${card.value}';
              final compact = columns == 1;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: card.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: card.color.withValues(alpha: 0.14)),
                ),
                child: compact
                    ? Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: card.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(card.icon, size: 19, color: card.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActivitySnapshotText(
                              displayValue: displayValue,
                              label: card.label,
                              subtitle: card.subtitle,
                              color: card.color,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: card.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(card.icon, size: 18, color: card.color),
                          ),
                          const SizedBox(height: 10),
                          _ActivitySnapshotText(
                            displayValue: displayValue,
                            label: card.label,
                            subtitle: card.subtitle,
                            color: card.color,
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFTile(
    BuildContext context, {
    required Color color,
    required String label,
    required String receivedLabel,
    required String usedLabel,
    required String balanceLabel,
    required double progress,
    required String metaLeft,
    required String metaRight,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  receivedLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Used: $usedLabel',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'Balance: $balanceLabel',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                metaLeft,
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
              ),
              Text(
                metaRight,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Menu grid ─────────────────────────────────────────────────────────────

  Widget _buildMenuList(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final isAdmin = user?.role == 'admin';
    final canApprove = authProvider.canApprove();

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
        title: 'Expense Claims',
        subtitle: 'Staff expense reimbursement',
        icon: Icons.receipt_long_outlined,
        color: Colors.orange,
        route: '/expense-claims',
      ),
      _MenuItem(
        title: 'Payment Vouchers',
        subtitle: 'Issue & track payments',
        icon: Icons.receipt,
        color: Colors.deepPurple,
        route: '/payment-vouchers',
      ),
      _MenuItem(
        title: 'Internal Debit Notes',
        subtitle: 'Intercompany charge-backs',
        icon: Icons.compare_arrows_outlined,
        color: Colors.brown,
        route: '/internal-debit-notes',
      ),
      _MenuItem(
        title: 'Production Budget',
        subtitle: 'Annual budget by language',
        icon: Icons.video_library_outlined,
        color: Colors.teal,
        route: '/finance/production-budget',
      ),
    ];

    final visibleItems = menuItems.where((item) => item.visible).toList();

    return _buildCard(
      context,
      icon: Icons.list_alt_rounded,
      title: 'Finance Management',
      child: Column(
        children: visibleItems
            .map(
              (item) => _buildListRow(
                context,
                icon: item.icon,
                color: item.color,
                title: item.title,
                subtitle: item.subtitle,
                badge: item.badge,
                onTap: () async {
                  if (item.onTap != null) {
                    await item.onTap!(context);
                  } else {
                    context.push(item.route);
                  }
                },
                isLast: item == visibleItems.last,
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── List row (Finance Management items) ──────────────────────────────────

  Widget _buildListRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    int? badge,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge
                if (badge != null && badge > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
      ],
    );
  }

  // ─── Quick actions card ────────────────────────────────────────────────────

  Widget _buildQuickActionsCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actions = [
      (icon: Icons.add_chart, label: 'New Report', route: '/reports/new'),
      (
        icon: Icons.receipt_long,
        label: 'View Transactions',
        route: '/transactions',
      ),
      (
        icon: Icons.flight_takeoff,
        label: 'Travel Report',
        route: '/traveling-reports',
      ),
      (icon: Icons.trending_up, label: 'Income Report', route: '/income/new'),
      (
        icon: Icons.add_card,
        label: 'New Voucher',
        route: '/payment-vouchers/new',
      ),
      (
        icon: Icons.compare_arrows_outlined,
        label: 'Debit Note',
        route: '/internal-debit-notes/new',
      ),
      (
        icon: Icons.shopping_cart_outlined,
        label: 'Purchase Req.',
        route: '/purchase-requisitions',
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Expense Claims',
        route: '/expense-claims',
      ),
    ];

    return _buildCard(
      context,
      icon: Icons.bolt,
      title: 'Quick Actions',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: actions.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: InkWell(
                onTap: () => context.push(a.route),
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  width: 80,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: Icon(
                                  a.icon,
                                  size: 21,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Shared card builder ──────────────────────────────────────────────────

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
    String? badge,
    Color? badgeColor,
    String? footerRoute,
    String? footerLabel,
  }) {
    final cs = Theme.of(context).colorScheme;
    final accent = badgeColor ?? cs.primary;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent top strip
          Container(height: 3, color: accent),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: child,
          ),
          // Footer
          if (footerRoute != null) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
            InkWell(
              onTap: () => context.push(footerRoute),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      footerLabel ?? 'View all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  // ─── AI report helpers (kept for Finance Analysis screen reuse) ───────────

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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

class _ActivitySnapshotText extends StatelessWidget {
  final String displayValue;
  final String label;
  final String subtitle;
  final Color color;

  const _ActivitySnapshotText({
    required this.displayValue,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
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
