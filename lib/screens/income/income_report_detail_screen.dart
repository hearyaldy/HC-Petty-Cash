import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/income_report_provider.dart';
import '../../models/income_report.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class IncomeReportDetailScreen extends StatefulWidget {
  final String reportId;

  const IncomeReportDetailScreen({super.key, required this.reportId});

  @override
  State<IncomeReportDetailScreen> createState() =>
      _IncomeReportDetailScreenState();
}

class _IncomeReportDetailScreenState extends State<IncomeReportDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncomeReportProvider>().loadReportWithEntries(
        widget.reportId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IncomeReportProvider>(
      builder: (context, provider, child) {
        final report = provider.currentReport;
        final entries = provider.currentEntries;

        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Income Report'),
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () => context.go('/dashboard'),
                  tooltip: 'Dashboard',
                ),
              ],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (report == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Income Report'),
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () => context.go('/dashboard'),
                  tooltip: 'Dashboard',
                ),
              ],
            ),
            body: const Center(child: Text('Report not found')),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(report.reportNumber),
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            actions: [
              // Edit button - visible for draft reports
              if (report.status == 'draft')
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditReportDialog(report),
                  tooltip: 'Edit Report',
                ),
              // Home button - always visible
              IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go('/dashboard'),
                tooltip: 'Dashboard',
              ),
              // More options menu
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, report),
                itemBuilder: (context) => [
                  if (report.status == 'draft') ...[
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
                      value: 'submit',
                      child: Row(
                        children: [
                          Icon(Icons.send, size: 20),
                          SizedBox(width: 8),
                          Text('Submit for Approval'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Delete Report',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Back to income list option - always available
                  const PopupMenuItem(
                    value: 'back_to_list',
                    child: Row(
                      children: [
                        Icon(Icons.list, size: 20),
                        SizedBox(width: 8),
                        Text('Back to Income List'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ResponsiveContainer(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildReportHeader(report),
                  _buildSummaryCards(report, entries),
                  _buildEntriesList(entries, report.status),
                ],
              ),
            ),
          ),
          floatingActionButton: report.status == 'draft'
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddEntryDialog(context),
                  backgroundColor: Colors.green.shade600,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Income'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildReportHeader(IncomeReport report) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.department,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(report.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                '${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Created by: ${report.createdByName}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    String label;

    switch (status) {
      case 'draft':
        backgroundColor = Colors.grey.shade600;
        label = 'Draft';
        break;
      case 'submitted':
        backgroundColor = Colors.orange.shade600;
        label = 'Submitted';
        break;
      case 'approved':
        backgroundColor = Colors.green.shade800;
        label = 'Approved';
        break;
      case 'closed':
        backgroundColor = Colors.blue.shade600;
        label = 'Closed';
        break;
      default:
        backgroundColor = Colors.grey.shade600;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSummaryCards(IncomeReport report, List<IncomeEntry> entries) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final screenPadding = ResponsiveHelper.getScreenPadding(context);

    // Group entries by category
    final categoryTotals = <String, double>{};
    for (final entry in entries) {
      categoryTotals[entry.category] =
          (categoryTotals[entry.category] ?? 0) + entry.amount;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenPadding.left,
        vertical: 16,
      ),
      child: Column(
        children: [
          // Total Income Card
          Container(
            width: double.infinity,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.green.shade600,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Income',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            '${AppConstants.currencySymbol}${currencyFormat.format(report.totalIncome)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${entries.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Entries',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Category breakdown
          if (categoryTotals.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                  const Text(
                    'Income by Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...categoryTotals.entries.map((entry) {
                    final category = incomeCategoryFromString(entry.key);
                    final percentage = report.totalIncome > 0
                        ? (entry.value / report.totalIncome * 100)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.displayName,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '${AppConstants.currencySymbol}${currencyFormat.format(entry.value)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${percentage.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(List<IncomeEntry> entries, String reportStatus) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MMM dd, yyyy');
    final screenPadding = ResponsiveHelper.getScreenPadding(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Income Entries',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No income entries yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (reportStatus == 'draft') ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Tap the button below to add your first entry',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            )
          else
            ...entries.map((entry) {
              final category = incomeCategoryFromString(entry.category);
              final paymentMethod = paymentMethodFromString(
                entry.paymentMethod,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: reportStatus == 'draft'
                      ? () => _showEditEntryDialog(context, entry)
                      : null,
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
                                entry.sourceName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${AppConstants.currencySymbol}${currencyFormat.format(entry.amount)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildInfoChip(
                              Icons.category,
                              category.displayName,
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              Icons.payment,
                              paymentMethod.displayName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dateFormat.format(entry.dateReceived),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            if (entry.referenceNumber != null &&
                                entry.referenceNumber!.isNotEmpty)
                              Text(
                                'Ref: ${entry.referenceNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, IncomeReport report) async {
    switch (action) {
      case 'edit':
        _showEditReportDialog(report);
        break;
      case 'submit':
        _submitReport(report);
        break;
      case 'delete':
        _deleteReport(report);
        break;
      case 'back_to_list':
        context.go('/income');
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

  void _submitReport(IncomeReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Report'),
        content: const Text(
          'Are you sure you want to submit this report for approval? You won\'t be able to edit it after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context
          .read<IncomeReportProvider>()
          .submitIncomeReport(report.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _deleteReport(IncomeReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text(
          'Are you sure you want to delete this report? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context
          .read<IncomeReportProvider>()
          .deleteIncomeReport(report.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/income');
      }
    }
  }

  void _showAddEntryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _IncomeEntryForm(
        reportId: widget.reportId,
        onSaved: () {
          context.read<IncomeReportProvider>().loadReportWithEntries(
            widget.reportId,
          );
        },
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, IncomeEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _IncomeEntryForm(
        reportId: widget.reportId,
        entry: entry,
        onSaved: () {
          context.read<IncomeReportProvider>().loadReportWithEntries(
            widget.reportId,
          );
        },
      ),
    );
  }
}

// Income Entry Form Widget
class _IncomeEntryForm extends StatefulWidget {
  final String reportId;
  final IncomeEntry? entry;
  final VoidCallback onSaved;

  const _IncomeEntryForm({
    required this.reportId,
    this.entry,
    required this.onSaved,
  });

  @override
  State<_IncomeEntryForm> createState() => _IncomeEntryFormState();
}

class _IncomeEntryFormState extends State<_IncomeEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _sourceNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();

  DateTime _dateReceived = DateTime.now();
  IncomeCategory _selectedCategory = IncomeCategory.donations;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.bankTransfer;
  bool _isSubmitting = false;

  bool get isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _sourceNameController.text = widget.entry!.sourceName;
      _descriptionController.text = widget.entry!.description;
      _amountController.text = widget.entry!.amount.toString();
      _referenceController.text = widget.entry!.referenceNumber ?? '';
      _dateReceived = widget.entry!.dateReceived;
      _selectedCategory = widget.entry!.categoryEnum;
      _selectedPaymentMethod = widget.entry!.paymentMethodEnum;
    }
  }

  @override
  void dispose() {
    _sourceNameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReceived,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dateReceived = picked);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<IncomeReportProvider>();

      if (isEditing) {
        final updatedEntry = widget.entry!.copyWith(
          dateReceived: _dateReceived,
          category: _selectedCategory.value,
          sourceName: _sourceNameController.text.trim(),
          description: _descriptionController.text.trim(),
          amount: double.parse(_amountController.text),
          paymentMethod: _selectedPaymentMethod.value,
          referenceNumber: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          updatedAt: DateTime.now(),
        );
        await provider.updateIncomeEntry(updatedEntry);
      } else {
        await provider.addIncomeEntry(
          reportId: widget.reportId,
          dateReceived: _dateReceived,
          category: _selectedCategory.value,
          sourceName: _sourceNameController.text.trim(),
          description: _descriptionController.text.trim(),
          amount: double.parse(_amountController.text),
          paymentMethod: _selectedPaymentMethod.value,
          referenceNumber: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Entry updated successfully!'
                  : 'Entry added successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this income entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<IncomeReportProvider>().deleteIncomeEntry(
          widget.entry!.id,
          widget.reportId,
        );
        if (mounted) {
          Navigator.pop(context);
          widget.onSaved();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Income Entry' : 'Add Income Entry',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isEditing)
                      IconButton(
                        onPressed: _deleteEntry,
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Date
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date Received',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              dateFormat.format(_dateReceived),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Source Name
                TextFormField(
                  controller: _sourceNameController,
                  decoration: InputDecoration(
                    labelText: 'Source/Donor Name *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the source name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Category
                DropdownButtonFormField<IncomeCategory>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: IncomeCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (${AppConstants.currencySymbol}) *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Payment Method
                DropdownButtonFormField<PaymentMethod>(
                  value: _selectedPaymentMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.payment),
                  ),
                  items: PaymentMethod.values.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedPaymentMethod = value!);
                  },
                ),
                const SizedBox(height: 16),
                // Reference Number
                TextFormField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    labelText: 'Reference Number (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 24),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEditing ? 'Update Entry' : 'Add Entry',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
