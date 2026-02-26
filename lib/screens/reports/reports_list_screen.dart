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
            color: Colors.blue.withOpacity(0.3),
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
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
            color: Colors.white.withOpacity(0.15),
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
          color: Colors.white.withOpacity(0.15),
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
            color: Colors.black.withOpacity(0.05),
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
            color: Colors.black.withOpacity(0.05),
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

  // Table view with all reports in a single table (Row mode)
  Widget _buildTableViewRow(
    List<dynamic> reports,
    List<Transaction> transactions,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columnSpacing: 20,
              horizontalMargin: 16,
              columns: const [
                DataColumn(
                  label: Text(
                    'Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Report #',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Name/Department',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Custodian',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Period',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Budget/Opening',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Expenses/Disbursed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Balance/Remaining',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: reports.map((report) {
                final isPettyCash = report is PettyCashReport;
                double expenses = 0;
                double remaining = 0;
                double budget = 0;

                if (isPettyCash) {
                  final pc = report;
                  budget = pc.openingBalance;
                  expenses = pc.totalDisbursements;
                  remaining = pc.closingBalance;
                } else {
                  final pr = report as ProjectReport;
                  budget = pr.budget;
                  final projectTransactions = transactions
                      .where((t) => t.projectId == pr.id)
                      .toList();
                  expenses = projectTransactions
                      .where(
                        (t) =>
                            t.statusEnum == TransactionStatus.approved ||
                            t.statusEnum == TransactionStatus.processed,
                      )
                      .fold<double>(0.0, (sum, t) => sum + t.amount);
                  remaining = pr.budget - expenses;
                }

                final statusColor = _getStatusColor(report.statusEnum);
                final themeColor = isPettyCash
                    ? _getPettyCashTypeColor(report)
                    : Colors.green;
                final reportTypeLabel = isPettyCash
                    ? _getPettyCashTypeLabel(report)
                    : 'Project';
                final reportTypeIcon = isPettyCash
                    ? _getPettyCashTypeIcon(report)
                    : Icons.folder_special;

                return DataRow(
                  onSelectChanged: (_) {
                    if (isPettyCash) {
                      context.go('/reports/${report.id}');
                    } else {
                      context.go('/project-reports/${report.id}');
                    }
                  },
                  cells: [
                    // Type column with colored badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: themeColor.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: themeColor.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              reportTypeIcon,
                              size: 14,
                              color: themeColor.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reportTypeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: themeColor.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Report number
                    DataCell(
                      Text(
                        report.reportNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () {
                        if (isPettyCash) {
                          context.go('/reports/${report.id}');
                        } else {
                          context.go('/project-reports/${report.id}');
                        }
                      },
                    ),
                    // Name/Department
                    DataCell(
                      Text(
                        isPettyCash
                            ? (report).department
                            : (report as ProjectReport).projectName,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    // Custodian
                    DataCell(
                      Text(
                        report.custodianName,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    // Period
                    DataCell(
                      Text(
                        isPettyCash
                            ? '${DateFormat('MM/dd/yy').format((report).periodStart)} - ${DateFormat('MM/dd/yy').format(report.periodEnd)}'
                            : '${DateFormat('MM/dd/yy').format((report as ProjectReport).startDate)} - ${DateFormat('MM/dd/yy').format(report.endDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    // Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          report.statusEnum.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    // Budget/Opening
                    DataCell(
                      Text(
                        currencyFormat.format(budget),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    // Expenses/Disbursed
                    DataCell(
                      Text(
                        currencyFormat.format(expenses),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    // Balance/Remaining
                    DataCell(
                      Text(
                        currencyFormat.format(remaining),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: remaining >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.visibility,
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                            tooltip: 'View',
                            onPressed: () {
                              if (isPettyCash) {
                                context.go('/reports/${report.id}');
                              } else {
                                context.go('/project-reports/${report.id}');
                              }
                            },
                          ),
                          if (report.statusEnum == ReportStatus.draft)
                            IconButton(
                              icon: Icon(
                                Icons.send,
                                size: 18,
                                color: Colors.orange.shade700,
                              ),
                              tooltip: 'Submit',
                              onPressed: () =>
                                  _submitReport(report, isPettyCash),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red.shade700,
                            ),
                            tooltip: 'Delete',
                            onPressed: () => _deleteReport(report, isPettyCash),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
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

  Widget _buildDataTable({
    required List<dynamic> reports,
    required bool isPettyCash,
    required MaterialColor headerColor,
    required List<Transaction> transactions,
    required DateFormat dateFormat,
    required NumberFormat currencyFormat,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(
              headerColor.shade50,
            ),
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: [
              const DataColumn(
                label: Text(
                  'Report #',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  isPettyCash ? 'Department' : 'Project Name',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (!isPettyCash)
                const DataColumn(
                  label: Text(
                    'Language',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const DataColumn(
                label: Text(
                  'Custodian',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const DataColumn(
                label: Text(
                  'Period',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const DataColumn(
                label: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  isPettyCash ? 'Opening' : 'Budget',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  isPettyCash ? 'Disbursed' : 'Expenses',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  isPettyCash ? 'Balance' : 'Remaining',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
              const DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: reports.map((report) {
              double expenses = 0;
              double remaining = 0;

              if (isPettyCash) {
                final pc = report as PettyCashReport;
                expenses = pc.totalDisbursements;
                remaining = pc.closingBalance;
              } else {
                final pr = report as ProjectReport;
                final projectTransactions = transactions
                    .where((t) => t.projectId == pr.id)
                    .toList();
                expenses = projectTransactions
                    .where(
                      (t) =>
                          t.statusEnum == TransactionStatus.approved ||
                          t.statusEnum == TransactionStatus.processed,
                    )
                    .fold<double>(0.0, (sum, t) => sum + t.amount);
                remaining = pr.budget - expenses;
              }

              final statusColor = _getStatusColor(report.statusEnum);

              return DataRow(
                onSelectChanged: (_) {
                  if (isPettyCash) {
                    context.go('/reports/${report.id}');
                  } else {
                    context.go('/project-reports/${report.id}');
                  }
                },
                cells: [
                  DataCell(
                    Text(
                      report.reportNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      if (isPettyCash) {
                        context.go('/reports/${report.id}');
                      } else {
                        context.go('/project-reports/${report.id}');
                      }
                    },
                  ),
                  DataCell(
                    Text(
                      isPettyCash
                          ? (report as PettyCashReport).department
                          : (report as ProjectReport).projectName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (!isPettyCash)
                    DataCell(
                      Text(
                        (report as ProjectReport).language ?? '-',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  DataCell(
                    Text(
                      report.custodianName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      isPettyCash
                          ? '${DateFormat('MM/dd/yy').format((report as PettyCashReport).periodStart)} - ${DateFormat('MM/dd/yy').format(report.periodEnd)}'
                          : '${DateFormat('MM/dd/yy').format((report as ProjectReport).startDate)} - ${DateFormat('MM/dd/yy').format(report.endDate)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        report.statusEnum.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormat.format(
                        isPettyCash
                            ? (report as PettyCashReport).openingBalance
                            : (report as ProjectReport).budget,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormat.format(expenses),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormat.format(remaining),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: remaining >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.visibility,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          tooltip: 'View',
                          onPressed: () {
                            if (isPettyCash) {
                              context.go('/reports/${report.id}');
                            } else {
                              context.go('/project-reports/${report.id}');
                            }
                          },
                        ),
                        if (report.statusEnum == ReportStatus.draft)
                          IconButton(
                            icon: Icon(
                              Icons.send,
                              size: 18,
                              color: Colors.orange.shade700,
                            ),
                            tooltip: 'Submit',
                            onPressed: () => _submitReport(report, isPettyCash),
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                          tooltip: 'Delete',
                          onPressed: () => _deleteReport(report, isPettyCash),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
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
  }) {
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
            color: Colors.grey.withOpacity(0.1),
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
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
              const SizedBox(height: 16),
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
