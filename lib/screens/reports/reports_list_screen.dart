import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  ReportStatus? _filterStatus;
  String _searchQuery = '';
  String _reportType = 'all'; // 'all', 'petty_cash', 'project'

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reportProvider = context.watch<ReportProvider>();
    final projectReportProvider = context.watch<ProjectReportProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final user = authProvider.currentUser;

    // Combine both types of reports into a unified list
    List<dynamic> allReports = [];

    if (_reportType == 'all' || _reportType == 'petty_cash') {
      allReports.addAll(reportProvider.reports);
    }

    if (_reportType == 'all' || _reportType == 'project') {
      allReports.addAll(projectReportProvider.projectReports);
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
      appBar: AppBar(
        elevation: 0,
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.go('/reports/new'),
            tooltip: 'Create New Report',
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context),
            const SizedBox(height: 24),
            _buildFilters(),
            const SizedBox(height: 24),
            Expanded(
              child: reports.isEmpty
                  ? _buildEmptyState()
                  : _buildReportsList(reports, transactionProvider.transactions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
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
                  'Reports Overview',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage and track all your reports',
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
            child: const Icon(Icons.description, size: 48, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
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
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by report number, report name, or custodian...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Type: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              _buildTypeFilterChip('All Reports', 'all'),
              const SizedBox(width: 8),
              _buildTypeFilterChip('Petty Cash', 'petty_cash'),
              const SizedBox(width: 8),
              _buildTypeFilterChip('Projects', 'project'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Status: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
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
      padding: const EdgeInsets.all(48),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No reports found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first report to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/reports/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList(List<dynamic> reports, List<Transaction> transactions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card width based on screen size
        // 2 cards per row on wide screens, 1 on narrow
        final isWide = constraints.maxWidth > 800;
        final cardWidth = isWide
            ? (constraints.maxWidth - 16) / 2 // 2 cards with 16px gap
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
                    .where((t) =>
                        t.statusEnum == TransactionStatus.approved ||
                        t.statusEnum == TransactionStatus.processed)
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
    final themeColor = isPettyCash ? Colors.blue : Colors.green;

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
                        colors: [
                          themeColor.shade400,
                          themeColor.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPettyCash ? Icons.account_balance_wallet : Icons.folder_special,
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
                                isPettyCash ? 'Petty Cash' : 'Project',
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
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
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
                        Icon(Icons.person, size: 16, color: Colors.grey.shade600),
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
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isPettyCash
                          ? '${DateFormat('MMM d').format(report.periodStart)} - ${DateFormat('MMM d, y').format(report.periodEnd)}'
                          : '${DateFormat('MMM d').format((report as ProjectReport).startDate)} - ${DateFormat('MMM d, y').format(report.endDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Amount Summary Box - Compact
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: themeColor.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAmountColumn(
                      isPettyCash ? 'Opening' : 'Budget',
                      '฿${currencyFormat.format(isPettyCash ? report.openingBalance : (report as ProjectReport).budget)}',
                      Icons.account_balance,
                      themeColor,
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: themeColor.shade200,
                    ),
                    _buildAmountColumn(
                      isPettyCash ? 'Disbursed' : 'Expenses',
                      '฿${currencyFormat.format(isPettyCash ? report.totalDisbursements : projectExpenses)}',
                      Icons.payments,
                      Colors.red,
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: themeColor.shade200,
                    ),
                    _buildAmountColumn(
                      isPettyCash ? 'Balance' : 'Remaining',
                      '฿${currencyFormat.format(isPettyCash ? report.closingBalance : projectRemaining)}',
                      Icons.account_balance_wallet,
                      Colors.green,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons Row
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
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                  if (report.statusEnum == ReportStatus.draft) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _submitReport(report, isPettyCash),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Submit'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
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

  Future<void> _submitReport(dynamic report, bool isPettyCash) async {
    try {
      if (isPettyCash) {
        await context.read<ReportProvider>().submitReport(report.id);
      } else {
        await context.read<ProjectReportProvider>().submitProjectReport(report.id);
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
          await context.read<ProjectReportProvider>().deleteProjectReport(report.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report "${report.reportNumber}" deleted successfully'),
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
