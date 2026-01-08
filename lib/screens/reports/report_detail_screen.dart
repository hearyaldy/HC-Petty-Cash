import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/petty_cash_report.dart';
import '../../models/transaction.dart';
import '../../models/enums.dart';
import '../../services/excel_export_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/voucher_export_service.dart';
import '../../widgets/voucher_preview_dialog.dart';
import '../../utils/constants.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<ProjectReportProvider>().loadProjectReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reportProvider = context.watch<ReportProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    final report = reportProvider.reports.firstWhere(
      (r) => r.id == widget.reportId,
      orElse: () => throw Exception('Report not found'),
    );

    final transactions = transactionProvider.transactions
        .where((t) => t.reportId == report.id)
        .toList();
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(report.reportNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
          if (report.status != ReportStatus.closed.name)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddTransactionDialog(report),
              tooltip: 'Add Transaction',
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export_excel') {
                await _exportExcel(report, transactions);
              } else if (value == 'export_pdf') {
                await _exportPdf(report, transactions);
              } else if (value == 'submit') {
                await _submitReport(report, reportProvider);
              } else if (value == 'approve') {
                await _approveReport(report, reportProvider);
              } else if (value == 'close') {
                await _closeReport(report, reportProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart),
                    SizedBox(width: 8),
                    Text('Export to Excel'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Export to PDF'),
                  ],
                ),
              ),
              if (report.status == ReportStatus.draft.name)
                const PopupMenuItem(
                  value: 'submit',
                  child: Row(
                    children: [
                      Icon(Icons.send),
                      SizedBox(width: 8),
                      Text('Submit Report'),
                    ],
                  ),
                ),
              if (authProvider.canApprove() &&
                  (report.status == ReportStatus.submitted.name ||
                      report.status == ReportStatus.underReview.name))
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Approve Report',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              if (report.status == ReportStatus.approved.name &&
                  authProvider.canApprove())
                const PopupMenuItem(
                  value: 'close',
                  child: Row(
                    children: [
                      Icon(Icons.archive),
                      SizedBox(width: 8),
                      Text('Close Report'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportHeader(report),
            const SizedBox(height: 24),
            _buildFinancialSummary(report),
            const SizedBox(height: 32),
            _buildTransactionsList(transactions, report, authProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHeader(PettyCashReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Details',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created ${DateFormat('MMM d, y').format(report.createdAt)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(report.statusEnum),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow('Report Number', report.reportNumber),
            _buildDetailRow('Report Name', report.department),
            _buildDetailRow('Custodian', report.custodianName),
            _buildDetailRow(
              'Period',
              '${DateFormat('MMM d, y').format(report.periodStart)} - ${DateFormat('MMM d, y').format(report.periodEnd)}',
            ),
            if (report.companyName != null)
              _buildDetailRow('Company', report.companyName!),
            if (report.notes != null && report.notes!.isNotEmpty)
              _buildDetailRow('Notes', report.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color color;
    switch (status) {
      case ReportStatus.draft:
        color = Colors.grey;
        break;
      case ReportStatus.submitted:
        color = Colors.blue;
        break;
      case ReportStatus.underReview:
        color = Colors.orange;
        break;
      case ReportStatus.approved:
        color = Colors.green;
        break;
      case ReportStatus.closed:
        color = Colors.purple;
        break;
    }

    return Chip(
      label: Text(
        status.displayName,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  Widget _buildFinancialSummary(PettyCashReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildAmountCard(
                    'Opening Balance',
                    report.openingBalance,
                    Colors.blue,
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAmountCard(
                    'Total Disbursements',
                    report.totalDisbursements,
                    Colors.red,
                    Icons.money_off,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAmountCard(
                    'Cash on Hand',
                    report.cashOnHand,
                    Colors.orange,
                    Icons.payments,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAmountCard(
                    'Closing Balance',
                    report.closingBalance,
                    Colors.green,
                    Icons.account_balance,
                  ),
                ),
              ],
            ),
            if (report.variance != 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Variance Detected',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${AppConstants.currencySymbol}${report.variance.abs().toStringAsFixed(2)} ${report.variance > 0 ? 'over' : 'under'}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    List<Transaction> transactions,
    PettyCashReport report,
    AuthProvider authProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transactions',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (report.status != ReportStatus.closed.name)
                  ElevatedButton.icon(
                    onPressed: () => _showAddTransactionDialog(report),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                  ),
              ],
            ),
            const Divider(height: 32),
            if (transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No transactions yet'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionItem(transaction, authProvider);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    Transaction transaction,
    AuthProvider authProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getTransactionStatusColor(
                transaction.statusEnum,
              ),
              child: Icon(
                _getTransactionIcon(transaction.categoryEnum),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.categoryEnum.displayName} • ${DateFormat('MMM d, y').format(transaction.date)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  Text(
                    'Receipt: ${transaction.receiptNo} • ${transaction.paymentMethodEnum.displayName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  _buildTransactionStatusChip(transaction.statusEnum),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _exportVoucher(transaction),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text(
                        'Voucher',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _showEditTransactionDialog(transaction);
                        } else if (value == 'delete') {
                          await _showDeleteTransactionConfirmation(transaction);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionStatusChip(TransactionStatus status) {
    Color color;
    switch (status) {
      case TransactionStatus.draft:
        color = Colors.grey;
        break;
      case TransactionStatus.pendingApproval:
        color = Colors.orange;
        break;
      case TransactionStatus.approved:
        color = Colors.green;
        break;
      case TransactionStatus.rejected:
        color = Colors.red;
        break;
      case TransactionStatus.processed:
        color = Colors.blue;
        break;
    }

    return Chip(
      label: Text(
        status.displayName,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getTransactionStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.draft:
        return Colors.grey;
      case TransactionStatus.pendingApproval:
        return Colors.orange;
      case TransactionStatus.approved:
        return Colors.green;
      case TransactionStatus.rejected:
        return Colors.red;
      case TransactionStatus.processed:
        return Colors.blue;
    }
  }

  IconData _getTransactionIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.office:
        return Icons.business;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.meals:
        return Icons.restaurant;
      case ExpenseCategory.utilities:
        return Icons.lightbulb;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.supplies:
        return Icons.shopping_cart;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  Future<void> _showAddTransactionDialog(PettyCashReport report) async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    final receiptNoController = TextEditingController();
    final amountController = TextEditingController();
    final paidToController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    ExpenseCategory selectedCategory = ExpenseCategory.other;
    PaymentMethod selectedPaymentMethod = PaymentMethod.cash;
    String? selectedProjectId;

    // Get project reports before showing modal
    final projectReports = context.read<ProjectReportProvider>().projectReports;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
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
                          'Add Transaction',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextFormField(
                          controller: receiptNoController,
                          decoration: const InputDecoration(
                            labelText: 'Receipt Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.receipt),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a receipt number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(selectedDate),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: paidToController,
                          decoration: const InputDecoration(
                            labelText: 'Paid to',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter who this was paid to';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (For)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            border: const OutlineInputBorder(),
                            prefixText: '${AppConstants.currencySymbol} ',
                            prefixIcon: const Icon(Icons.money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Project selection dropdown
                        DropdownButtonFormField<String?>(
                          value: selectedProjectId,
                          decoration: const InputDecoration(
                            labelText: 'Project (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.work),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('No Project'),
                            ),
                            ...projectReports.map(
                              (project) => DropdownMenuItem(
                                value: project.id,
                                child: Text(project.projectName),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedProjectId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ExpenseCategory>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: ExpenseCategory.values.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedCategory = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<PaymentMethod>(
                          value: selectedPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: PaymentMethod.values.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Text(method.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedPaymentMethod = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  final transactionProvider = context
                                      .read<TransactionProvider>();
                                  final authProvider = context
                                      .read<AuthProvider>();

                                  await transactionProvider.createTransaction(
                                    reportId: report.id,
                                    projectId: selectedProjectId,
                                    date: selectedDate,
                                    receiptNo: receiptNoController.text,
                                    description: descriptionController.text,
                                    category: selectedCategory,
                                    amount: double.parse(amountController.text),
                                    paymentMethod: selectedPaymentMethod,
                                    requestorId: authProvider.currentUser!.id,
                                    paidTo: paidToController.text,
                                  );

                                  if (!context.mounted) return;
                                  // Reload both transactions and reports to update the UI
                                  await Future.wait([
                                    context
                                        .read<TransactionProvider>()
                                        .loadTransactions(),
                                    context
                                        .read<ReportProvider>()
                                        .loadReports(),
                                  ]);

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Transaction added successfully',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Add Transaction'),
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
        ),
      ),
    );
  }

  Future<void> _exportExcel(
    PettyCashReport report,
    List<Transaction> transactions,
  ) async {
    try {
      final excelService = ExcelExportService();
      await excelService.exportReport(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel file exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting Excel: $e')));
      }
    }
  }

  Future<void> _exportPdf(
    PettyCashReport report,
    List<Transaction> transactions,
  ) async {
    try {
      final pdfService = PdfExportService();
      await pdfService.exportReport(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
      }
    }
  }

  Future<void> _submitReport(
    PettyCashReport report,
    ReportProvider provider,
  ) async {
    final updatedReport = report.copyWith(
      status: ReportStatus.submitted.name,
      updatedAt: DateTime.now(),
    );
    await provider.updateReport(updatedReport);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
    }
  }

  Future<void> _approveReport(
    PettyCashReport report,
    ReportProvider provider,
  ) async {
    final updatedReport = report.copyWith(
      status: ReportStatus.approved.name,
      updatedAt: DateTime.now(),
    );
    await provider.updateReport(updatedReport);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _closeReport(
    PettyCashReport report,
    ReportProvider provider,
  ) async {
    final updatedReport = report.copyWith(
      status: ReportStatus.closed.name,
      updatedAt: DateTime.now(),
    );
    await provider.updateReport(updatedReport);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report closed successfully')),
      );
    }
  }

  Future<void> _exportVoucher(Transaction transaction) async {
    try {
      final reportProvider = context.read<ReportProvider>();
      final report = reportProvider.reports.firstWhere(
        (r) => r.id == transaction.reportId,
      );

      // Show preview bottom sheet
      final shouldExport = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => VoucherPreviewDialog(
          transaction: transaction,
          report: report,
          onPrint: () => _printVoucher(transaction, report),
        ),
      );

      // If user confirmed export
      if (shouldExport == true) {
        final voucherService = VoucherExportService();
        await voucherService.exportVoucher(transaction, report);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Petty Cash Voucher exported successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printVoucher(
    Transaction transaction,
    PettyCashReport report,
  ) async {
    try {
      final voucherService = VoucherExportService();
      await voucherService.printVoucher(transaction, report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditTransactionDialog(Transaction transaction) async {
    final amountController = TextEditingController(
      text: transaction.amount.toString(),
    );
    final descriptionController = TextEditingController(
      text: transaction.description,
    );
    final receiptNoController = TextEditingController(
      text: transaction.receiptNo,
    );
    final paidToController = TextEditingController(
      text: transaction.paidTo ?? '',
    );
    DateTime selectedDate = transaction.date;
    ExpenseCategory selectedCategory = transaction.categoryEnum;
    PaymentMethod selectedPaymentMethod = transaction.paymentMethodEnum;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Transaction'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: '${AppConstants.currencySymbol} ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: receiptNoController,
                  decoration: const InputDecoration(
                    labelText: 'Receipt No.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: paidToController,
                  decoration: const InputDecoration(
                    labelText: 'Paid To',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('MMM d, y').format(selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ExpenseCategory>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: ExpenseCategory.values
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PaymentMethod>(
                        value: selectedPaymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                        ),
                        items: PaymentMethod.values
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: Text(method.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedPaymentMethod = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descriptionController.text.isEmpty ||
                  amountController.text.isEmpty ||
                  receiptNoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                  ),
                );
                return;
              }

              final transactionProvider = context.read<TransactionProvider>();

              final updatedTransaction = transaction.copyWith(
                date: selectedDate,
                receiptNo: receiptNoController.text,
                description: descriptionController.text,
                category: selectedCategory.name,
                amount: double.parse(amountController.text),
                paymentMethod: selectedPaymentMethod.name,
                paidTo: paidToController.text.isEmpty
                    ? null
                    : paidToController.text,
                updatedAt: DateTime.now(),
              );

              await transactionProvider.updateTransaction(updatedTransaction);

              if (!context.mounted) return;
              // Reload both transactions and reports to update the UI
              await Future.wait([
                context.read<TransactionProvider>().loadTransactions(),
                context.read<ReportProvider>().loadReports(),
              ]);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction updated successfully'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteTransactionConfirmation(
    Transaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this transaction?\n\n'
          '${transaction.description}\n'
          '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final transactionProvider = context.read<TransactionProvider>();
        await transactionProvider.deleteTransaction(transaction.id);

        if (!mounted) return;
        // Reload both transactions and reports to update the UI
        await Future.wait([
          context.read<TransactionProvider>().loadTransactions(),
          context.read<ReportProvider>().loadReports(),
        ]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting transaction: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
