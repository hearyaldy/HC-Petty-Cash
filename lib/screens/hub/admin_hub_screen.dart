import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/ai_consent_helper.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

// Available color themes (matches dashboard mockup palettes)
const _kColorThemes = [
  (name: 'blue', color: Color(0xFF3B82F6), label: 'Ocean'),
  (name: 'purple', color: Color(0xFF8B5CF6), label: 'Violet'),
  (name: 'green', color: Color(0xFF10B981), label: 'Emerald'),
  (name: 'red', color: Color(0xFFF43F5E), label: 'Rose'),
  (name: 'slate', color: Color(0xFF475569), label: 'Slate'),
];

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> {
  // KPI counts (kept from original)
  int _pendingApprovals = 0;
  int _pendingStudentReports = 0;

  // New KPI counts
  int _totalReports = 0;
  int _draftReports = 0;
  int _travelPending = 0;
  int _staffCount = 0;

  // List data for panels
  List<Map<String, dynamic>> _pendingApprovalItems = [];
  List<Map<String, dynamic>> _recentPettyCash = [];
  List<Map<String, dynamic>> _recentAdvance = [];
  List<Map<String, dynamic>> _recentPurchaseReqs = [];
  List<Map<String, dynamic>> _recentTravelReports = [];
  List<Map<String, dynamic>> _recentHrSubmissions = [];
  List<Map<String, dynamic>> _recentStaff = [];
  List<Map<String, dynamic>> _recentStudents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AiConsentHelper.showIfNeeded(context);
    });
  }

  Future<void> _loadData() async {
    try {
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        // Counts
        db.collection('reports').where('status', isEqualTo: 'submitted').get(),
        db
            .collection('transactions')
            .where('status', isEqualTo: 'submitted')
            .get(),
        db
            .collection('student_monthly_reports')
            .where('status', isEqualTo: 'submitted')
            .get(),
        db.collection('reports').get(),
        db.collection('reports').where('status', isEqualTo: 'draft').get(),
        db
            .collection('traveling_reports')
            .where('status', isEqualTo: 'submitted')
            .get(),
        db
            .collection('staff')
            .where('employmentStatus', isEqualTo: 'active')
            .get(),
        // Lists
        db
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .limit(12)
            .get(),
        db
            .collection('purchase_requisitions')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
        db
            .collection('traveling_reports')
            .orderBy('createdAt', descending: true)
            .limit(4)
            .get(),
        db
            .collection('hr_data_submissions')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
        db
            .collection('staff')
            .where('employmentStatus', isEqualTo: 'active')
            .limit(4)
            .get(),
        db
            .collection('student_monthly_reports')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(),
      ]);

      final reportsSubmitted = results[0];
      final transactionsSubmitted = results[1];
      final studentReports = results[2];
      final totalReports = results[3];
      final draftReports = results[4];
      final travelPending = results[5];
      final staffAll = results[6];
      final recentReports = results[7];
      final recentPrs = results[8];
      final recentTravel = results[9];
      final recentHr = results[10];
      final recentStaff = results[11];
      final recentStudents = results[12];

      // Build pending approval items
      final approvalItems = <Map<String, dynamic>>[];
      for (final doc in reportsSubmitted.docs.take(3)) {
        final d = doc.data();
        approvalItems.add({
          'id': doc.id,
          'name': d['custodianName'] ?? '',
          'title': d['reportNumber'] ?? 'Report',
          'type': d['reportType'] == 'advance_settlement'
              ? 'Advance Settlement'
              : 'Petty Cash',
          'amount': (d['totalDisbursements'] as num?)?.toDouble() ?? 0.0,
          'route': '/reports/${doc.id}',
          'date': (d['createdAt'] as Timestamp?)?.toDate(),
        });
      }
      for (final doc in travelPending.docs.take(2)) {
        final d = doc.data();
        approvalItems.add({
          'id': doc.id,
          'name': d['reporterName'] ?? '',
          'title': d['placeName'] ?? d['purpose'] ?? 'Travel',
          'type': 'Travel Report',
          'amount': (d['perDiemTotal'] as num?)?.toDouble() ?? 0.0,
          'route': '/traveling-reports/${doc.id}',
          'date':
              (d['submittedAt'] as Timestamp?)?.toDate() ??
              (d['createdAt'] as Timestamp?)?.toDate(),
        });
      }

      final allRecent = recentReports.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      if (mounted) {
        setState(() {
          _pendingApprovals =
              transactionsSubmitted.docs.length + travelPending.docs.length;
          _pendingStudentReports = studentReports.docs.length;

          _totalReports = totalReports.docs.length;
          _draftReports = draftReports.docs.length;
          _travelPending = travelPending.docs.length;
          _staffCount = staffAll.docs.length;
          _pendingApprovalItems = approvalItems;
          _recentPettyCash = allRecent
              .where((d) => d['reportType'] == 'petty_cash')
              .take(3)
              .toList();
          _recentAdvance = allRecent
              .where((d) => d['reportType'] == 'advance_settlement')
              .take(3)
              .toList();
          _recentPurchaseReqs = recentPrs.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _recentTravelReports = recentTravel.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _recentHrSubmissions = recentHr.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _recentStaff = recentStaff.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _recentStudents = recentStudents.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
        });
      }
    } catch (e) {
      // Silently handle — panels show empty state
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isAdmin = user?.role == 'admin';
    final canApprove = authProvider.canApprove();

    return Scaffold(
      appBar: _buildTopBar(context, user, authProvider, isAdmin),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),

                if (_pendingApprovals > 0) _buildAlertRibbon(context),

                _buildWelcomeBanner(context, user, authProvider, isAdmin),
                const SizedBox(height: 14),

                _buildSectionLabel('Overview'),
                const SizedBox(height: 8),
                _buildKpiRow(context),
                const SizedBox(height: 14),

                _buildSectionLabel('Actions & Finance'),
                const SizedBox(height: 8),
                _buildActionsFinanceRow(context, canApprove, isAdmin),
                const SizedBox(height: 14),

                if (canApprove && _pendingApprovalItems.isNotEmpty) ...[
                  _buildSectionLabel('Pending Approvals'),
                  const SizedBox(height: 8),
                  _buildPendingApprovalsCard(context),
                  const SizedBox(height: 14),
                ],

                _buildSectionLabel('Recent Reports'),
                const SizedBox(height: 8),
                _buildRecentReportsRow(context),
                const SizedBox(height: 14),

                if (isAdmin) ...[
                  _buildSectionLabel('Administration'),
                  const SizedBox(height: 8),
                  _buildAdministrationRow(context),
                  const SizedBox(height: 14),
                ],

                _buildSectionLabel('Traveling Overview'),
                const SizedBox(height: 8),
                _buildTravelingOverview(context),
                const SizedBox(height: 14),

                if (isAdmin) ...[
                  _buildSectionLabel('People Management'),
                  const SizedBox(height: 8),
                  _buildPeopleManagement(context),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar (AppBar) ─────────────────────────────────────────────────────

  PreferredSizeWidget _buildTopBar(
    BuildContext context,
    User? user,
    AuthProvider authProvider,
    bool isAdmin,
  ) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final currentTheme = themeProvider.colorTheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;
    final isCompact = MediaQuery.of(context).size.width < 900;

    final topBarColor = cs.primary;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: topBarColor,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'HC Financial Report System',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
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
                            isAdmin ? 'ADMIN' : 'STAFF',
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
                      if (!isCompact)
                        ..._kColorThemes.map(
                          (t) => _buildColorDot(
                            context,
                            t.name,
                            t.color,
                            t.label,
                            currentTheme,
                            themeProvider,
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
                          if (_pendingApprovals > 0)
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
                                    color: topBarColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$_pendingApprovals',
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
                        onPressed: _loadData,
                      ),
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

  Widget _buildColorDot(
    BuildContext context,
    String name,
    Color color,
    String label,
    String currentTheme,
    ThemeProvider themeProvider,
  ) {
    final isActive = currentTheme == name;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => themeProvider.updateColorTheme(name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isActive ? 20 : 18,
          height: isActive ? 20 : 18,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 22),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: Colors.white, width: 2.5)
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ]
                : null,
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

  // ─── Alert ribbon ──────────────────────────────────────────────────────────

  Widget _buildAlertRibbon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.errorContainer.withValues(alpha: 0.5),
            cs.errorContainer.withValues(alpha: 0.25),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: cs.error.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Left accent strip
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: cs.error),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 12,
                top: 11,
                bottom: 11,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final icon = Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: cs.error.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.pending_actions,
                      size: 16,
                      color: Colors.white,
                    ),
                  );

                  final textBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_pendingApprovals item${_pendingApprovals > 1 ? 's' : ''} waiting for approval',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onErrorContainer,
                        ),
                      ),
                      Text(
                        'Tap to review and take action',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.error.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  );

                  final action = FilledButton.tonal(
                    onPressed: () => context.push(AppRoutes.approvals),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Review',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10),
                      ],
                    ),
                  );

                  if (constraints.maxWidth < 640) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            icon,
                            const SizedBox(width: 12),
                            Expanded(child: textBlock),
                          ],
                        ),
                        const SizedBox(height: 12),
                        action,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: textBlock),
                      const SizedBox(width: 8),
                      action,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Welcome banner ────────────────────────────────────────────────────────

  Widget _buildWelcomeBanner(
    BuildContext context,
    User? user,
    AuthProvider authProvider,
    bool isAdmin,
  ) {
    final hour = DateTime.now().hour;
    final cs = Theme.of(context).colorScheme;
    final monthYear = DateFormat('MMMM yyyy').format(DateTime.now());
    final String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

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
          final stats = [
            ('Reports This Month', _totalReports),
            ('Staff Members', _staffCount),
            ('Pending', _pendingApprovals),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${user?.name ?? 'Admin'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isAdmin ? 'Administrator' : 'Staff'} · HC Financial Report System · $monthYear',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: stats
                      .map(
                        (stat) => SizedBox(
                          width: constraints.maxWidth < 420
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                          child: _buildWelcomeStat(
                            stat.$1,
                            stat.$2,
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
                    Text(
                      '$greeting, ${user?.name ?? 'Admin'} 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isAdmin ? 'Administrator' : 'Staff'} · HC Financial Report System · $monthYear',
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
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    _buildWelcomeStat(stats[i].$1, stats[i].$2),
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
            fontSize: 11,
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

  // ─── KPI row (5 cards) ────────────────────────────────────────────────────

  Widget _buildKpiRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kpis = [
      (
        label: 'Total Reports',
        value: _totalReports,
        icon: Icons.description_outlined,
        color: cs.primary,
        bg: cs.primary.withValues(alpha: 0.08),
        badge: 'All',
        isAlert: false,
      ),
      (
        label: 'Draft Reports',
        value: _draftReports,
        icon: Icons.edit_note,
        color: Colors.amber.shade700,
        bg: Colors.amber.shade50,
        badge: 'drafts',
        isAlert: false,
      ),
      (
        label: 'Pending Approvals',
        value: _pendingApprovals,
        icon: Icons.hourglass_top,
        color: Colors.red.shade600,
        bg: Colors.red.shade50,
        badge: _pendingApprovals > 0 ? 'Urgent' : 'Clear',
        isAlert: _pendingApprovals > 0,
      ),
      (
        label: 'Travel Reports',
        value: _travelPending,
        icon: Icons.flight_takeoff,
        color: Colors.cyan.shade700,
        bg: Colors.cyan.shade50,
        badge: _travelPending > 0 ? 'Pending' : 'Clear',
        isAlert: false,
      ),
      (
        label: 'Staff Members',
        value: _staffCount,
        icon: Icons.badge_outlined,
        color: Colors.green.shade600,
        bg: Colors.green.shade50,
        badge: 'Active',
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
              const SizedBox(height: 10),
              _buildKpiCard(kpis[4]),
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

  // ─── Actions & Finance row-3 ───────────────────────────────────────────────

  Widget _buildActionsFinanceRow(
    BuildContext context,
    bool canApprove,
    bool isAdmin,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              _buildQuickActionsCard(context, canApprove, isAdmin),
              const SizedBox(height: 14),
              _buildReportSummaryCard(context),
              const SizedBox(height: 14),
              _buildIncomeCard(context),
              const SizedBox(height: 14),
              _buildBudgetCard(context),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildQuickActionsCard(context, canApprove, isAdmin),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildReportSummaryCard(context),
                  const SizedBox(height: 14),
                  _buildIncomeCard(context),
                  const SizedBox(height: 14),
                  _buildBudgetCard(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsCard(
    BuildContext context,
    bool canApprove,
    bool isAdmin,
  ) {
    final actions = [
      (icon: Icons.add_chart, label: 'New Report', route: '/reports/new'),
      (
        icon: Icons.receipt_long,
        label: 'New Transaction',
        route: '/transactions',
      ),
      (
        icon: Icons.flight_takeoff,
        label: 'Travel Report',
        route: '/traveling-reports',
      ),
      (
        icon: Icons.shopping_cart_outlined,
        label: 'Purchase Req.',
        route: '/purchase-requisitions',
      ),
      (
        icon: Icons.groups_outlined,
        label: 'Meetings',
        route: '/meetings-dashboard',
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        label: 'Cash Advance',
        route: '/cash-advances',
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Expense Claims',
        route: '/expense-claims',
      ),
      if (canApprove)
        (
          icon: Icons.approval_outlined,
          label: 'Approvals',
          route: AppRoutes.approvals,
        ),
      if (isAdmin)
        (
          icon: Icons.person_add_outlined,
          label: 'Add Staff',
          route: '/admin/staff/add',
        ),
    ];

    return _buildCard(
      context,
      icon: Icons.bolt,
      title: 'Quick Actions',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.1,
        children: actions
            .map(
              (a) => _buildActionBtn(
                context,
                icon: a.icon,
                label: a.label,
                route: a.route,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 72;
        final iconBoxSize = isCompact ? 30.0 : 36.0;
        final iconSize = isCompact ? 15.0 : 17.0;
        final gap = isCompact ? 3.0 : 5.0;
        final fontSize = isCompact ? 8.5 : 9.5;

        return InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 4 : 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: iconSize, color: cs.primary),
                  ),
                  SizedBox(height: gap),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportSummaryCard(BuildContext context) {
    final pending = _pendingApprovals.clamp(0, _totalReports);
    final draft = _draftReports.clamp(0, _totalReports);
    final total = _totalReports == 0 ? 1 : _totalReports;

    return _buildCard(
      context,
      icon: Icons.bar_chart_outlined,
      title: 'Report Summary',
      footerRoute: AppRoutes.reports,
      footerLabel: 'View all reports',
      child: Column(
        children: [
          _buildFTile(
            context,
            label: 'Petty Cash Reports',
            count: _totalReports,
            submitted: pending,
            total: total,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          _buildFTile(
            context,
            label: 'Draft Reports',
            count: _totalReports,
            submitted: draft,
            total: total,
            color: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildFTile(
    BuildContext context, {
    required String label,
    required int count,
    required int submitted,
    required int total,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final pct = (submitted / total).clamp(0.0, 1.0);
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
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '$submitted pending',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
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
                '$submitted submitted',
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
              ),
              Text(
                '${(pct * 100).toInt()}%',
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

  Widget _buildIncomeCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allReports = [..._recentPettyCash, ..._recentAdvance];
    final totalIncome = allReports.fold<double>(
      0,
      (acc, d) => acc + ((d['totalDisbursements'] as num?)?.toDouble() ?? 0),
    );
    final incomePending = allReports
        .where((d) => d['status'] == 'submitted')
        .length;
    final incomeTotal = allReports.isNotEmpty ? allReports.length : 1;
    final incomePct = (incomePending / incomeTotal).clamp(0.0, 1.0);

    final totalKm = _recentTravelReports.fold<double>(0, (acc, d) {
      final end = (d['mileageEnd'] as num?)?.toDouble() ?? 0;
      final start = (d['mileageStart'] as num?)?.toDouble() ?? 0;
      return acc + (end - start).clamp(0, double.infinity);
    });
    final totalPerDiem = _recentTravelReports.fold<double>(
      0,
      (acc, d) => acc + ((d['perDiemTotal'] as num?)?.toDouble() ?? 0),
    );
    final kmTotal = _recentTravelReports.isNotEmpty
        ? _recentTravelReports.length
        : 1;
    final kmPct = (_travelPending / kmTotal).clamp(0.0, 1.0);

    return _buildCard(
      context,
      icon: Icons.trending_up,
      title: 'Income & Mileage',
      badgeColor: Colors.teal.shade600,
      child: Column(
        children: [
          // Income tile
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.green.shade200.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Total Income',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '฿${NumberFormat('#,##0').format(totalIncome)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${allReports.length} reports',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: incomePct,
                    minHeight: 5,
                    backgroundColor: Colors.green.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$incomePending pending approval',
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Mileage tile
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mileage',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${totalKm.toStringAsFixed(0)} km',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'total',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: kmPct,
                    minHeight: 5,
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Reimb. ฿${NumberFormat('#,##0').format(totalPerDiem)}',
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pending Approvals (full width) ────────────────────────────────────────

  Widget _buildPendingApprovalsCard(BuildContext context) {
    final reportItems = _pendingApprovalItems
        .where((d) => d['type'] != 'Travel Report')
        .toList();
    final travelItems = _pendingApprovalItems
        .where((d) => d['type'] == 'Travel Report')
        .toList();

    return _buildCard(
      context,
      icon: Icons.pending_actions,
      title: 'Waiting for Your Action',
      badge: '$_pendingApprovals items',
      badgeColor: Colors.red,
      footerRoute: AppRoutes.approvals,
      footerLabel: 'View all approvals',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600 || travelItems.isEmpty;
          if (isCompact) {
            return Column(
              children: _pendingApprovalItems
                  .take(4)
                  .map((item) => _buildApprovalItem(context, item))
                  .toList(),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubLabel('Petty Cash / Advance'),
                    const SizedBox(height: 8),
                    ...reportItems
                        .take(2)
                        .map((item) => _buildApprovalItem(context, item)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubLabel('Travel Reports'),
                    const SizedBox(height: 8),
                    ...travelItems
                        .take(2)
                        .map((item) => _buildApprovalItem(context, item)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApprovalItem(BuildContext context, Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final type = item['type'] as String? ?? '';
    final amount = item['amount'] as double? ?? 0;
    final date = item['date'] as DateTime?;
    final route = item['route'] as String? ?? AppRoutes.approvals;

    Color typeColor;
    if (type == 'Travel Report') {
      typeColor = Colors.cyan.shade700;
    } else if (type == 'Advance Settlement') {
      typeColor = Colors.purple.shade600;
    } else {
      typeColor = cs.error;
    }

    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: cs.error.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3, color: typeColor),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials(item['name'] as String? ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item['title']} · $type${date != null ? ' · ${_relativeDate(date)}' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (amount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '฿${NumberFormat('#,##0').format(amount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Recent Reports row-3 ─────────────────────────────────────────────────

  Widget _buildRecentReportsRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              _buildReportListCard(
                context,
                title: 'Petty Cash Reports',
                icon: Icons.receipt_outlined,
                items: _recentPettyCash,
                footerRoute: AppRoutes.reports,
              ),
              const SizedBox(height: 14),
              _buildReportListCard(
                context,
                title: 'Advance Settlement',
                icon: Icons.file_open_outlined,
                items: _recentAdvance,
                footerRoute: AppRoutes.reports,
                badgeColor: Colors.orange,
              ),
              const SizedBox(height: 14),
              _buildTravelReportsCard(context),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildReportListCard(
                context,
                title: 'Petty Cash Reports',
                icon: Icons.receipt_outlined,
                items: _recentPettyCash,
                footerRoute: AppRoutes.reports,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildReportListCard(
                context,
                title: 'Advance Settlement',
                icon: Icons.file_open_outlined,
                items: _recentAdvance,
                footerRoute: AppRoutes.reports,
                badgeColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _buildTravelReportsCard(context)),
          ],
        );
      },
    );
  }

  Widget _buildReportListCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String footerRoute,
    Color? badgeColor,
    bool isPr = false,
  }) {
    return _buildCard(
      context,
      icon: icon,
      title: title,
      badge: items.isNotEmpty ? '${items.length}' : null,
      badgeColor: badgeColor ?? Theme.of(context).colorScheme.primary,
      footerRoute: footerRoute,
      footerLabel: 'View all',
      child: items.isEmpty
          ? _buildEmptyState('No recent records')
          : Column(
              children: items
                  .map(
                    (item) => _buildReportListItem(context, item, isPr: isPr),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildReportListItem(
    BuildContext context,
    Map<String, dynamic> item, {
    bool isPr = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final status = item['status'] as String? ?? 'draft';
    final name = isPr
        ? (item['requisitionNumber'] ?? item['reportNumber'] ?? 'Unknown')
        : (item['reportNumber'] ?? 'Unknown');
    final meta = _statusLabel(status);
    final rawAmount = isPr ? item['totalAmount'] : item['totalDisbursements'];
    final amount = rawAmount != null ? (rawAmount as num).toDouble() : null;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 3, color: statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount != null
                          ? '฿${NumberFormat('#,##0').format(amount)}'
                          : meta.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: meta.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: meta.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentYear = DateTime.now().year;
    return _buildCard(
      context,
      icon: Icons.account_balance_wallet_outlined,
      title: 'Annual Budget',
      badge: currentYear.toString(),
      badgeColor: cs.primary,
      footerRoute: '/admin/budget',
      footerLabel: 'View all budgets',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'HCSA Budget $currentYear',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat(
                      context,
                      value: 'Income',
                      label: 'S-15 to S-17',
                    ),
                    _buildMiniStat(
                      context,
                      value: 'Expenses',
                      label: 'S-18a to S-21',
                    ),
                    _buildMiniStat(
                      context,
                      value: 'Approp.',
                      label: 'S-22 to S-25',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/admin/budget'),
                    icon: Icon(Icons.open_in_new, size: 14, color: cs.primary),
                    label: Text(
                      'Open Budget',
                      style: TextStyle(fontSize: 12, color: cs.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: cs.primary.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelReportsCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _buildCard(
      context,
      icon: Icons.flight_takeoff,
      title: 'Travel Reports',
      badge: _recentTravelReports.isNotEmpty
          ? '${_recentTravelReports.length}'
          : null,
      badgeColor: Colors.cyan.shade700,
      footerRoute: '/traveling-reports',
      footerLabel: 'View all travel reports',
      child: _recentTravelReports.isEmpty
          ? _buildEmptyState('No recent travel reports')
          : Column(
              children: _recentTravelReports.take(3).map((item) {
                final status = item['status'] as String? ?? 'draft';
                final name = item['reporterName'] as String? ?? 'Unknown';
                final place = item['placeName'] ?? item['purpose'] ?? 'Trip';
                final end = (item['mileageEnd'] as num?)?.toDouble() ?? 0;
                final start = (item['mileageStart'] as num?)?.toDouble() ?? 0;
                final km = (end - start).clamp(0, double.infinity);
                final meta = _statusLabel(status);
                final statusColor = _statusColor(status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(width: 3, color: statusColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$name – $place',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${km.toStringAsFixed(0)} km',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: meta.bg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              meta.label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: meta.color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─── Administration row-2 ─────────────────────────────────────────────────

  Widget _buildAdministrationRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              _buildHrSubmissionsCard(context),
              const SizedBox(height: 14),
              _buildReportListCard(
                context,
                title: 'Purchase Requisitions',
                icon: Icons.shopping_cart_outlined,
                items: _recentPurchaseReqs,
                footerRoute: '/purchase-requisitions',
                badgeColor: Colors.indigo.shade400,
                isPr: true,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildHrSubmissionsCard(context)),
            const SizedBox(width: 14),
            Expanded(
              child: _buildReportListCard(
                context,
                title: 'Purchase Requisitions',
                icon: Icons.shopping_cart_outlined,
                items: _recentPurchaseReqs,
                footerRoute: '/purchase-requisitions',
                badgeColor: Colors.indigo.shade400,
                isPr: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHrSubmissionsCard(BuildContext context) {
    return _buildCard(
      context,
      icon: Icons.person_add_outlined,
      title: 'HR Data Submissions',
      badge: _recentHrSubmissions.isNotEmpty
          ? '${_recentHrSubmissions.length} new'
          : null,
      badgeColor: Colors.orange,
      footerRoute: '/hr/data-submissions',
      footerLabel: 'View all submissions',
      child: _recentHrSubmissions.isEmpty
          ? _buildEmptyState('No recent submissions')
          : Column(
              children: _recentHrSubmissions
                  .map((item) => _buildPersonItem(context, item))
                  .toList(),
            ),
    );
  }

  // ─── Traveling Overview (full width) ──────────────────────────────────────

  Widget _buildTravelingOverview(BuildContext context) {
    final totalKm = _recentTravelReports.fold<double>(0, (acc, d) {
      final end = (d['mileageEnd'] as num?)?.toDouble() ?? 0;
      final start = (d['mileageStart'] as num?)?.toDouble() ?? 0;
      return acc + (end - start).clamp(0, double.infinity);
    });
    final totalPerDiem = _recentTravelReports.fold<double>(
      0,
      (acc, d) => acc + ((d['perDiemTotal'] as num?)?.toDouble() ?? 0),
    );

    return _buildCard(
      context,
      icon: Icons.flight,
      title: 'Mileage & Travel Summary',
      footerRoute: '/traveling-reports',
      footerLabel: 'View all travel reports',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final statsGrid = GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _buildTravelStatTile(
                context,
                value: '${totalKm.toStringAsFixed(0)} km',
                label: 'Total KM',
              ),
              _buildTravelStatTile(
                context,
                value: '฿${NumberFormat('#,##0').format(totalPerDiem)}',
                label: 'Per Diem',
              ),
              _buildTravelStatTile(
                context,
                value: '${_recentTravelReports.length}',
                label: 'Recent Trips',
              ),
              _buildTravelStatTile(
                context,
                value: '$_travelPending',
                label: 'Pending',
              ),
            ],
          );
          final tripList = Column(
            children: _recentTravelReports
                .take(3)
                .map((item) => _buildTravelItem(context, item))
                .toList(),
          );

          if (constraints.maxWidth < 600) {
            return Column(
              children: [statsGrid, const SizedBox(height: 14), tripList],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: statsGrid),
              const SizedBox(width: 14),
              Expanded(child: tripList),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTravelStatTile(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.07),
            cs.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: cs.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelItem(BuildContext context, Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final status = item['status'] as String? ?? 'draft';
    final name = item['reporterName'] as String? ?? 'Unknown';
    final place = item['placeName'] ?? item['purpose'] ?? 'Trip';
    final end = (item['mileageEnd'] as num?)?.toDouble() ?? 0;
    final start = (item['mileageStart'] as num?)?.toDouble() ?? 0;
    final km = (end - start).clamp(0, double.infinity);
    final perDiem = (item['perDiemTotal'] as num?)?.toDouble() ?? 0;
    final meta = _statusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 3, color: _statusColor(status)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name – $place',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${km.toStringAsFixed(0)} km · ฿${NumberFormat('#,##0').format(perDiem)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: meta.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: meta.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── People Management row-2 ──────────────────────────────────────────────

  Widget _buildPeopleManagement(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              _buildStudentManagementCard(context),
              const SizedBox(height: 14),
              _buildStaffDirectoryCard(context),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildStudentManagementCard(context)),
            const SizedBox(width: 14),
            Expanded(child: _buildStaffDirectoryCard(context)),
          ],
        );
      },
    );
  }

  Widget _buildStudentManagementCard(BuildContext context) {
    return _buildCard(
      context,
      icon: Icons.school_outlined,
      title: 'Student Management',
      badge: '$_pendingStudentReports due',
      badgeColor: Colors.blue,
      footerRoute: '/student-labor-dashboard',
      footerLabel: 'View all students',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  context,
                  value: '${_recentStudents.length}',
                  label: 'Active',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  context,
                  value: '$_pendingStudentReports',
                  label: 'Reports Due',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  context,
                  value:
                      '${_recentStudents.where((d) => d['status'] == 'submitted').length}',
                  label: 'Submitted',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._recentStudents.map(
            (item) => _buildPersonItem(context, {
              'name': item['studentName'] ?? item['name'] ?? 'Student',
              'role': item['month'] ?? 'Monthly Report',
              'status': item['status'] ?? 'draft',
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffDirectoryCard(BuildContext context) {
    return _buildCard(
      context,
      icon: Icons.badge_outlined,
      title: 'Staff Directory',
      badge: '$_staffCount staff',
      badgeColor: Theme.of(context).colorScheme.primary,
      footerRoute: '/admin/staff',
      footerLabel: 'View all staff',
      child: _recentStaff.isEmpty
          ? _buildEmptyState('No staff records')
          : Column(
              children: _recentStaff
                  .map((item) => _buildStaffItem(context, item))
                  .toList(),
            ),
    );
  }

  Widget _buildStaffItem(BuildContext context, Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final name = item['fullName'] as String? ?? 'Unknown';
    final position = item['position'] as String? ?? '';
    final role = item['role'] as String? ?? 'staff';
    final initials = _initials(name);
    final avatarColors = [
      cs.primary,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.cyan.shade700,
    ];
    final colorIdx = name.isNotEmpty
        ? name.codeUnitAt(0) % avatarColors.length
        : 0;

    String roleLabel;
    Color roleBg;
    Color roleColor;
    if (role == 'admin') {
      roleLabel = 'Admin';
      roleBg = Colors.amber.shade50;
      roleColor = Colors.amber.shade800;
    } else if (role == 'finance') {
      roleLabel = 'Finance';
      roleBg = cs.primaryContainer.withValues(alpha: 0.4);
      roleColor = cs.primary;
    } else if (role == 'manager') {
      roleLabel = 'Manager';
      roleBg = cs.primaryContainer.withValues(alpha: 0.4);
      roleColor = cs.primary;
    } else {
      roleLabel = 'Staff';
      roleBg = Colors.green.shade50;
      roleColor = Colors.green.shade700;
    }

    final avatarColor = avatarColors[colorIdx];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [avatarColor, avatarColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  position,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: roleBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: roleColor,
              ),
            ),
          ),
        ],
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

  // ─── Shared item builders ─────────────────────────────────────────────────

  Widget _buildPersonItem(BuildContext context, Map<String, dynamic> item) {
    final cs = Theme.of(context).colorScheme;
    final name =
        item['name'] as String? ??
        item['submittedByName'] as String? ??
        'Unknown';
    final role =
        item['role'] as String? ?? item['submissionType'] as String? ?? 'Staff';
    final initials = _initials(name);
    final avatarColors = [
      cs.primary,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
    ];
    final colorIdx = name.isNotEmpty
        ? name.codeUnitAt(0) % avatarColors.length
        : 0;
    final avatarColor = avatarColors[colorIdx];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [avatarColor, avatarColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Staff',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.07),
            cs.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: cs.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static ({String label, Color color, Color bg}) _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return (
          label: 'Approved',
          color: Colors.green.shade700,
          bg: Colors.green.shade50,
        );
      case 'submitted':
        return (
          label: 'Pending',
          color: Colors.amber.shade800,
          bg: Colors.amber.shade50,
        );
      case 'underReview':
        return (
          label: 'Review',
          color: Colors.purple.shade700,
          bg: Colors.purple.shade50,
        );
      case 'closed':
        return (
          label: 'Closed',
          color: Colors.grey.shade700,
          bg: Colors.grey.shade100,
        );
      case 'rejected':
        return (
          label: 'Rejected',
          color: Colors.red.shade700,
          bg: Colors.red.shade50,
        );
      case 'disbursed':
        return (
          label: 'Disbursed',
          color: Colors.teal.shade700,
          bg: Colors.teal.shade50,
        );
      case 'settled':
        return (
          label: 'Settled',
          color: Colors.green.shade700,
          bg: Colors.green.shade50,
        );
      case 'cancelled':
        return (
          label: 'Cancelled',
          color: Colors.grey.shade600,
          bg: Colors.grey.shade100,
        );
      default:
        return (
          label: 'Draft',
          color: Colors.blue.shade700,
          bg: Colors.blue.shade50,
        );
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'settled':
        return Colors.green;
      case 'submitted':
        return Colors.amber;
      case 'underReview':
        return Colors.purple;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'disbursed':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(date);
  }
}
