import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';
import '../../models/petty_cash_report.dart';
import '../../models/project_report.dart';
import '../../utils/responsive_helper.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({
    super.key,
    this.initialReportType,
  });

  final String? initialReportType; // 'petty_cash', 'advance_settlement', 'project'

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

// View mode options for reports display
enum ReportsViewMode {
  card, // Card/Grid view
  tableRow, // Table view - all reports in one table
  tableCategory, // Table view - reports grouped by category
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  static const _viewModePrefsKey = 'reports_view_mode';
  ReportStatus? _filterStatus;
  String _searchQuery = '';
  String _reportType = 'all'; // 'all', 'petty_cash', 'advance_settlement', 'project'
  ReportsViewMode _viewMode = ReportsViewMode.card;
  final Set<String> _expandedCardIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialReportType != null) {
      _reportType = widget.initialReportType!;
    }
    _loadViewModePreference();
    // Load reports when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReports();
      context.read<ProjectReportProvider>().loadProjectReports();
    });
  }

  Future<void> _loadViewModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_viewModePrefsKey);
    if (stored == null) return;

    ReportsViewMode? mode;
    switch (stored) {
      case 'card':
        mode = ReportsViewMode.card;
        break;
      case 'tableRow':
        mode = ReportsViewMode.tableRow;
        break;
      case 'tableCategory':
        mode = ReportsViewMode.tableCategory;
        break;
    }

    if (mode != null && mounted) {
      setState(() {
        _viewMode = mode!;
      });
    }
  }

  Future<void> _saveViewModePreference(ReportsViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModePrefsKey, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reportProvider = context.watch<ReportProvider>();
    final projectReportProvider = context.watch<ProjectReportProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final user = authProvider.currentUser;

    // Combine both types of reports into a unified list
    List<dynamic> allReports = [];

    if (_reportType == 'all' || _reportType == 'project') {
      allReports.addAll(projectReportProvider.projectReports);
    }

    if (_reportType != 'project') {
      final pettyCashReports = reportProvider.reports.where((report) {
        if (_reportType == 'petty_cash') {
          return report.reportType == 'petty_cash';
        }
        if (_reportType == 'advance_settlement') {
          return report.reportType == 'advance_settlement';
        }
        return true;
      });
      allReports.addAll(pettyCashReports);
    }

    var reports = allReports;

    // Filter by user if not admin or manager
    if (!authProvider.canViewAllReports()) {
      reports = reports.where((r) => r.custodianId == user?.id).toList();
    }

    // Apply status filter
    if (_filterStatus != null) {
      reports = reports.where((r) => r.statusEnum == _filterStatus).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      reports = reports.where((r) {
        final reportNumber = r.reportNumber.toLowerCase();
        final custodianName = r.custodianName.toLowerCase();
        final searchLower = _searchQuery.toLowerCase();

        // Handle different report types
        if (r is PettyCashReport) {
          return reportNumber.contains(searchLower) ||
              r.department.toLowerCase().contains(searchLower) ||
              custodianName.contains(searchLower);
        } else if (r is ProjectReport) {
          return reportNumber.contains(searchLower) ||
              r.projectName.toLowerCase().contains(searchLower) ||
              custodianName.contains(searchLower);
        }
        return false;
      }).toList();
    }

    // Sort by date (newest first)
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildPageHeader(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildFilters(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: reports.isEmpty
                      ? _buildEmptyState()
                      : _buildReportsContent(
                          reports,
                          transactionProvider.transactions,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top action bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back/Home button
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Dashboard',
                onPressed: () => context.go('/admin-hub'),
              ),
              // Action buttons
              Row(
                children: [
                  // View mode selector
                  _buildViewModeButton(),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.add_circle_outline,
                    tooltip: 'Create New Report',
                    onPressed: () => context.go('/reports/new'),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          // Content row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports Overview',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMobile
                          ? 'Manage your reports'
                          : 'Manage and track all your reports',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
            ],
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

  Widget _buildViewModeButton() {
    return PopupMenuButton<ReportsViewMode>(
      tooltip: 'Change View',
      onSelected: (ReportsViewMode mode) {
        setState(() {
          _viewMode = mode;
        });
        _saveViewModePreference(mode);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getViewModeIcon(), color: Colors.white, size: 20),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ReportsViewMode.card,
          child: Row(
            children: [
              Icon(
                Icons.grid_view,
                size: 20,
                color: _viewMode == ReportsViewMode.card
                    ? Colors.blue
                    : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Text(
                'Card View',
                style: TextStyle(
                  fontWeight: _viewMode == ReportsViewMode.card
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _viewMode == ReportsViewMode.card ? Colors.blue : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: ReportsViewMode.tableRow,
          child: Row(
            children: [
              Icon(
                Icons.table_rows_outlined,
                size: 20,
                color: _viewMode == ReportsViewMode.tableRow
                    ? Colors.blue
                    : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Text(
                'Table View (Row)',
                style: TextStyle(
                  fontWeight: _viewMode == ReportsViewMode.tableRow
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _viewMode == ReportsViewMode.tableRow
                      ? Colors.blue
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: ReportsViewMode.tableCategory,
          child: Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 20,
                color: _viewMode == ReportsViewMode.tableCategory
                    ? Colors.blue
                    : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Text(
                'Table View (Category)',
                style: TextStyle(
                  fontWeight: _viewMode == ReportsViewMode.tableCategory
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _viewMode == ReportsViewMode.tableCategory
                      ? Colors.blue
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: isMobile
                  ? 'Search reports...'
                  : 'Search by report number, report name, or custodian...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 12 : 16,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          // Type filter - wrap on mobile
          if (isMobile) ...[
            Text(
              'Type:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeFilterChip('All', 'all'),
                _buildTypeFilterChip('Petty Cash', 'petty_cash'),
                _buildTypeFilterChip('Advance Settlement', 'advance_settlement'),
                _buildTypeFilterChip('Projects', 'project'),
              ],
            ),
          ] else
            Row(
              children: [
                Text(
                  'Type: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                _buildTypeFilterChip('All Reports', 'all'),
                const SizedBox(width: 8),
                _buildTypeFilterChip('Petty Cash', 'petty_cash'),
                const SizedBox(width: 8),
                _buildTypeFilterChip('Advance Settlement', 'advance_settlement'),
                const SizedBox(width: 8),
                _buildTypeFilterChip('Projects', 'project'),
              ],
            ),
          const SizedBox(height: 16),
          // Status filter - wrap on mobile
          if (isMobile) ...[
            Text(
              'Status:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', null),
                  const SizedBox(width: 6),
                  _buildFilterChip('Draft', ReportStatus.draft),
                  const SizedBox(width: 6),
                  _buildFilterChip('Submitted', ReportStatus.submitted),
                  const SizedBox(width: 6),
                  _buildFilterChip('Review', ReportStatus.underReview),
                  const SizedBox(width: 6),
                  _buildFilterChip('Approved', ReportStatus.approved),
                  const SizedBox(width: 6),
                  _buildFilterChip('Closed', ReportStatus.closed),
                ],
              ),
            ),
          ] else
            Row(
              children: [
                Text(
                  'Status: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Draft', ReportStatus.draft),
                const SizedBox(width: 8),
                _buildFilterChip('Submitted', ReportStatus.submitted),
                const SizedBox(width: 8),
                _buildFilterChip('Under Review', ReportStatus.underReview),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', ReportStatus.approved),
                const SizedBox(width: 8),
                _buildFilterChip('Closed', ReportStatus.closed),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ReportStatus? status) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? status : null;
        });
      },
      selectedColor: Colors.blue.shade600,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildTypeFilterChip(String label, String type) {
    final isSelected = _reportType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _reportType = type;
        });
      },
      selectedColor: Colors.blue.shade600,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTight = constraints.maxWidth < 360;
          return SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: isTight ? 64 : 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports found',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTight ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first report to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTight ? 14 : 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/reports/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper method to get the icon for current view mode
  IconData _getViewModeIcon() {
    switch (_viewMode) {
      case ReportsViewMode.card:
        return Icons.grid_view;
      case ReportsViewMode.tableRow:
        return Icons.table_rows_outlined;
      case ReportsViewMode.tableCategory:
        return Icons.category_outlined;
    }
  }

  // Helper method to build the appropriate view based on selected mode
  Widget _buildReportsContent(
    List<dynamic> reports,
    List<Transaction> transactions,
  ) {
    switch (_viewMode) {
      case ReportsViewMode.card:
        return _buildReportsList(reports, transactions);
      case ReportsViewMode.tableRow:
        return _buildTableViewRow(reports, transactions);
      case ReportsViewMode.tableCategory:
        return _buildTableViewCategory(reports, transactions);
    }
  }

  Widget _buildReportsList(
    List<dynamic> reports,
    List<Transaction> transactions,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card width based on screen size
        // 2 cards per row on wide screens, 1 on narrow
        final isWide = constraints.maxWidth > 800;
        final cardWidth = isWide
            ? (constraints.maxWidth - 16) /
                  2 // 2 cards with 16px gap
            : constraints.maxWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: reports.map((report) {
              final isPettyCash = report is PettyCashReport;

              // Calculate actual expenses from transactions for project reports
              double projectExpenses = 0;
              double projectRemaining = 0;
              if (!isPettyCash) {
                final projectReport = report as ProjectReport;
                final projectTransactions = transactions
                    .where((t) => t.projectId == projectReport.id)
                    .toList();
                projectExpenses = projectTransactions
                    .where(
                      (t) =>
                          t.statusEnum == TransactionStatus.approved ||
                          t.statusEnum == TransactionStatus.processed,
                    )
                    .fold<double>(0.0, (sum, t) => sum + t.amount);
                projectRemaining = projectReport.budget - projectExpenses;
              }

              return SizedBox(
                width: cardWidth,
                child: _buildReportCard(
                  report: report,
                  isPettyCash: isPettyCash,
                  projectExpenses: projectExpenses,
                  projectRemaining: projectRemaining,
                  reportId: report.id,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTableViewCategory(
    List<dynamic> reports,
    List<Transaction> transactions,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    // Separate reports by category
    final pettyCashReports = reports
        .whereType<PettyCashReport>()
        .where((report) => report.reportType == 'petty_cash')
        .toList();
    final advanceSettlementReports = reports
        .whereType<PettyCashReport>()
        .where((report) => report.reportType == 'advance_settlement')
        .toList();
    final projectReports = reports.whereType<ProjectReport>().toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Petty Cash category
          if (pettyCashReports.isNotEmpty) ...[
            _buildCategoryHeader(
              'Petty Cash Reports',
              Icons.account_balance_wallet,
              Colors.blue,
              pettyCashReports.length,
            ),
            const SizedBox(height: 8),
            _buildDataTable(
              reports: pettyCashReports,
              isPettyCash: true,
              headerColor: Colors.blue,
              transactions: transactions,
              dateFormat: dateFormat,
              currencyFormat: currencyFormat,
            ),
            const SizedBox(height: 24),
          ],
          // Advance Settlement category
          if (advanceSettlementReports.isNotEmpty) ...[
            _buildCategoryHeader(
              'Advance Settlement Reports',
              Icons.request_page,
              Colors.orange,
              advanceSettlementReports.length,
            ),
            const SizedBox(height: 8),
            _buildDataTable(
              reports: advanceSettlementReports,
              isPettyCash: true,
              headerColor: Colors.orange,
              transactions: transactions,
              dateFormat: dateFormat,
              currencyFormat: currencyFormat,
            ),
            const SizedBox(height: 24),
          ],
          // Project category
          if (projectReports.isNotEmpty) ...[
            _buildCategoryHeader(
              'Project Reports',
              Icons.folder_special,
              Colors.green,
              projectReports.length,
            ),
            const SizedBox(height: 8),
            _buildDataTable(
              reports: projectReports,
              isPettyCash: false,
              headerColor: Colors.green,
              transactions: transactions,
              dateFormat: dateFormat,
              currencyFormat: currencyFormat,
            ),
          ],
        ],
      ),
    );
  }

  // Table view with all reports in a single expandable list (Row mode)
  Widget _buildTableViewRow(
    List<dynamic> reports,
    List<Transaction> transactions,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MM/dd/yy');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: reports.map((report) {
          final isPettyCash = report is PettyCashReport;
          double expenses = 0;
          double remaining = 0;
          double budget = 0;
          if (isPettyCash) {
            budget = report.openingBalance;
            expenses = report.totalDisbursements;
            remaining = report.closingBalance;
          } else {
            final pr = report as ProjectReport;
            budget = pr.budget;
            final pt = transactions.where((t) => t.projectId == pr.id);
            expenses = pt
                .where((t) =>
                    t.statusEnum == TransactionStatus.approved ||
                    t.statusEnum == TransactionStatus.processed)
                .fold<double>(0.0, (acc, t) => acc + t.amount);
            remaining = pr.budget - expenses;
          }
          return _buildExpandableTableRow(
            report: report,
            isPettyCash: isPettyCash,
            budget: budget,
            expenses: expenses,
            remaining: remaining,
            currencyFormat: currencyFormat,
            dateFormat: dateFormat,
            transactions: transactions,
          );
        }).toList(),
      ),
    );
  }


  Widget _buildCategoryHeader(
    String title,
    IconData icon,
    MaterialColor color,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color.shade700),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Category table — now uses expandable rows instead of horizontal scroll
  Widget _buildDataTable({
    required List<dynamic> reports,
    required bool isPettyCash,
    required MaterialColor headerColor,
    required List<Transaction> transactions,
    required DateFormat dateFormat,
    required NumberFormat currencyFormat,
  }) {
    return Column(
      children: reports.map((report) {
        double expenses = 0;
        double remaining = 0;
        double budget = 0;
        if (isPettyCash) {
          final pc = report as PettyCashReport;
          budget = pc.openingBalance;
          expenses = pc.totalDisbursements;
          remaining = pc.closingBalance;
        } else {
          final pr = report as ProjectReport;
          budget = pr.budget;
          final pt = transactions.where((t) => t.projectId == pr.id);
          expenses = pt
              .where((t) =>
                  t.statusEnum == TransactionStatus.approved ||
                  t.statusEnum == TransactionStatus.processed)
              .fold<double>(0.0, (acc, t) => acc + t.amount);
          remaining = pr.budget - expenses;
        }
        return _buildExpandableTableRow(
          report: report,
          isPettyCash: isPettyCash,
          budget: budget,
          expenses: expenses,
          remaining: remaining,
          currencyFormat: currencyFormat,
          dateFormat: dateFormat,
          transactions: transactions,
        );
      }).toList(),
    );
  }

  Widget _buildExpandableTableRow({
    required dynamic report,
    required bool isPettyCash,
    required double budget,
    required double expenses,
    required double remaining,
    required NumberFormat currencyFormat,
    required DateFormat dateFormat,
    required List<Transaction> transactions,
  }) {
    final isExpanded = _expandedCardIds.contains(report.id);
    final statusColor = _getStatusColor(report.statusEnum);
    final themeColor = isPettyCash ? _getPettyCashTypeColor(report) : Colors.green;
    final typeLabel = isPettyCash ? _getPettyCashTypeLabel(report) : 'Project';
    final pr = isPettyCash ? null : report as ProjectReport;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: InkWell(
        onTap: () => setState(() {
          if (isExpanded) {
            _expandedCardIds.remove(report.id);
          } else {
            _expandedCardIds.add(report.id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Always-visible summary row
              Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: themeColor.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: themeColor.shade200),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: themeColor.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Report number + department/name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.reportNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          isPettyCash
                              ? report.department
                              : pr!.projectName,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      report.statusEnum.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  // Expand icon
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Always-visible financial summary
              Row(
                children: [
                  _buildMiniAmount(
                    isPettyCash ? 'Opening' : 'Budget',
                    '฿${currencyFormat.format(budget)}',
                    Colors.grey.shade700,
                  ),
                  const SizedBox(width: 12),
                  _buildMiniAmount(
                    isPettyCash ? 'Disbursed' : 'Expenses',
                    '฿${currencyFormat.format(expenses)}',
                    Colors.red.shade700,
                  ),
                  const SizedBox(width: 12),
                  _buildMiniAmount(
                    isPettyCash ? 'Balance' : 'Remaining',
                    '฿${currencyFormat.format(remaining)}',
                    remaining >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    bold: true,
                  ),
                ],
              ),
              // Expanded detail section
              if (isExpanded) ...[
                const Divider(height: 12),
                _buildDetailRow(Icons.person, 'Custodian', report.custodianName),
                _buildDetailRow(
                  Icons.calendar_today,
                  'Period',
                  isPettyCash
                      ? '${dateFormat.format(report.periodStart)} – ${dateFormat.format(report.periodEnd)}'
                      : '${dateFormat.format(pr!.startDate)} – ${dateFormat.format(pr.endDate)}',
                ),
                _buildDetailRow(
                  Icons.account_balance,
                  isPettyCash ? 'Opening' : 'Budget',
                  '฿${currencyFormat.format(budget)}',
                ),
                _buildDetailRow(
                  Icons.payments,
                  isPettyCash ? 'Disbursed' : 'Expenses',
                  '฿${currencyFormat.format(expenses)}',
                  valueColor: Colors.red.shade700,
                ),
                _buildDetailRow(
                  Icons.account_balance_wallet,
                  isPettyCash ? 'Balance' : 'Remaining',
                  '฿${currencyFormat.format(remaining)}',
                  valueColor: remaining >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                ),
                if (isPettyCash && report.purpose != null && report.purpose.isNotEmpty)
                  _buildDetailRow(Icons.info_outline, 'Purpose', report.purpose),
                if (isPettyCash && report.notes != null && report.notes.isNotEmpty)
                  _buildDetailRow(Icons.notes, 'Notes', report.notes),
                if (!isPettyCash && pr!.description != null && pr.description!.isNotEmpty)
                  _buildDetailRow(Icons.description, 'Description', pr.description!),
                const SizedBox(height: 6),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        if (isPettyCash) {
                          context.go('/reports/${report.id}');
                        } else {
                          context.go('/project-reports/${report.id}');
                        }
                      },
                      icon: const Icon(Icons.visibility, size: 15),
                      label: const Text('View'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (report.statusEnum == ReportStatus.draft)
                      TextButton.icon(
                        onPressed: () => _submitReport(report, isPettyCash),
                        icon: const Icon(Icons.send, size: 15),
                        label: const Text('Submit'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => _deleteReport(report, isPettyCash),
                      icon: const Icon(Icons.delete, size: 15),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required dynamic report,
    required bool isPettyCash,
    required double projectExpenses,
    required double projectRemaining,
    required String reportId,
  }) {
    final isExpanded = _expandedCardIds.contains(reportId);
    final pr = isPettyCash ? null : report as ProjectReport;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final statusColor = _getStatusColor(report.statusEnum);
    final statusIcon = _getStatusIcon(report.statusEnum);
    final themeColor = isPettyCash
        ? _getPettyCashTypeColor(report)
        : Colors.green;
    final reportTypeLabel = isPettyCash
        ? _getPettyCashTypeLabel(report)
        : 'Project';
    final reportTypeIcon = isPettyCash
        ? _getPettyCashTypeIcon(report)
        : Icons.folder_special;

    return Container(
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
      child: InkWell(
        onTap: () {
          if (isPettyCash) {
            context.go('/reports/${report.id}');
          } else {
            context.go('/project-reports/${report.id}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with Icon, Report Number, Date and Status
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [themeColor.shade400, themeColor.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      reportTypeIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: themeColor.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                reportTypeLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                report.reportNumber,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateFormat.format(report.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 3),
                        Text(
                          report.statusEnum.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // Report Details - Compact 2 column layout
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isPettyCash ? Icons.business : Icons.folder,
                          size: 16,
                          color: themeColor.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isPettyCash
                                ? report.department
                                : (report as ProjectReport).projectName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            report.custodianName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isPettyCash
                          ? '${DateFormat('MMM d').format(report.periodStart)} - ${DateFormat('MMM d, y').format(report.periodEnd)}'
                          : '${DateFormat('MMM d').format((report as ProjectReport).startDate)} - ${DateFormat('MMM d, y').format(report.endDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Amount Summary Box - Compact
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: themeColor.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    final children = [
                      _buildAmountColumn(
                        isPettyCash ? 'Opening' : 'Budget',
                        '฿${currencyFormat.format(isPettyCash ? report.openingBalance : (report as ProjectReport).budget)}',
                        Icons.account_balance,
                        themeColor,
                      ),
                      _buildAmountColumn(
                        isPettyCash ? 'Disbursed' : 'Expenses',
                        '฿${currencyFormat.format(isPettyCash ? report.totalDisbursements : projectExpenses)}',
                        Icons.payments,
                        Colors.red,
                      ),
                      _buildAmountColumn(
                        isPettyCash ? 'Balance' : 'Remaining',
                        '฿${currencyFormat.format(isPettyCash ? report.closingBalance : projectRemaining)}',
                        Icons.account_balance_wallet,
                        Colors.green,
                        isTotal: true,
                      ),
                    ];

                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: children.sublist(0, 2),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: children[2],
                          ),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        children[0],
                        Container(
                          width: 1,
                          height: 32,
                          color: themeColor.shade200,
                        ),
                        children[1],
                        Container(
                          width: 1,
                          height: 32,
                          color: themeColor.shade200,
                        ),
                        children[2],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Expand/collapse toggle
              InkWell(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedCardIds.remove(reportId);
                  } else {
                    _expandedCardIds.add(reportId);
                  }
                }),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isExpanded ? 'Hide Details' : 'Show All Details',
                        style: TextStyle(
                          fontSize: 11,
                          color: themeColor.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: themeColor.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              // Expanded detail section
              if (isExpanded) ...[
                const Divider(height: 16),
                _buildDetailRow(Icons.tag, 'Report ID', report.id),
                if (isPettyCash) ...[
                  _buildDetailRow(
                    Icons.category,
                    'Type',
                    report.reportType == 'advance_settlement'
                        ? 'Advance Settlement'
                        : 'Petty Cash',
                  ),
                  if (report.purpose != null && report.purpose.isNotEmpty)
                    _buildDetailRow(Icons.info_outline, 'Purpose', report.purpose),
                  if (report.companyName != null && report.companyName.isNotEmpty)
                    _buildDetailRow(Icons.business, 'Company', report.companyName),
                  if (report.advanceTakenDate != null)
                    _buildDetailRow(
                      Icons.event,
                      'Advance Date',
                      dateFormat.format(report.advanceTakenDate),
                    ),
                  _buildDetailRow(
                    Icons.account_balance_wallet,
                    'Cash on Hand',
                    '฿${currencyFormat.format(report.cashOnHand)}',
                  ),
                  _buildDetailRow(
                    Icons.compare_arrows,
                    'Variance',
                    '฿${currencyFormat.format(report.variance)}',
                    valueColor: report.variance.abs() > 0.01
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                  if (report.notes != null && report.notes.isNotEmpty)
                    _buildDetailRow(Icons.notes, 'Notes', report.notes),
                ] else ...[
                  _buildDetailRow(Icons.folder, 'Report Name', pr!.reportName),
                  if (pr.language != null && pr.language!.isNotEmpty)
                    _buildDetailRow(Icons.language, 'Language', pr.language!),
                  if (pr.description != null && pr.description!.isNotEmpty)
                    _buildDetailRow(Icons.description, 'Description', pr.description!),
                  _buildDetailRow(
                    Icons.show_chart,
                    'Budget Used',
                    '${projectExpenses > 0 ? (projectExpenses / pr.budget * 100).toStringAsFixed(1) : '0.0'}%',
                    valueColor: projectExpenses / pr.budget > 0.9
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ],
                if (report.updatedAt != null)
                  _buildDetailRow(
                    Icons.update,
                    'Last Updated',
                    dateFormat.format(report.updatedAt),
                  ),
              ],
              const SizedBox(height: 8),
              // Action Buttons Row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      if (isPettyCash) {
                        context.go('/reports/${report.id}');
                      } else {
                        context.go('/project-reports/${report.id}');
                      }
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                  if (report.statusEnum == ReportStatus.draft)
                    TextButton.icon(
                      onPressed: () => _submitReport(report, isPettyCash),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Submit'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _deleteReport(report, isPettyCash),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniAmount(String label, String value, Color color, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(
    String label,
    String amount,
    IconData icon,
    MaterialColor color, {
    bool isTotal = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 12 : 11,
            fontWeight: FontWeight.bold,
            color: isTotal ? color.shade700 : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Colors.grey;
      case ReportStatus.submitted:
        return Colors.orange;
      case ReportStatus.underReview:
        return Colors.blue;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.closed:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Icons.edit_document;
      case ReportStatus.submitted:
        return Icons.pending;
      case ReportStatus.underReview:
        return Icons.hourglass_empty;
      case ReportStatus.approved:
        return Icons.check_circle;
      case ReportStatus.closed:
        return Icons.lock;
    }
  }

  String _getPettyCashTypeLabel(PettyCashReport report) {
    switch (report.reportType) {
      case 'advance_settlement':
        return 'Advance Settlement';
      case 'petty_cash':
      default:
        return 'Petty Cash';
    }
  }

  MaterialColor _getPettyCashTypeColor(PettyCashReport report) {
    switch (report.reportType) {
      case 'advance_settlement':
        return Colors.orange;
      case 'petty_cash':
      default:
        return Colors.blue;
    }
  }

  IconData _getPettyCashTypeIcon(PettyCashReport report) {
    switch (report.reportType) {
      case 'advance_settlement':
        return Icons.request_page;
      case 'petty_cash':
      default:
        return Icons.account_balance_wallet;
    }
  }

  Future<void> _submitReport(dynamic report, bool isPettyCash) async {
    try {
      if (isPettyCash) {
        await context.read<ReportProvider>().submitReport(report.id);
      } else {
        await context.read<ProjectReportProvider>().submitProjectReport(
          report.id,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteReport(dynamic report, bool isPettyCash) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete "${report.reportNumber}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        if (isPettyCash) {
          await context.read<ReportProvider>().deleteReport(report.id);
        } else {
          await context.read<ProjectReportProvider>().deleteProjectReport(
            report.id,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Report "${report.reportNumber}" deleted successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
