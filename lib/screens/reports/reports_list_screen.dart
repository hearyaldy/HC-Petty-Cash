import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../models/enums.dart';
import '../../models/petty_cash_report.dart';
import '../../models/project_report.dart';
import '../../utils/constants.dart';
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
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(context),
              const SizedBox(height: 24),
              _buildFilters(),
              const SizedBox(height: 24),
              reports.isEmpty
                  ? _buildEmptyState()
                  : _buildReportsList(reports),
            ],
          ),
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

  Widget _buildReportsList(List<dynamic> reports) {
    return Container(
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
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          final isPettyCash = report is PettyCashReport;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: Colors.grey.shade200,
              ),
              borderRadius: BorderRadius.circular(12),
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isPettyCash
                                            ? [Colors.blue.shade400, Colors.blue.shade600]
                                            : [Colors.green.shade400, Colors.green.shade600],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isPettyCash ? 'Petty Cash' : 'Project',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      report.reportNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isPettyCash
                                    ? report.department
                                    : (report as ProjectReport).projectName,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(report.statusEnum),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            Icons.person,
                            'Custodian',
                            report.custodianName,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            Icons.calendar_today,
                            'Period',
                            isPettyCash
                                ? '${DateFormat('MMM d').format(report.periodStart)} - ${DateFormat('MMM d, y').format(report.periodEnd)}'
                                : '${DateFormat('MMM d').format((report as ProjectReport).startDate)} - ${DateFormat('MMM d, y').format(report.endDate)}',
                          ),
                        ),
                        // Add menu button for edit/delete options
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (String choice) async {
                            if (choice == 'edit') {
                              // Navigate to the appropriate detail screen
                              if (isPettyCash) {
                                context.go('/reports/${report.id}');
                              } else {
                                context.go('/project-reports/${report.id}');
                              }
                            } else if (choice == 'submit') {
                              try {
                                if (isPettyCash) {
                                  await context
                                      .read<ReportProvider>()
                                      .submitReport(report.id);
                                } else {
                                  await context
                                      .read<ProjectReportProvider>()
                                      .submitProjectReport(report.id);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Report submitted successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error submitting report: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } else if (choice == 'approve') {
                              try {
                                if (isPettyCash) {
                                  await context
                                      .read<ReportProvider>()
                                      .approveReport(report.id);
                                } else {
                                  await context
                                      .read<ProjectReportProvider>()
                                      .approveProjectReport(report.id);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Report approved successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error approving report: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } else if (choice == 'close') {
                              try {
                                if (isPettyCash) {
                                  await context
                                      .read<ReportProvider>()
                                      .closeReport(report.id);
                                } else {
                                  await context
                                      .read<ProjectReportProvider>()
                                      .closeProjectReport(report.id);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Report closed successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error closing report: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } else if (choice == 'delete') {
                              // Show confirmation dialog before deleting
                              showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Report'),
                                  content: Text(
                                    'Are you sure you want to delete report ${report.reportNumber}? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          if (isPettyCash) {
                                            await context
                                                .read<ReportProvider>()
                                                .deleteReport(report.id);
                                          } else {
                                            await context
                                                .read<ProjectReportProvider>()
                                                .deleteProjectReport(report.id);
                                          }
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Report deleted successfully',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error deleting report: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                        if (context.mounted) {
                                          Navigator.of(context).pop(true);
                                        }
                                      },
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ).then((confirmed) async {
                                if (confirmed == true && context.mounted) {
                                  // Refresh the list after deletion
                                  await context
                                      .read<ReportProvider>()
                                      .loadReports();
                                  await context
                                      .read<ProjectReportProvider>()
                                      .loadProjectReports();
                                }
                              });
                            }
                          },
                          itemBuilder: (context) {
                            final authProvider = context.read<AuthProvider>();
                            final reportStatus = report.statusEnum;
                            final canApprove = authProvider.canApprove();

                            return [
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              if (reportStatus == ReportStatus.draft)
                                const PopupMenuItem<String>(
                                  value: 'submit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.send,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Submit'),
                                    ],
                                  ),
                                ),
                              if (canApprove &&
                                  (reportStatus == ReportStatus.submitted ||
                                      reportStatus == ReportStatus.underReview))
                                const PopupMenuItem<String>(
                                  value: 'approve',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
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
                              if (canApprove &&
                                  reportStatus == ReportStatus.approved)
                                const PopupMenuItem<String>(
                                  value: 'close',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lock,
                                        size: 18,
                                        color: Colors.purple,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Close',
                                        style: TextStyle(color: Colors.purple),
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
                                      size: 18,
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
                            ];
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAmountItem(
                            isPettyCash ? 'Opening' : 'Budget',
                            isPettyCash
                                ? report.openingBalance
                                : (report as ProjectReport).budget,
                            isPettyCash ? Colors.blue : Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildAmountItem(
                            isPettyCash ? 'Disbursements' : 'Expenses',
                            isPettyCash
                                ? report.totalDisbursements
                                : (report as ProjectReport).totalExpenses,
                            Colors.red,
                          ),
                        ),
                        Expanded(
                          child: _buildAmountItem(
                            isPettyCash ? 'Balance' : 'Remaining',
                            isPettyCash
                                ? report.closingBalance
                                : (report as ProjectReport).remainingBudget,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (status) {
      case ReportStatus.draft:
        backgroundColor = Colors.grey.shade600;
        break;
      case ReportStatus.submitted:
        backgroundColor = Colors.blue.shade600;
        break;
      case ReportStatus.underReview:
        backgroundColor = Colors.orange.shade600;
        break;
      case ReportStatus.approved:
        backgroundColor = Colors.green.shade600;
        break;
      case ReportStatus.closed:
        backgroundColor = Colors.purple.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountItem(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
