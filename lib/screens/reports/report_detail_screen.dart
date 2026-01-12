import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io' show Platform;
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/petty_cash_report.dart';
import '../../models/app_settings.dart';
import '../../models/transaction.dart';
import '../../models/enums.dart';
import '../../services/excel_export_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/voucher_export_service.dart';
import '../../widgets/voucher_preview_dialog.dart';
import '../../widgets/edit_petty_cash_report_dialog.dart';
import '../../widgets/paid_to_field.dart';
import '../../widgets/support_document_upload_dialog.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

enum TransactionSortOption {
  dateNewest,
  dateOldest,
  amountHighest,
  amountLowest,
  receiptNoAsc,
  receiptNoDesc,
}

extension TransactionSortOptionExtension on TransactionSortOption {
  String get displayName {
    switch (this) {
      case TransactionSortOption.dateNewest:
        return 'Date (Newest First)';
      case TransactionSortOption.dateOldest:
        return 'Date (Oldest First)';
      case TransactionSortOption.amountHighest:
        return 'Amount (Highest First)';
      case TransactionSortOption.amountLowest:
        return 'Amount (Lowest First)';
      case TransactionSortOption.receiptNoAsc:
        return 'Receipt No (1-9)';
      case TransactionSortOption.receiptNoDesc:
        return 'Receipt No (9-1)';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionSortOption.dateNewest:
      case TransactionSortOption.dateOldest:
        return Icons.calendar_today;
      case TransactionSortOption.amountHighest:
      case TransactionSortOption.amountLowest:
        return Icons.attach_money;
      case TransactionSortOption.receiptNoAsc:
      case TransactionSortOption.receiptNoDesc:
        return Icons.receipt;
    }
  }
}

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  TransactionSortOption _sortOption = TransactionSortOption.receiptNoAsc;
  List<CustomCategory> _enabledCustomCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<ProjectReportProvider>().loadProjectReports();
    });
  }

  Future<void> _loadCustomCategories() async {
    final settingsService = SettingsService();
    final categories = await settingsService.getCustomCategories();
    if (!mounted) return;
    setState(() {
      _enabledCustomCategories = categories.where((c) => c.enabled).toList();
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
    _sortTransactions(transactions);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
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
              if (value == 'edit') {
                await _showEditReportDialog(report, reportProvider);
              } else if (value == 'export_excel') {
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
              if (report.status == ReportStatus.draft.name ||
                  authProvider.canApprove())
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit Report'),
                    ],
                  ),
                ),
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
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(report),
              const SizedBox(height: 24),
              _buildReportHeader(report),
              const SizedBox(height: 24),
              _buildFinancialSummary(report),
              const SizedBox(height: 32),
              _buildTransactionsList(transactions, report, authProvider),
            ],
          ),
        ),
      ),
    );
  }

  void _sortTransactions(List<Transaction> transactions) {
    switch (_sortOption) {
      case TransactionSortOption.dateNewest:
        transactions.sort((a, b) => b.date.compareTo(a.date));
        break;
      case TransactionSortOption.dateOldest:
        transactions.sort((a, b) => a.date.compareTo(b.date));
        break;
      case TransactionSortOption.amountHighest:
        transactions.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case TransactionSortOption.amountLowest:
        transactions.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case TransactionSortOption.receiptNoAsc:
        transactions.sort((a, b) {
          final aNum = int.tryParse(a.receiptNo) ?? 0;
          final bNum = int.tryParse(b.receiptNo) ?? 0;
          return aNum.compareTo(bNum);
        });
        break;
      case TransactionSortOption.receiptNoDesc:
        transactions.sort((a, b) {
          final aNum = int.tryParse(a.receiptNo) ?? 0;
          final bNum = int.tryParse(b.receiptNo) ?? 0;
          return bNum.compareTo(aNum);
        });
        break;
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TransactionSortOption.values.map((option) {
            return RadioListTile<TransactionSortOption>(
              title: Row(
                children: [
                  Icon(option.icon, size: 20),
                  const SizedBox(width: 12),
                  Text(option.displayName),
                ],
              ),
              value: option,
              groupValue: _sortOption,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortOption = value;
                  });
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(PettyCashReport report) {
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
                  report.reportNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  report.department,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Created ${DateFormat('MMM d, y').format(report.createdAt)}',
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

  Widget _buildReportHeader(PettyCashReport report) {
    return Container(
      padding: const EdgeInsets.all(24),
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
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

  Widget _buildFinancialSummary(PettyCashReport report) {
    return Container(
      padding: const EdgeInsets.all(24),
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
    );
  }

  Widget _buildAmountCard(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                if (transactions.isNotEmpty) ...[
                  IconButton(
                    onPressed: _showSortDialog,
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort Transactions',
                  ),
                  IconButton(
                    onPressed: () =>
                        _printTransactionsTable(report, transactions),
                    icon: const Icon(Icons.print),
                    tooltip: 'Print Transactions',
                  ),
                ],
                if (report.status != ReportStatus.closed.name)
                  ElevatedButton.icon(
                    onPressed: () => _showAddTransactionDialog(report),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            if (transactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(
                  children: [
                    Icon(_sortOption.icon, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Sorted by: ${_sortOption.displayName}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),
            if (transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first transaction to get started',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
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
    final isMobile = ResponsiveHelper.isMobile(context);

    final amountText = Text(
      '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    );

    final actions = Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        _buildSupportDocumentButton(transaction),
        OutlinedButton.icon(
          onPressed: () => _exportVoucher(transaction),
          icon: const Icon(Icons.receipt_long, size: 16),
          label: const Text('Voucher', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            side: BorderSide(color: Colors.blue.shade300),
            foregroundColor: Colors.blue.shade700,
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
            } else if (value == 'viewDocument') {
              _showSupportDocumentPreview(transaction);
            } else if (value == 'uploadDocument') {
              _showSupportDocumentUploadDialog(transaction);
            }
          },
          itemBuilder: (context) => [
            if (transaction.supportDocumentUrl != null)
              const PopupMenuItem(
                value: 'viewDocument',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('View Document'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'uploadDocument',
              child: Row(
                children: [
                  Icon(
                    transaction.supportDocumentUrl != null
                        ? Icons.edit_document
                        : Icons.upload_file,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    transaction.supportDocumentUrl != null
                        ? 'Change Document'
                        : 'Upload Document',
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
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
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final leadingIcon = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getTransactionStatusColor(transaction.statusEnum),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_getTransactionIconFor(transaction), color: Colors.white),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          transaction.description,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                transaction.categoryDisplayName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• ${DateFormat('MMM d, y').format(transaction.date)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Receipt: ${transaction.receiptNo} • ${transaction.paymentMethodEnum.displayName}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildTransactionStatusChip(transaction.statusEnum),
            if (transaction.supportDocumentUrl != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 12,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Doc',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leadingIcon,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                      const SizedBox(width: 8),
                      amountText,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              )
            : Row(
                children: [
                  leadingIcon,
                  const SizedBox(width: 16),
                  Expanded(child: details),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [amountText, const SizedBox(height: 12), actions],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSupportDocumentButton(Transaction transaction) {
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final hasDocument = transaction.supportDocumentUrl != null;

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'view') {
          _showSupportDocumentPreview(transaction);
        } else if (value == 'upload') {
          _showSupportDocumentUploadDialog(transaction);
        } else if (value == 'camera') {
          _showSupportDocumentUploadDialog(transaction, fromCamera: true);
        }
      },
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasDocument ? Colors.green.shade300 : Colors.orange.shade300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasDocument ? Icons.attach_file : Icons.add_photo_alternate,
              size: 16,
              color: hasDocument
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              hasDocument ? 'Doc' : 'Add Doc',
              style: TextStyle(
                fontSize: 12,
                color: hasDocument
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        if (hasDocument)
          const PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('View Document'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'upload',
          child: Row(
            children: [
              Icon(Icons.photo_library, size: 18, color: Colors.purple),
              SizedBox(width: 8),
              Text('Upload from Gallery'),
            ],
          ),
        ),
        if (isMobile)
          const PopupMenuItem(
            value: 'camera',
            child: Row(
              children: [
                Icon(Icons.camera_alt, size: 18, color: Colors.teal),
                SizedBox(width: 8),
                Text('Take Photo'),
              ],
            ),
          ),
      ],
    );
  }

  void _showSupportDocumentPreview(Transaction transaction) {
    if (transaction.supportDocumentUrl == null) return;

    showDialog(
      context: context,
      builder: (context) =>
          SupportDocumentPreview(documentUrl: transaction.supportDocumentUrl!),
    );
  }

  void _showSupportDocumentUploadDialog(
    Transaction transaction, {
    bool fromCamera = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => SupportDocumentUploadDialog(
        transactionId: transaction.id,
        existingDocumentUrls: transaction.supportDocumentUrls,
        onDocumentsUploaded: (urls) async {
          try {
            await context.read<TransactionProvider>().updateSupportDocuments(
              transaction.id,
              urls,
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating documents: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildTransactionStatusChip(TransactionStatus status) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (status) {
      case TransactionStatus.draft:
        backgroundColor = Colors.grey.shade600;
        break;
      case TransactionStatus.pendingApproval:
        backgroundColor = Colors.orange.shade600;
        break;
      case TransactionStatus.approved:
        backgroundColor = Colors.green.shade600;
        break;
      case TransactionStatus.rejected:
        backgroundColor = Colors.red.shade600;
        break;
      case TransactionStatus.processed:
        backgroundColor = Colors.blue.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
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

  IconData _getTransactionIconFor(Transaction transaction) {
    final hasCustom =
        transaction.customCategory != null &&
        transaction.customCategory!.isNotEmpty;

    if (hasCustom) {
      final custom = _enabledCustomCategories.firstWhere(
        (c) => c.name == transaction.customCategory,
        orElse: () => CustomCategory(
          // Fallback to avoid crashes if cache misses
          id: 'fallback',
          name: transaction.customCategory!,
          iconCodePoint: Icons.category.codePoint.toString(),
          createdAt: DateTime.now(),
        ),
      );

      try {
        return IconData(
          int.parse(custom.iconCodePoint),
          fontFamily: 'MaterialIcons',
        );
      } catch (_) {
        // If parsing fails, fall back to generic icon
        return Icons.category;
      }
    }

    return _getTransactionIcon(transaction.categoryEnum);
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
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

    // Auto-generate next receipt number starting from 1
    final transactionProvider = context.read<TransactionProvider>();
    final existingTransactions = transactionProvider.transactions
        .where((t) => t.reportId == report.id)
        .toList();

    int nextReceiptNumber = 1;
    if (existingTransactions.isNotEmpty) {
      // Find the highest receipt number and add 1
      final receiptNumbers = existingTransactions
          .map((t) => int.tryParse(t.receiptNo) ?? 0)
          .where((n) => n > 0)
          .toList();
      if (receiptNumbers.isNotEmpty) {
        nextReceiptNumber = receiptNumbers.reduce((a, b) => a > b ? a : b) + 1;
      }
    }

    final receiptNoController = TextEditingController(
      text: nextReceiptNumber.toString().padLeft(3, '0'),
    );
    final amountController = TextEditingController();
    final paidToController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedCategory = ExpenseCategory.other.name;
    PaymentMethod selectedPaymentMethod = PaymentMethod.cash;
    String? selectedProjectId;

    // Get project reports before showing modal
    final projectReports = context.read<ProjectReportProvider>().projectReports;

    // Load custom categories
    final settingsService = SettingsService();
    final customCategories = await settingsService.getCustomCategories();
    var enabledCustomCategories = customCategories
        .where((c) => c.enabled)
        .toList();

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
                        InkWell(
                          onTap: () async {
                            final result = await showDialog<String>(
                              context: context,
                              builder: (context) => PaidToFieldDialog(
                                initialValue: paidToController.text,
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                paidToController.text = result;
                              });
                            }
                          },
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: paidToController,
                              decoration: const InputDecoration(
                                labelText: 'Paid to',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter who this was paid to';
                                }
                                return null;
                              },
                            ),
                          ),
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
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: [
                            // Default categories
                            ...ExpenseCategory.values.map((category) {
                              return DropdownMenuItem(
                                value: category.name,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(category),
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.displayName),
                                  ],
                                ),
                              );
                            }),
                            // Custom categories
                            ...enabledCustomCategories.map((category) {
                              return DropdownMenuItem(
                                value: 'custom_${category.id}',
                                child: Row(
                                  children: [
                                    Icon(
                                      IconData(
                                        int.parse(category.iconCodePoint),
                                        fontFamily: 'MaterialIcons',
                                      ),
                                      size: 20,
                                      color: Colors.purple,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }),
                            // Add new category option
                            DropdownMenuItem(
                              value: '_add_new_category',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add New Category...',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == '_add_new_category') {
                              // Show add category dialog
                              final newCategory = await _showAddCategoryDialog(
                                context,
                              );
                              if (newCategory != null) {
                                // Reload custom categories
                                final updatedCategories = await settingsService
                                    .getCustomCategories();
                                setState(() {
                                  enabledCustomCategories = updatedCategories
                                      .where((c) => c.enabled)
                                      .toList();
                                  selectedCategory = 'custom_${newCategory.id}';
                                });
                              }
                            } else if (value != null) {
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

                                  final ExpenseCategory categoryEnum;
                                  String? customCategoryName;

                                  if (selectedCategory.startsWith('custom_')) {
                                    // For custom categories, extract the custom category name
                                    final customCategoryId = selectedCategory
                                        .substring(
                                          7,
                                        ); // Remove 'custom_' prefix
                                    final customCategory =
                                        enabledCustomCategories.firstWhere(
                                          (c) => c.id == customCategoryId,
                                        );
                                    customCategoryName = customCategory.name;
                                    categoryEnum = ExpenseCategory.other;
                                  } else {
                                    // For standard categories, find the corresponding enum value
                                    categoryEnum = ExpenseCategory.values
                                        .firstWhere(
                                          (e) => e.name == selectedCategory,
                                          orElse: () => ExpenseCategory
                                              .other, // fallback to 'other' if not found
                                        );
                                  }

                                  await transactionProvider.createTransaction(
                                    reportId: report.id,
                                    projectId: selectedProjectId,
                                    date: selectedDate,
                                    receiptNo: receiptNoController.text,
                                    description: descriptionController.text,
                                    category: categoryEnum,
                                    customCategory: customCategoryName,
                                    amount: double.parse(amountController.text),
                                    paymentMethod: selectedPaymentMethod,
                                    requestorId: authProvider.currentUser!.id,
                                    paidTo: paidToController.text,
                                  );

                                  if (!context.mounted) return;
                                  // Reload transactions, reports, and project reports to update the UI
                                  await Future.wait([
                                    context
                                        .read<TransactionProvider>()
                                        .loadTransactions(),
                                    context
                                        .read<ReportProvider>()
                                        .loadReports(),
                                    context
                                        .read<ProjectReportProvider>()
                                        .loadProjectReports(),
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

  Future<void> _showEditReportDialog(
    PettyCashReport report,
    ReportProvider provider,
  ) async {
    final updatedReport = await showDialog<PettyCashReport>(
      context: context,
      builder: (context) => EditPettyCashReportDialog(report: report),
    );

    if (updatedReport != null) {
      await provider.updateReport(updatedReport);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated successfully')),
        );
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
      final authProvider = context.read<AuthProvider>();
      final report = reportProvider.reports.firstWhere(
        (r) => r.id == transaction.reportId,
      );

      // Fetch requestor user
      final requestor = await authProvider.getUserById(transaction.requestorId);

      // Show preview bottom sheet
      final shouldExport = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => VoucherPreviewDialog(
          transaction: transaction,
          report: report,
          requestor: requestor,
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
      text:
          int.tryParse(transaction.receiptNo)?.toString().padLeft(3, '0') ??
          transaction.receiptNo,
    );
    final paidToController = TextEditingController(
      text: transaction.paidTo ?? '',
    );
    DateTime selectedDate = transaction.date;
    final settingsService = SettingsService();
    final customCategories = await settingsService.getCustomCategories();
    List<CustomCategory> enabledCustomCategories = customCategories
        .where((c) => c.enabled)
        .toList();

    String selectedCategory = transaction.categoryEnum.name;
    if (transaction.customCategory != null &&
        transaction.customCategory!.isNotEmpty) {
      final matchingCustom = enabledCustomCategories
          .where((c) => c.name == transaction.customCategory)
          .toList();
      if (matchingCustom.isNotEmpty) {
        selectedCategory = 'custom_${matchingCustom.first.id}';
      }
    }
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
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ...ExpenseCategory.values.map(
                            (cat) => DropdownMenuItem(
                              value: cat.name,
                              child: Text(cat.displayName),
                            ),
                          ),
                          ...enabledCustomCategories.map(
                            (category) => DropdownMenuItem(
                              value: 'custom_${category.id}',
                              child: Row(
                                children: [
                                  Icon(
                                    IconData(
                                      int.parse(category.iconCodePoint),
                                      fontFamily: 'MaterialIcons',
                                    ),
                                    size: 20,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(category.name),
                                ],
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: '_add_new_category',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add New Category...',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == '_add_new_category') {
                            final newCategory = await _showAddCategoryDialog(
                              context,
                            );
                            if (newCategory != null) {
                              final updatedCategories = await settingsService
                                  .getCustomCategories();
                              setState(() {
                                enabledCustomCategories = updatedCategories
                                    .where((c) => c.enabled)
                                    .toList();
                                selectedCategory = 'custom_${newCategory.id}';
                              });
                              _loadCustomCategories();
                              _loadCustomCategories();
                            }
                          } else if (value != null) {
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

              final ExpenseCategory categoryEnum;
              String? customCategoryName;

              if (selectedCategory.startsWith('custom_')) {
                final customCategoryId = selectedCategory.substring(7);
                final customCategory = enabledCustomCategories.firstWhere(
                  (c) => c.id == customCategoryId,
                  orElse: () => CustomCategory(
                    id: customCategoryId,
                    name: transaction.customCategory ?? 'Custom',
                    iconCodePoint: Icons.category.codePoint.toString(),
                    createdAt: DateTime.now(),
                  ),
                );
                customCategoryName = customCategory.name;
                categoryEnum = ExpenseCategory.other;
              } else {
                categoryEnum = ExpenseCategory.values.firstWhere(
                  (e) => e.name == selectedCategory,
                  orElse: () => ExpenseCategory.other,
                );
              }

              final updatedTransaction = transaction.copyWith(
                date: selectedDate,
                receiptNo: receiptNoController.text,
                description: descriptionController.text,
                category: categoryEnum.name,
                customCategory: customCategoryName,
                amount: double.parse(amountController.text),
                paymentMethod: selectedPaymentMethod.name,
                paidTo: paidToController.text.isEmpty
                    ? null
                    : paidToController.text,
                updatedAt: DateTime.now(),
              );

              await transactionProvider.updateTransaction(updatedTransaction);

              if (!context.mounted) return;
              // Reload transactions, reports, and project reports to update the UI
              await Future.wait([
                context.read<TransactionProvider>().loadTransactions(),
                context.read<ReportProvider>().loadReports(),
                context.read<ProjectReportProvider>().loadProjectReports(),
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
        // Reload transactions, reports, and project reports to update the UI
        await Future.wait([
          context.read<TransactionProvider>().loadTransactions(),
          context.read<ReportProvider>().loadReports(),
          context.read<ProjectReportProvider>().loadProjectReports(),
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

  Future<void> _printTransactionsTable(
    PettyCashReport report,
    List<Transaction> transactions,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
    );

    // Load font
    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Regular.ttf',
    );
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoSansThai-Bold.ttf',
    );
    final boldTtf = pw.Font.ttf(boldFontData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldTtf,
          fontFallback: [pw.Font.helvetica()],
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                'Transactions Report',
                style: pw.TextStyle(font: boldTtf, fontSize: 20),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${report.reportNumber} - ${report.department}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.Text(
                'Period: ${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
                style: pw.TextStyle(font: ttf, fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Requested by: Heary Healdy Sairin',
                style: pw.TextStyle(font: ttf, fontSize: 10),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Department: Hope Channel Southeast Asia',
                style: pw.TextStyle(font: ttf, fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1.5),
                  6: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Receipt No',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Category',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Payment',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Status',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...transactions.map((transaction) {
                    final categoryName = transaction.categoryDisplayName;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            dateFormat.format(transaction.date),
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            transaction.receiptNo,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            transaction.description,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            categoryName,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            currencyFormat.format(transaction.amount),
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            transaction.paymentMethodEnum.displayName,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            transaction.statusEnum.displayName,
                            style: pw.TextStyle(font: ttf, fontSize: 8),
                          ),
                        ),
                      ],
                    );
                  }),
                  // Total row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('', style: pw.TextStyle(font: ttf)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('', style: pw.TextStyle(font: ttf)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('', style: pw.TextStyle(font: ttf)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Total:',
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          currencyFormat.format(
                            transactions.fold<double>(
                              0,
                              (sum, t) => sum + t.amount,
                            ),
                          ),
                          style: pw.TextStyle(font: boldTtf, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('', style: pw.TextStyle(font: ttf)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('', style: pw.TextStyle(font: ttf)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Balance Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Opening Balance:',
                          style: pw.TextStyle(font: ttf, fontSize: 10),
                        ),
                        pw.Text(
                          currencyFormat.format(report.openingBalance),
                          style: pw.TextStyle(font: ttf, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Disbursements:',
                          style: pw.TextStyle(font: ttf, fontSize: 10),
                        ),
                        pw.Text(
                          currencyFormat.format(
                            transactions.fold<double>(
                              0,
                              (sum, t) => sum + t.amount,
                            ),
                          ),
                          style: pw.TextStyle(font: ttf, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Balance:',
                              style: pw.TextStyle(font: boldTtf, fontSize: 11),
                            ),
                            pw.Text(
                              currencyFormat.format(
                                report.openingBalance -
                                    transactions.fold<double>(
                                      0,
                                      (sum, t) => sum + t.amount,
                                    ),
                              ),
                              style: pw.TextStyle(font: boldTtf, fontSize: 11),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '(${_convertToWords(report.openingBalance - transactions.fold<double>(0, (sum, t) => sum + t.amount))})',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 9,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Container(
                    width: 150,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Requested By:',
                          style: pw.TextStyle(font: boldTtf, fontSize: 10),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: PdfColors.black),
                            ),
                          ),
                          height: 1,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Name',
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 150,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Approved By:',
                          style: pw.TextStyle(font: boldTtf, fontSize: 10),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: PdfColors.black),
                            ),
                          ),
                          height: 1,
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 120,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Action No:',
                          style: pw.TextStyle(font: boldTtf, fontSize: 10),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: PdfColors.black),
                            ),
                          ),
                          height: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Show preview dialog
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transactions Report Preview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Printing.layoutPdf(
                            onLayout: (format) async => pdf.save(),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PdfPreview(
                  build: (format) async => pdf.save(),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _convertToWords(double amount) {
    final baht = amount.floor();
    final satang = ((amount - baht) * 100).round();

    final bahtInWords = _numberToWords(baht);
    final satangInWords = satang > 0
        ? 'and ${_numberToWords(satang)} Satang'
        : '';

    return '${bahtInWords.toUpperCase()} BAHT $satangInWords'.trim();
  }

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';

    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      return '${tens[number ~/ 10]} ${ones[number % 10]}'.trim();
    }
    if (number < 1000) {
      return '${ones[number ~/ 100]} Hundred ${_numberToWords(number % 100)}'
          .trim();
    }
    if (number < 1000000) {
      return '${_numberToWords(number ~/ 1000)} Thousand ${_numberToWords(number % 1000)}'
          .trim();
    }

    return number.toString(); // Fallback for very large numbers
  }

  Future<CustomCategory?> _showAddCategoryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    IconData selectedIcon = Icons.category;

    final List<IconData> availableIcons = [
      Icons.category,
      Icons.shopping_bag,
      Icons.restaurant,
      Icons.local_gas_station,
      Icons.home_repair_service,
      Icons.build,
      Icons.electrical_services,
      Icons.plumbing,
      Icons.local_shipping,
      Icons.phone,
      Icons.computer,
      Icons.print,
      Icons.attach_file,
      Icons.event,
      Icons.celebration,
      Icons.card_giftcard,
      Icons.medical_services,
      Icons.school,
      Icons.sports,
      Icons.fitness_center,
    ];

    return await showDialog<CustomCategory>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Colors.green),
              const SizedBox(width: 12),
              const Text('Add New Category'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name *',
                    hintText: 'e.g., Marketing, Equipment',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of this category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Icon',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: availableIcons.length,
                    itemBuilder: (context, index) {
                      final icon = availableIcons[index];
                      final isSelected = icon == selectedIcon;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedIcon = icon;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purple.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.purple
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? Colors.purple
                                : Colors.grey.shade700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a category name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final settingsService = SettingsService();
                  final newCategory = CustomCategory(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    iconCodePoint: selectedIcon.codePoint.toString(),
                    enabled: true,
                    createdAt: DateTime.now(),
                  );

                  await settingsService.addCustomCategory(newCategory);

                  if (context.mounted) {
                    Navigator.of(context).pop(newCategory);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Category "${newCategory.name}" added successfully!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding category: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Category'),
            ),
          ],
        ),
      ),
    );
  }
}
