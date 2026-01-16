import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/income_report_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/income_report.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class IncomeReportsScreen extends StatefulWidget {
  const IncomeReportsScreen({super.key});

  @override
  State<IncomeReportsScreen> createState() => _IncomeReportsScreenState();
}

class _IncomeReportsScreenState extends State<IncomeReportsScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }

  Future<void> _loadReports() async {
    final provider = context.read<IncomeReportProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      if (authProvider.canApprove()) {
        await provider.loadIncomeReports();
      } else {
        await provider.loadIncomeReportsByUser(user.id);
      }
    }
  }

  List<IncomeReport> _getFilteredReports(List<IncomeReport> reports) {
    switch (_selectedFilter) {
      case 'draft':
        return reports.where((r) => r.status == 'draft').toList();
      case 'submitted':
        return reports.where((r) => r.status == 'submitted').toList();
      case 'approved':
        return reports.where((r) => r.status == 'approved').toList();
      case 'closed':
        return reports.where((r) => r.status == 'closed').toList();
      default:
        return reports;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Income Reports'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Dashboard',
          ),
          TextButton.icon(
            onPressed: () => context.push('/income/new'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'New Report',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Consumer<IncomeReportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredReports = _getFilteredReports(provider.incomeReports);

          return ResponsiveContainer(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: ResponsiveHelper.getScreenPadding(context).copyWith(
                    top: 0,
                    bottom: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Income Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/income/new'),
                        icon: const Icon(Icons.add),
                        label: const Text('New Report'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                    ],
                  ),
                ),
                // Summary Card
                _buildSummaryCard(provider),
                // Filter Chips
                _buildFilterChips(provider),
                // Reports List
                Expanded(
                  child: filteredReports.isEmpty
                      ? _buildEmptyState()
                      : _buildReportsList(filteredReports),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/income/new'),
        backgroundColor: Colors.green.shade600,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
    );
  }

  Widget _buildSummaryCard(IncomeReportProvider provider) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final horizontalPadding = ResponsiveHelper.getScreenPadding(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding.left,
        vertical: 16,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
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
                const Text(
                  'Total Income',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppConstants.currencySymbol}${currencyFormat.format(provider.totalIncomeAllReports)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${provider.incomeReports.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Reports',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(IncomeReportProvider provider) {
    final filters = [
      {'key': 'all', 'label': 'All', 'count': provider.incomeReports.length},
      {'key': 'draft', 'label': 'Draft', 'count': provider.draftReports.length},
      {
        'key': 'submitted',
        'label': 'Submitted',
        'count': provider.submittedReports.length,
      },
      {
        'key': 'approved',
        'label': 'Approved',
        'count': provider.approvedReports.length,
      },
      {
        'key': 'closed',
        'label': 'Closed',
        'count': provider.closedReports.length,
      },
    ];

    final horizontalPadding = ResponsiveHelper.getScreenPadding(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding.left),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('${filter['label']} (${filter['count']})'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
              },
              selectedColor: Colors.green.shade100,
              checkmarkColor: Colors.green.shade700,
              labelStyle: TextStyle(
                color: isSelected ? Colors.green.shade700 : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No income reports found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to create one',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(List<IncomeReport> reports) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MMM dd, yyyy');
    final screenPadding = ResponsiveHelper.getScreenPadding(context);

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: screenPadding.left,
        vertical: 16,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => context.push('/income/${report.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          report.reportName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusChip(report.status),
                          if (report.status == 'draft')
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                              onSelected: (value) => _handleReportAction(value, report),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit Report'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red, size: 20),
                                      SizedBox(width: 8),
                                      Text('Delete Report', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.reportNumber,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Income',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${AppConstants.currencySymbol}${currencyFormat.format(report.totalIncome)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
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

  void _handleReportAction(String action, IncomeReport report) {
    switch (action) {
      case 'edit':
        _showEditReportDialog(report);
        break;
      case 'delete':
        _showDeleteReportDialog(report);
        break;
    }
  }

  void _showEditReportDialog(IncomeReport report) {
    final formKey = GlobalKey<FormState>();
    final reportNameController = TextEditingController(text: report.reportName);
    final descriptionController = TextEditingController(text: report.description ?? '');
    String selectedDepartment = report.department;
    DateTime periodStart = report.periodStart;
    DateTime periodEnd = report.periodEnd;

    final departments = [
      'Hope Channel',
      'Finance',
      'Production',
      'Marketing',
      'Administration',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final dateFormat = DateFormat('MMM dd, yyyy');

          Future<void> selectDate(bool isStartDate) async {
            final initialDate = isStartDate ? periodStart : periodEnd;
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setModalState(() {
                if (isStartDate) {
                  periodStart = picked;
                  if (periodEnd.isBefore(periodStart)) {
                    periodEnd = periodStart;
                  }
                } else {
                  periodEnd = picked;
                }
              });
            }
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Edit Income Report',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Form(
                      key: formKey,
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextFormField(
                            controller: reportNameController,
                            decoration: InputDecoration(
                              labelText: 'Report Name *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.description),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a report name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: InputDecoration(
                              labelText: 'Department *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.business),
                            ),
                            items: departments.map((dept) {
                              return DropdownMenuItem(value: dept, child: Text(dept));
                            }).toList(),
                            onChanged: (value) {
                              setModalState(() => selectedDepartment = value!);
                            },
                          ),
                          const SizedBox(height: 16),
                          // Period dates
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => selectDate(true),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Start Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 16, color: Colors.green.shade600),
                                            const SizedBox(width: 8),
                                            Text(dateFormat.format(periodStart), style: const TextStyle(fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => selectDate(false),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('End Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 16, color: Colors.green.shade600),
                                            const SizedBox(width: 8),
                                            Text(dateFormat.format(periodEnd), style: const TextStyle(fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.notes),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    final updatedReport = report.copyWith(
                                      reportName: reportNameController.text.trim(),
                                      department: selectedDepartment,
                                      periodStart: periodStart,
                                      periodEnd: periodEnd,
                                      description: descriptionController.text.trim().isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      updatedAt: DateTime.now(),
                                    );

                                    final success = await context
                                        .read<IncomeReportProvider>()
                                        .updateIncomeReport(updatedReport);

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Report updated successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Save Changes'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  void _showDeleteReportDialog(IncomeReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete Income Report',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Are you sure you want to delete "${report.reportName}"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'This will also delete all income entries in this report. This action cannot be undone.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final success = await context
                        .read<IncomeReportProvider>()
                        .deleteIncomeReport(report.id);

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report deleted successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'draft':
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = 'Draft';
        break;
      case 'submitted':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        label = 'Submitted';
        break;
      case 'approved':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        label = 'Approved';
        break;
      case 'closed':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        label = 'Closed';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
