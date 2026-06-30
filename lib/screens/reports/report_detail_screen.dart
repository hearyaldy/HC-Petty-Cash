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
import '../../services/ai_text_service.dart';
import '../../services/currency_conversion_pdf_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/icon_registry.dart';
import '../../utils/print_options_dialog.dart';
import '../../services/pdf_signature_helper.dart';

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
  final bool autoLaunchAddTransaction;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    this.autoLaunchAddTransaction = false,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  TransactionSortOption _sortOption = TransactionSortOption.receiptNoAsc;
  List<CustomCategory> _enabledCustomCategories = [];
  bool _pendingAutoAddTransaction = false;

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    _pendingAutoAddTransaction = widget.autoLaunchAddTransaction;
    // Only load data if not already loaded - avoid unnecessary reloads that can cause Firestore errors on web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reportProvider = context.read<ReportProvider>();
      final transactionProvider = context.read<TransactionProvider>();
      final projectReportProvider = context.read<ProjectReportProvider>();

      if (reportProvider.reports.isEmpty) {
        reportProvider.loadReports();
      }
      if (transactionProvider.transactions.isEmpty) {
        transactionProvider.loadTransactions();
      }
      if (projectReportProvider.projectReports.isEmpty) {
        projectReportProvider.loadProjectReports();
      }
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

    // Try to find the report first
    final report = reportProvider.reports.cast<PettyCashReport?>().firstWhere(
      (r) => r?.id == widget.reportId,
      orElse: () => null,
    );

    // Only show loading if report is not found AND still loading
    if (report == null &&
        (reportProvider.isLoading || reportProvider.reports.isEmpty)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        body: ResponsiveContainer(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildPageHeader(
                  title: 'Loading...',
                  subtitle: 'Loading report details',
                  showBackButton: false,
                  actions: [
                    _buildHeaderActionButton(
                      icon: Icons.home_outlined,
                      tooltip: 'Home',
                      onPressed: () => context.go('/admin-hub'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );
    }

    if (report == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        body: ResponsiveContainer(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildPageHeader(
                  title: 'Report',
                  subtitle: 'Report details are unavailable',
                  showBackButton: false,
                  actions: [
                    _buildHeaderActionButton(
                      icon: Icons.home_outlined,
                      tooltip: 'Home',
                      onPressed: () => context.go('/admin-hub'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Report not found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/admin-hub'),
                        icon: const Icon(Icons.home),
                        label: const Text('Go to Dashboard'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_pendingAutoAddTransaction) {
      _pendingAutoAddTransaction = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Only open if report is not closed
        if (report.statusEnum != ReportStatus.closed) {
          _showAddTransactionDialog(report);
        }
      });
    }

    final transactions = transactionProvider.transactions
        .where((t) => t.reportId == report.id)
        .toList();
    _sortTransactions(transactions); // Sort transactions

    final pageHeaderActions = <Widget>[
      _buildHeaderActionButton(
        icon: Icons.home_outlined,
        tooltip: 'Home',
        onPressed: () => context.go('/admin-hub'),
      ),
      if (report.status != ReportStatus.closed.name)
        _buildHeaderActionButton(
          icon: Icons.add,
          tooltip: 'Add Transaction',
          onPressed: () => _showAddTransactionDialog(report),
        ),
      Theme(
        data: Theme.of(context).copyWith(
          popupMenuTheme: PopupMenuThemeData(
            color: Colors.white,
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          tooltip: 'More Actions',
          onSelected: (value) async {
            if (value == 'edit') {
              await _showEditReportDialog(report, reportProvider);
            } else if (value == 'export_excel') {
              await _exportExcel(report, transactions);
            } else if (value == 'export_pdf') {
              await _exportPdf(report, transactions);
            } else if (value == 'export_advance_settlement_pdf') {
              await _exportAdvanceSettlementPdf(report, transactions);
            } else if (value == 'print_all_support_docs') {
              _showPrintAllSupportDocumentsDialog(report, transactions);
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
            const PopupMenuItem(
              value: 'export_advance_settlement_pdf',
              child: Row(
                children: [
                  Icon(Icons.request_page),
                  SizedBox(width: 8),
                  Text('Export Advance Settlement'),
                ],
              ),
            ),
            if (transactions.any((t) => t.supportDocumentUrls.isNotEmpty))
              const PopupMenuItem(
                value: 'print_all_support_docs',
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Print All Support Docs'),
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
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(
                title: report.reportNumber,
                subtitle:
                    '${report.department} • Created ${DateFormat('MMM d, y').format(report.createdAt)}',
                actions: pageHeaderActions,
                showBackButton: true,
                status: report.statusEnum,
              ),
              const SizedBox(height: 24),
              _buildReportHeader(report),
              const SizedBox(height: 24),
              _buildFinancialSummary(report, transactions),
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

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        foregroundColor: Colors.white,
        minimumSize: const Size(36, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPageHeader({
    required String title,
    String? subtitle,
    List<Widget> actions = const [],
    bool showBackButton = true,
    ReportStatus? status,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBackButton)
                _buildHeaderActionButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/reports');
                    }
                  },
                )
              else
                const SizedBox(width: 40),
              const Spacer(),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          if (status != null) ...[
            _buildStatusChip(status),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportHeader(PettyCashReport report) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
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
              _buildStatusChipColored(report.statusEnum),
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
          if (report.purpose != null && report.purpose!.isNotEmpty)
            _buildDetailRow('Purpose', report.purpose!),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusChipColored(ReportStatus status) {
    final cs = Theme.of(context).colorScheme;
    Color chipColor;

    switch (status) {
      case ReportStatus.draft:
        chipColor = Colors.grey.shade600;
        break;
      case ReportStatus.submitted:
        chipColor = cs.primary;
        break;
      case ReportStatus.underReview:
        chipColor = Colors.orange.shade600;
        break;
      case ReportStatus.approved:
        chipColor = Colors.green.shade600;
        break;
      case ReportStatus.closed:
        chipColor = Colors.purple.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          color: chipColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(
    PettyCashReport report,
    List<Transaction> transactions,
  ) {
    final cs = Theme.of(context).colorScheme;

    // Compute live from in-memory transactions so the UI is always up-to-date
    // even before Firestore persists the recalculated stored fields.
    // This matches the PDF export logic which also derives values on-the-fly.
    final liveTotalDisbursements =
        transactions.fold<double>(0, (sum, t) => sum + t.amount);
    final liveCashOnHand = report.openingBalance - liveTotalDisbursements;
    final liveClosingBalance = liveCashOnHand;
    final liveVariance = liveClosingBalance - report.openingBalance + liveTotalDisbursements;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
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
                  Theme.of(context).colorScheme.primary,
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAmountCard(
                  'Total Disbursements',
                  liveTotalDisbursements,
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
                  liveCashOnHand,
                  Colors.orange,
                  Icons.payments,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAmountCard(
                  'Closing Balance',
                  liveClosingBalance,
                  Colors.green,
                  Icons.account_balance,
                ),
              ),
            ],
          ),
          if (liveVariance != 0) ...[
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
                          '${AppConstants.currencySymbol}${liveVariance.abs().toStringAsFixed(2)} ${liveVariance > 0 ? 'over' : 'under'}',
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = <Widget>[
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
                    IconButton(
                      onPressed: () => _printAllVouchers(report, transactions),
                      icon: const Icon(Icons.receipt_long),
                      tooltip: 'Print All Vouchers',
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
                ];

                final isNarrow = constraints.maxWidth < 520;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transactions',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: actions,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Transactions',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: actions,
                    ),
                  ],
                );
              },
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
                  return _buildTransactionItem(
                    transaction,
                    authProvider,
                    report: report,
                    index: index,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    Transaction transaction,
    AuthProvider authProvider, {
    required PettyCashReport report,
    required int index,
  }) {
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
        _buildSupportDocumentButton(transaction, notes: report.notes),
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
            if (authProvider.canUploadSupportDocument())
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
          'No. ${index + 1}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          transaction.description,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
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

  Widget _buildSupportDocumentButton(Transaction transaction, {String? notes}) {
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final hasDocument = transaction.supportDocumentUrl != null;
    final hasMultipleDocuments = transaction.supportDocumentUrls.length > 1;
    final canUpload = context.read<AuthProvider>().canUploadSupportDocument();

    final hasForeignExchange = transaction.foreignCurrency != null &&
        transaction.foreignAmount != null &&
        transaction.exchangeRate != null &&
        transaction.exchangeRateDate != null;

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'view') {
          _showSupportDocumentPreview(transaction, notes: notes);
        } else if (value == 'upload') {
          _showSupportDocumentUploadDialog(transaction);
        } else if (value == 'camera') {
          _showSupportDocumentUploadDialog(transaction, fromCamera: true);
        } else if (value == 'print_single') {
          _printSingleSupportDocument(transaction, notes: notes);
        } else if (value == 'print_select') {
          _showPrintSupportDocumentDialog(transaction);
        } else if (value == 'print_exchange_rate') {
          _printExchangeRateDoc(transaction);
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
        if (hasDocument && !hasMultipleDocuments)
          const PopupMenuItem(
            value: 'print_single',
            child: Row(
              children: [
                Icon(Icons.print, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text('Print Document'),
              ],
            ),
          ),
        if (hasMultipleDocuments)
          const PopupMenuItem(
            value: 'print_select',
            child: Row(
              children: [
                Icon(Icons.print, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text('Print Documents'),
              ],
            ),
          ),
        if (canUpload)
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
        if (canUpload && isMobile)
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
        if (hasForeignExchange)
          const PopupMenuItem(
            value: 'print_exchange_rate',
            child: Row(
              children: [
                Icon(Icons.currency_exchange, size: 18, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Print Exchange Rate Doc'),
              ],
            ),
          ),
      ],
    );
  }

  void _showSupportDocumentPreview(Transaction transaction, {String? notes}) {
    if (transaction.supportDocumentUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => SupportDocumentPreview(
        documentUrl: transaction.supportDocumentUrl!,
        transactionReceiptNo: transaction.receiptNo,
        description: transaction.description,
        amount: transaction.amount,
        notes: notes,
      ),
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

  Future<void> _printSingleSupportDocument(Transaction transaction, {String? notes}) async {
    if (transaction.supportDocumentUrls.isEmpty) return;

    try {
      final voucherService = VoucherExportService();
      await voucherService.printSupportDocument(
        transaction.supportDocumentUrls.first,
        transaction.receiptNo,
        description: transaction.description,
        amount: transaction.amount,
        notes: notes ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrintSupportDocumentDialog(Transaction transaction) {
    if (transaction.supportDocumentUrls.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => SupportDocumentSelectionDialog(
        documentUrls: transaction.supportDocumentUrls,
        transactionReceiptNo: transaction.receiptNo,
        description: transaction.description,
        amount: transaction.amount,
      ),
    );
  }

  /// Print the currency conversion support document for an existing transaction
  /// that was saved with foreign exchange data.
  Future<void> _printExchangeRateDoc(Transaction transaction) async {
    if (transaction.foreignCurrency == null ||
        transaction.foreignAmount == null ||
        transaction.exchangeRate == null ||
        transaction.exchangeRateDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing exchange rate information for this transaction'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final thbAmount = transaction.foreignAmount! * transaction.exchangeRate!;
      final convPdfService = CurrencyConversionPdfService();
      await convPdfService.printConversionPage(
        foreignCurrency: transaction.foreignCurrency!,
        foreignAmount: transaction.foreignAmount!,
        exchangeRate: transaction.exchangeRate!,
        exchangeRateDate: transaction.exchangeRateDate!,
        thbAmount: thbAmount,
        receiptNo: transaction.receiptNo,
        description: transaction.description,
        transactionDate: transaction.date,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing exchange rate document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrintAllSupportDocumentsDialog(
    PettyCashReport report,
    List<Transaction> transactions,
  ) {
    // Collect all support document URLs from all transactions
    final allDocumentUrls = <String>[];
    // Map document URL to its transaction details (amount, description, receiptNo)
    final documentDetails = <String, Map<String, dynamic>>{};

    for (final transaction in transactions) {
      for (final url in transaction.supportDocumentUrls) {
        allDocumentUrls.add(url);
        documentDetails[url] = {
          'amount': transaction.amount,
          'description': transaction.description,
          'receiptNo': transaction.receiptNo,
        };
      }
    }

    if (allDocumentUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No support documents found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Calculate total amount from all transactions with support documents
    final totalAmount = transactions
        .where((t) => t.supportDocumentUrls.isNotEmpty)
        .fold<double>(0, (sum, t) => sum + t.amount);

    showDialog(
      context: context,
      builder: (context) => SupportDocumentSelectionDialog(
        documentUrls: allDocumentUrls,
        transactionReceiptNo: report.reportNumber,
        description: 'All Support Documents - ${report.department}',
        amount: totalAmount,
        documentDetails: documentDetails,
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
      case ExpenseCategory.medicalReimbursement:
        return Icons.local_hospital;
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

      return iconFromCodePoint(custom.iconCodePoint);
    }

    return _getTransactionIcon(transaction.categoryEnum);
  }

  String _foreignCurrencySymbol(String code) {
    switch (code) {
      case 'MYR': return 'RM';
      case 'USD': return '\$';
      case 'THB': return '฿';
      default: return code;
    }
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
      case ExpenseCategory.medicalReimbursement:
        return Icons.local_hospital;
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

    // Medical claim variables
    bool isMedicalClaim = false;
    MedicalClaimType medicalClaimType = MedicalClaimType.outPatient;

    // Currency exchange variables
    bool hasCurrencyExchange = false;
    String selectedForeignCurrency = 'MYR';
    final foreignAmountController = TextEditingController();
    final exchangeRateController = TextEditingController();
    DateTime exchangeRateDate = DateTime.now();
    bool isFetchingRate = false;
    String? exchangeRateNote;

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
        builder: (context, setState) {
          // Calculate reimbursement amount for medical claims
          final totalBill = double.tryParse(amountController.text) ?? 0;
          final reimbursementAmount = totalBill * medicalClaimType.reimbursementRate;

          return Container(
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
                          // Transaction Type Toggle
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isMedicalClaim = false;
                                        selectedCategory = ExpenseCategory.other.name;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !isMedicalClaim ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !isMedicalClaim
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            size: 20,
                                            color: !isMedicalClaim ? Colors.blue : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Regular',
                                            style: TextStyle(
                                              fontWeight: !isMedicalClaim ? FontWeight.bold : FontWeight.normal,
                                              color: !isMedicalClaim ? Colors.blue : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isMedicalClaim = true;
                                        selectedCategory = ExpenseCategory.medicalReimbursement.name;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isMedicalClaim ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: isMedicalClaim
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.local_hospital,
                                            size: 20,
                                            color: isMedicalClaim ? Colors.teal : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Medical Claim',
                                            style: TextStyle(
                                              fontWeight: isMedicalClaim ? FontWeight.bold : FontWeight.normal,
                                              color: isMedicalClaim ? Colors.teal : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Medical Claim Type (only shown for medical claims)
                          if (isMedicalClaim) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Medical Claim Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              medicalClaimType = MedicalClaimType.outPatient;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: medicalClaimType == MedicalClaimType.outPatient
                                                  ? Colors.blue.withValues(alpha: 0.2)
                                                  : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: medicalClaimType == MedicalClaimType.outPatient
                                                    ? Colors.blue
                                                    : Colors.grey.shade300,
                                                width: medicalClaimType == MedicalClaimType.outPatient ? 2 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'OP',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: medicalClaimType == MedicalClaimType.outPatient
                                                        ? Colors.blue
                                                        : Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Out Patient',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  '75% Reimburse',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              medicalClaimType = MedicalClaimType.inPatient;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: medicalClaimType == MedicalClaimType.inPatient
                                                  ? Colors.orange.withValues(alpha: 0.2)
                                                  : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: medicalClaimType == MedicalClaimType.inPatient
                                                    ? Colors.orange
                                                    : Colors.grey.shade300,
                                                width: medicalClaimType == MedicalClaimType.inPatient ? 2 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'IP',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: medicalClaimType == MedicalClaimType.inPatient
                                                        ? Colors.orange
                                                        : Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'In Patient',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  '90% Reimburse',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

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
                                decoration: InputDecoration(
                                  labelText: isMedicalClaim ? 'Hospital/Clinic Name' : 'Paid to',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(isMedicalClaim ? Icons.local_hospital : Icons.person),
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return isMedicalClaim
                                        ? 'Please enter the hospital/clinic name'
                                        : 'Please enter who this was paid to';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: isMedicalClaim ? 'Medical Treatment Description' : 'Description (For)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.description),
                              hintText: isMedicalClaim ? 'e.g., Doctor consultation, Medicine, Lab tests' : null,
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
                              labelText: isMedicalClaim ? 'Total Medical Bill' : 'Amount',
                              border: const OutlineInputBorder(),
                              prefixText: '${AppConstants.currencySymbol} ',
                              prefixIcon: const Icon(Icons.money),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: isMedicalClaim ? (value) => setState(() {}) : null,
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

                          // Show reimbursement calculation for medical claims
                          if (isMedicalClaim && totalBill > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reimbursement Amount (${(medicalClaimType.reimbursementRate * 100).toInt()}%)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${AppConstants.currencySymbol} ${reimbursementAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Currency Exchange Section
                          Container(
                            decoration: BoxDecoration(
                              color: hasCurrencyExchange
                                  ? Colors.orange.withValues(alpha: 0.05)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasCurrencyExchange
                                    ? Colors.orange.shade300
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Toggle header
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() {
                                    hasCurrencyExchange = !hasCurrencyExchange;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.currency_exchange,
                                          size: 20,
                                          color: hasCurrencyExchange
                                              ? Colors.orange.shade700
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Currency Exchange',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: hasCurrencyExchange
                                                  ? Colors.orange.shade700
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: hasCurrencyExchange,
                                          onChanged: (v) => setState(
                                              () => hasCurrencyExchange = v),
                                          activeThumbColor: Colors.orange.shade700,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (hasCurrencyExchange) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Currency selector
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: DropdownButtonFormField<
                                                  String>(
                                                initialValue: selectedForeignCurrency,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'From Currency',
                                                  border: OutlineInputBorder(),
                                                  prefixIcon:
                                                      Icon(Icons.flag),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 14),
                                                ),
                                                items: const [
                                                  DropdownMenuItem(
                                                      value: 'MYR',
                                                      child: Text(
                                                          'MYR (Ringgit)')),
                                                  DropdownMenuItem(
                                                      value: 'USD',
                                                      child: Text(
                                                          'USD (US Dollar)')),
                                                  DropdownMenuItem(
                                                      value: 'THB',
                                                      child: Text(
                                                          'THB (Thai Baht)')),
                                                ],
                                                onChanged: (v) {
                                                  if (v != null) {
                                                    setState(() =>
                                                        selectedForeignCurrency =
                                                            v);
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward,
                                                color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: InputDecorator(
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'To',
                                                  border: OutlineInputBorder(),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 14),
                                                ),
                                                child: const Text('THB',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Foreign amount
                                        TextFormField(
                                          controller: foreignAmountController,
                                          decoration: InputDecoration(
                                            labelText:
                                                'Amount in $selectedForeignCurrency',
                                            border: const OutlineInputBorder(),
                                            prefixIcon:
                                                const Icon(Icons.money),
                                            prefixText:
                                                '${_foreignCurrencySymbol(selectedForeignCurrency)} ',
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                  decimal: true),
                                          onChanged: (_) => setState(() {}),
                                          validator: (v) {
                                            if (hasCurrencyExchange &&
                                                (v == null || v.isEmpty)) {
                                              return 'Enter foreign amount';
                                            }
                                            if (v != null &&
                                                v.isNotEmpty &&
                                                double.tryParse(v) == null) {
                                              return 'Invalid number';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                        // Exchange rate date + AI fetch
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () async {
                                                  final d =
                                                      await showDatePicker(
                                                    context: context,
                                                    initialDate:
                                                        exchangeRateDate,
                                                    firstDate: DateTime(2020),
                                                    lastDate: DateTime.now(),
                                                  );
                                                  if (d != null) {
                                                    setState(() =>
                                                        exchangeRateDate = d);
                                                  }
                                                },
                                                child: InputDecorator(
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText:
                                                        'Rate Date',
                                                    border:
                                                        OutlineInputBorder(),
                                                    prefixIcon: Icon(
                                                        Icons.calendar_today),
                                                  ),
                                                  child: Text(
                                                    DateFormat('dd/MM/yyyy')
                                                        .format(
                                                            exchangeRateDate),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              height: 56,
                                              child: ElevatedButton.icon(
                                                style:
                                                    ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.indigo,
                                                  foregroundColor:
                                                      Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                                onPressed: isFetchingRate
                                                    ? null
                                                    : () async {
                                                        setState(() =>
                                                            isFetchingRate =
                                                                true);
                                                        final aiService =
                                                            AITextService();
                                                        final result =
                                                            await aiService
                                                                .getExchangeRate(
                                                          fromCurrency:
                                                              selectedForeignCurrency,
                                                          date:
                                                              exchangeRateDate,
                                                        );
                                                        setState(() {
                                                          isFetchingRate =
                                                              false;
                                                          if (result.success &&
                                                              result.rate !=
                                                                  null) {
                                                            exchangeRateController
                                                                    .text =
                                                                result.rate!
                                                                    .toStringAsFixed(
                                                                        4);
                                                            exchangeRateNote =
                                                                result.note;
                                                          } else {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    result.error ??
                                                                        'Failed to fetch rate'),
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        });
                                                      },
                                                icon: isFetchingRate
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Icon(Icons.auto_awesome,
                                                        size: 18),
                                                label: const Text('AI Rate'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Exchange rate input
                                        TextFormField(
                                          controller: exchangeRateController,
                                          decoration: InputDecoration(
                                            labelText:
                                                '1 $selectedForeignCurrency = ? THB',
                                            border: const OutlineInputBorder(),
                                            prefixIcon:
                                                const Icon(Icons.swap_horiz),
                                            helperText: exchangeRateNote,
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                  decimal: true),
                                          onChanged: (_) => setState(() {}),
                                          validator: (v) {
                                            if (hasCurrencyExchange &&
                                                (v == null || v.isEmpty)) {
                                              return 'Enter exchange rate';
                                            }
                                            if (v != null &&
                                                v.isNotEmpty &&
                                                double.tryParse(v) == null) {
                                              return 'Invalid number';
                                            }
                                            return null;
                                          },
                                        ),

                                        // Computed THB amount
                                        if (foreignAmountController
                                                .text.isNotEmpty &&
                                            exchangeRateController
                                                .text.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Builder(builder: (ctx) {
                                            final foreign = double.tryParse(
                                                    foreignAmountController
                                                        .text) ??
                                                0;
                                            final rate = double.tryParse(
                                                    exchangeRateController
                                                        .text) ??
                                                0;
                                            final thb = foreign * rate;
                                            return Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.orange.shade200),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Converted Amount (THB)',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '฿ ${thb.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.orange,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  OutlinedButton.icon(
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          Colors.orange
                                                              .shade700,
                                                      side: BorderSide(
                                                          color: Colors.orange
                                                              .shade300),
                                                    ),
                                                    onPressed: () async {
                                                      final convPdfService =
                                                          CurrencyConversionPdfService();
                                                      await convPdfService
                                                          .printConversionPage(
                                                        foreignCurrency:
                                                            selectedForeignCurrency,
                                                        foreignAmount: foreign,
                                                        exchangeRate: rate,
                                                        exchangeRateDate:
                                                            exchangeRateDate,
                                                        thbAmount: thb,
                                                        receiptNo:
                                                            receiptNoController
                                                                .text,
                                                        description:
                                                            descriptionController
                                                                .text,
                                                        transactionDate:
                                                            selectedDate,
                                                      );
                                                    },
                                                    icon: const Icon(
                                                        Icons.print, size: 16),
                                                    label: const Text(
                                                        'Print Support Doc'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Project selection dropdown
                          DropdownButtonFormField<String?>(
                            initialValue: selectedProjectId,
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

                          // Category dropdown (hidden for medical claims since it's auto-set)
                          if (!isMedicalClaim)
                            DropdownButtonFormField<String>(
                              initialValue: selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: [
                                // Default categories (exclude medicalReimbursement for regular transactions)
                                ...ExpenseCategory.values
                                    .where((c) => c != ExpenseCategory.medicalReimbursement)
                                    .map((category) {
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
                                          iconFromCodePoint(
                                            category.iconCodePoint,
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

                          if (!isMedicalClaim) const SizedBox(height: 16),

                          DropdownButtonFormField<PaymentMethod>(
                            initialValue: selectedPaymentMethod,
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
                                style: isMedicalClaim
                                    ? ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                      )
                                    : null,
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    final transactionProvider = context
                                        .read<TransactionProvider>();
                                    final authProvider = context
                                        .read<AuthProvider>();

                                    final ExpenseCategory categoryEnum;
                                    String? customCategoryName;

                                    if (isMedicalClaim) {
                                      // For medical claims, always use medicalReimbursement category
                                      categoryEnum = ExpenseCategory.medicalReimbursement;
                                      // Store medical claim type info in custom category field
                                      customCategoryName = '${medicalClaimType.displayName} - ${(medicalClaimType.reimbursementRate * 100).toInt()}%';
                                    } else if (selectedCategory.startsWith('custom_')) {
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

                                    // For medical claims, store the reimbursement amount (not total bill)
                                    final amountToStore = isMedicalClaim
                                        ? reimbursementAmount
                                        : double.parse(amountController.text);

                                    // For medical claims, include total bill info in description
                                    final descriptionToStore = isMedicalClaim
                                        ? '${descriptionController.text} [Total Bill: ${AppConstants.currencySymbol}${double.parse(amountController.text).toStringAsFixed(2)}]'
                                        : descriptionController.text;

                                    await transactionProvider.createTransaction(
                                      reportId: report.id,
                                      projectId: selectedProjectId,
                                      date: selectedDate,
                                      receiptNo: receiptNoController.text,
                                      description: descriptionToStore,
                                      category: categoryEnum,
                                      customCategory: customCategoryName,
                                      amount: amountToStore,
                                      paymentMethod: selectedPaymentMethod,
                                      requestorId: authProvider.currentUser!.id,
                                      paidTo: paidToController.text,
                                      foreignCurrency: hasCurrencyExchange ? selectedForeignCurrency : null,
                                      foreignAmount: hasCurrencyExchange ? double.tryParse(foreignAmountController.text) : null,
                                      exchangeRate: hasCurrencyExchange ? double.tryParse(exchangeRateController.text) : null,
                                      exchangeRateDate: hasCurrencyExchange ? exchangeRateDate : null,
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
                                        SnackBar(
                                          content: Text(
                                            isMedicalClaim
                                                ? 'Medical claim added - Reimbursement: ${AppConstants.currencySymbol}${reimbursementAmount.toStringAsFixed(2)}'
                                                : 'Transaction added successfully',
                                          ),
                                          backgroundColor: isMedicalClaim ? Colors.teal : null,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(isMedicalClaim ? 'Add Medical Claim' : 'Add Transaction'),
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
    await showPrintOptionsDialog(
      context: context,
      title: 'Print Report',
      onPrint: () async {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error exporting PDF: $e')),
            );
          }
        }
      },
    );
  }

  Future<void> _exportAdvanceSettlementPdf(
    PettyCashReport report,
    List<Transaction> transactions,
  ) async {
    await showPrintOptionsDialog(
      context: context,
      title: 'Print Advance Settlement',
      onPrint: () async {
        try {
          final pdfService = PdfExportService();
          await pdfService.exportAdvanceSettlementReport(
            report,
            transactions: transactions,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Advance Settlement PDF exported successfully'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error exporting Advance Settlement PDF: $e')),
            );
          }
        }
      },
    );
  }

  Future<void> _showEditReportDialog(
    PettyCashReport report,
    ReportProvider provider,
  ) async {
    // Capture providers before the async gap to satisfy BuildContext safety rules.
    final transactionProvider = context.read<TransactionProvider>();

    final updatedReport = await showDialog<PettyCashReport>(
      context: context,
      builder: (context) => EditPettyCashReportDialog(report: report),
    );

    if (updatedReport != null) {
      // Recalculate financial totals with the updated opening balance so that
      // cashOnHand, closingBalance, and totalDisbursements stay in sync.
      final transactions = transactionProvider.transactions
          .where((t) => t.reportId == report.id)
          .toList();
      final recalculated = updatedReport.calculateTotals(transactions);

      await provider.updateReport(recalculated);
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

  Future<void> _printAllVouchers(
    PettyCashReport report,
    List<Transaction> transactions,
  ) async {
    if (transactions.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Print All Vouchers'),
        content: Text(
          'This will print ${transactions.length} vouchers. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Print'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final voucherService = VoucherExportService();
    try {
      await voucherService.printAllVouchers(transactions, report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All vouchers sent to print.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing vouchers: $e'),
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
    String? selectedProjectId = transaction.projectId;
    final projectReports = context.read<ProjectReportProvider>().projectReports;
    final settingsService = SettingsService();
    final customCategories = await settingsService.getCustomCategories();
    List<CustomCategory> enabledCustomCategories = customCategories
        .where((c) => c.enabled)
        .toList();

    // Medical claim variables - initialize from transaction
    bool isMedicalClaim = transaction.categoryEnum == ExpenseCategory.medicalReimbursement;
    MedicalClaimType medicalClaimType = MedicalClaimType.outPatient;

    // Try to determine medical claim type from description or notes
    if (isMedicalClaim) {
      final descLower = transaction.description.toLowerCase();
      if (descLower.contains('ip') || descLower.contains('in patient') || descLower.contains('inpatient') || descLower.contains('90%')) {
        medicalClaimType = MedicalClaimType.inPatient;
      }
    }

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

    // Currency exchange variables — initialise from the saved transaction
    bool hasCurrencyExchange = transaction.foreignCurrency != null;
    String selectedForeignCurrency = transaction.foreignCurrency ?? 'MYR';
    final foreignAmountController = TextEditingController(
      text: transaction.foreignAmount?.toString() ?? '',
    );
    final exchangeRateController = TextEditingController(
      text: transaction.exchangeRate != null
          ? transaction.exchangeRate!.toStringAsFixed(4)
          : '',
    );
    DateTime exchangeRateDate = transaction.exchangeRateDate ?? DateTime.now();
    bool isFetchingRate = false;
    String? exchangeRateNote;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate reimbursement amount for medical claims
          final totalBill = double.tryParse(amountController.text) ?? 0;
          final reimbursementAmount = totalBill * medicalClaimType.reimbursementRate;

          return AlertDialog(
            title: const Text('Edit Transaction'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Transaction Type Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isMedicalClaim = false;
                                  selectedCategory = ExpenseCategory.other.name;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !isMedicalClaim ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !isMedicalClaim
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 20,
                                      color: !isMedicalClaim ? Colors.blue : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Regular',
                                      style: TextStyle(
                                        fontWeight: !isMedicalClaim ? FontWeight.bold : FontWeight.normal,
                                        color: !isMedicalClaim ? Colors.blue : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isMedicalClaim = true;
                                  selectedCategory = ExpenseCategory.medicalReimbursement.name;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isMedicalClaim ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isMedicalClaim
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_hospital,
                                      size: 20,
                                      color: isMedicalClaim ? Colors.teal : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Medical Claim',
                                      style: TextStyle(
                                        fontWeight: isMedicalClaim ? FontWeight.bold : FontWeight.normal,
                                        color: isMedicalClaim ? Colors.teal : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Medical Claim Type (only shown for medical claims)
                    if (isMedicalClaim) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medical Claim Type',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        medicalClaimType = MedicalClaimType.outPatient;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: medicalClaimType == MedicalClaimType.outPatient
                                            ? Colors.blue.withValues(alpha: 0.2)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: medicalClaimType == MedicalClaimType.outPatient
                                              ? Colors.blue
                                              : Colors.grey.shade300,
                                          width: medicalClaimType == MedicalClaimType.outPatient ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'OP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: medicalClaimType == MedicalClaimType.outPatient
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Out Patient',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            '75% Reimburse',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        medicalClaimType = MedicalClaimType.inPatient;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: medicalClaimType == MedicalClaimType.inPatient
                                            ? Colors.orange.withValues(alpha: 0.2)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: medicalClaimType == MedicalClaimType.inPatient
                                              ? Colors.orange
                                              : Colors.grey.shade300,
                                          width: medicalClaimType == MedicalClaimType.inPatient ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'IP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: medicalClaimType == MedicalClaimType.inPatient
                                                  ? Colors.orange
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'In Patient',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            '90% Reimburse',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: isMedicalClaim ? 'Medical Treatment Description' : 'Description',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: isMedicalClaim ? 'Total Medical Bill' : 'Amount',
                        border: const OutlineInputBorder(),
                        prefixText: '${AppConstants.currencySymbol} ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: isMedicalClaim ? (value) => setState(() {}) : null,
                    ),

                    // Show reimbursement calculation for medical claims
                    if (isMedicalClaim && totalBill > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reimbursement Amount (${(medicalClaimType.reimbursementRate * 100).toInt()}%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${AppConstants.currencySymbol} ${reimbursementAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ],

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
                      decoration: InputDecoration(
                        labelText: isMedicalClaim ? 'Hospital/Clinic Name' : 'Paid To',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    // Project selection dropdown
                    DropdownButtonFormField<String?>(
                      initialValue: selectedProjectId,
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
                    // Hide category dropdown for medical claims (auto-set)
                    if (!isMedicalClaim)
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
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
                                    iconFromCodePoint(
                                      category.iconCodePoint,
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
                    if (!isMedicalClaim) const SizedBox(height: 16),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: selectedPaymentMethod,
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
                    const SizedBox(height: 16),

                    // ── Currency Exchange Section ──────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: hasCurrencyExchange
                            ? Colors.orange.withValues(alpha: 0.05)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasCurrencyExchange
                              ? Colors.orange.shade300
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Toggle header
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                setState(() => hasCurrencyExchange = !hasCurrencyExchange),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.currency_exchange,
                                    size: 20,
                                    color: hasCurrencyExchange
                                        ? Colors.orange.shade700
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Currency Exchange',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: hasCurrencyExchange
                                            ? Colors.orange.shade700
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: hasCurrencyExchange,
                                    onChanged: (v) =>
                                        setState(() => hasCurrencyExchange = v),
                                    activeThumbColor: Colors.orange.shade700,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (hasCurrencyExchange) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Currency selector row
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: selectedForeignCurrency,
                                          decoration: const InputDecoration(
                                            labelText: 'From Currency',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.flag),
                                            contentPadding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 14),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'MYR',
                                                child: Text('MYR (Ringgit)')),
                                            DropdownMenuItem(
                                                value: 'USD',
                                                child: Text('USD (US Dollar)')),
                                            DropdownMenuItem(
                                                value: 'THB',
                                                child: Text('THB (Thai Baht)')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() =>
                                                  selectedForeignCurrency = v);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward,
                                          color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'To',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 14),
                                          ),
                                          child: const Text('THB',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Foreign amount
                                  TextField(
                                    controller: foreignAmountController,
                                    decoration: InputDecoration(
                                      labelText:
                                          'Amount in $selectedForeignCurrency',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.money),
                                      prefixText:
                                          '${_foreignCurrencySymbol(selectedForeignCurrency)} ',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 12),

                                  // Rate date + AI Rate button
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate: exchangeRateDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime.now(),
                                            );
                                            if (d != null) {
                                              setState(
                                                  () => exchangeRateDate = d);
                                            }
                                          },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Rate Date',
                                              border: OutlineInputBorder(),
                                              prefixIcon:
                                                  Icon(Icons.calendar_today),
                                            ),
                                            child: Text(
                                              DateFormat('dd/MM/yyyy')
                                                  .format(exchangeRateDate),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 56,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigo,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          onPressed: isFetchingRate
                                              ? null
                                              : () async {
                                                  setState(() =>
                                                      isFetchingRate = true);
                                                  final aiService =
                                                      AITextService();
                                                  final result = await aiService
                                                      .getExchangeRate(
                                                    fromCurrency:
                                                        selectedForeignCurrency,
                                                    date: exchangeRateDate,
                                                  );
                                                  setState(() {
                                                    isFetchingRate = false;
                                                    if (result.success &&
                                                        result.rate != null) {
                                                      exchangeRateController
                                                              .text =
                                                          result.rate!
                                                              .toStringAsFixed(
                                                                  4);
                                                      exchangeRateNote =
                                                          result.note;
                                                    } else {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              result.error ??
                                                                  'Failed to fetch rate'),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  });
                                                },
                                          icon: isFetchingRate
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.auto_awesome,
                                                  size: 18),
                                          label: const Text('AI Rate'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Exchange rate field
                                  TextField(
                                    controller: exchangeRateController,
                                    decoration: InputDecoration(
                                      labelText:
                                          '1 $selectedForeignCurrency = ? THB',
                                      border: const OutlineInputBorder(),
                                      prefixIcon:
                                          const Icon(Icons.swap_horiz),
                                      helperText: exchangeRateNote,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) => setState(() {}),
                                  ),

                                  // Computed THB amount + print button
                                  if (foreignAmountController.text.isNotEmpty &&
                                      exchangeRateController
                                          .text.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Builder(builder: (ctx) {
                                      final foreign = double.tryParse(
                                              foreignAmountController.text) ??
                                          0;
                                      final rate = double.tryParse(
                                              exchangeRateController.text) ??
                                          0;
                                      final thb = foreign * rate;
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.orange.shade200),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Converted Amount (THB)',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[700]),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '฿ ${thb.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    Colors.orange.shade700,
                                                side: BorderSide(
                                                    color:
                                                        Colors.orange.shade300),
                                              ),
                                              onPressed: () async {
                                                final convPdfService =
                                                    CurrencyConversionPdfService();
                                                await convPdfService
                                                    .printConversionPage(
                                                  foreignCurrency:
                                                      selectedForeignCurrency,
                                                  foreignAmount: foreign,
                                                  exchangeRate: rate,
                                                  exchangeRateDate:
                                                      exchangeRateDate,
                                                  thbAmount: thb,
                                                  receiptNo:
                                                      receiptNoController.text,
                                                  description:
                                                      descriptionController
                                                          .text,
                                                  transactionDate: selectedDate,
                                                );
                                              },
                                              icon: const Icon(Icons.print,
                                                  size: 16),
                                              label: const Text(
                                                  'Print Support Doc'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ],
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

                  if (isMedicalClaim) {
                    categoryEnum = ExpenseCategory.medicalReimbursement;
                    customCategoryName = null;
                  } else if (selectedCategory.startsWith('custom_')) {
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

                  // Use the full Transaction constructor so nullable FX fields
                  // can be explicitly cleared when the toggle is off.
                  final updatedTransaction = Transaction(
                    id: transaction.id,
                    reportId: transaction.reportId,
                    projectId: selectedProjectId,
                    date: selectedDate,
                    receiptNo: receiptNoController.text,
                    description: descriptionController.text,
                    category: categoryEnum.name,
                    customCategory: customCategoryName,
                    amount: double.parse(amountController.text),
                    paymentMethod: selectedPaymentMethod.name,
                    requestorId: transaction.requestorId,
                    approverId: transaction.approverId,
                    status: transaction.status,
                    paidTo: paidToController.text.isEmpty
                        ? null
                        : paidToController.text,
                    attachmentUrls: transaction.attachmentUrls,
                    supportDocumentUrl: transaction.supportDocumentUrl,
                    supportDocumentUrls: transaction.supportDocumentUrls,
                    approvalHistory: transaction.approvalHistory,
                    createdAt: transaction.createdAt,
                    updatedAt: DateTime.now(),
                    foreignCurrency:
                        hasCurrencyExchange ? selectedForeignCurrency : null,
                    foreignAmount: hasCurrencyExchange
                        ? double.tryParse(foreignAmountController.text)
                        : null,
                    exchangeRate: hasCurrencyExchange
                        ? double.tryParse(exchangeRateController.text)
                        : null,
                    exchangeRateDate:
                        hasCurrencyExchange ? exchangeRateDate : null,
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
          );
        },
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
    await showPrintOptionsDialog(
      context: context,
      title: 'Print Transactions',
      onPrint: () async {
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

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(
        'assets/images/hope_channel_logo.png',
      );
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }

    // Define constants for pagination
    const maxRowsSinglePage = 25; // Leave room for summary/signature
    final needsSummaryPage = transactions.length > maxRowsSinglePage;
    final isAdvanceSettlement = report.reportType == 'advance_settlement';
    final reportSubtitle = isAdvanceSettlement
        ? (report.purpose?.trim().isNotEmpty == true
              ? report.purpose!.trim()
              : report.department)
        : report.department;
    final reportHeaderTitle = isAdvanceSettlement
        ? 'Advance Settlement Report'
        : 'Transactions Report';

    pw.Widget buildSummaryAndSignature() {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Balance Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
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
          pw.SizedBox(height: 12),

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
                    PdfSignatureHelper.slot(width: 100, height: 36),
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
                      'Name: Pr. Heary Healdy Sairin',
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
                    pw.SizedBox(height: 20),
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
                    pw.SizedBox(height: 20),
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
    }

    final totalAmount = transactions.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );
    final List<List<dynamic>> tableRows = transactions
        .map<List<dynamic>>(
          (transaction) => [
            dateFormat.format(transaction.date),
            transaction.receiptNo,
            transaction.description,
            transaction.categoryDisplayName,
            currencyFormat.format(transaction.amount),
            transaction.paymentMethodEnum.displayName,
            transaction.statusEnum.displayName,
          ],
        )
        .toList();

    tableRows.add([
      '',
      '',
      '',
      'Total',
      currencyFormat.format(totalAmount),
      '',
      '',
    ]);

    final totalRowNum = 1 + tableRows.length - 1;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldTtf,
          fontFallback: [pw.Font.helvetica()],
        ),
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Organization Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Add logo
              if (logoImage != null)
                pw.Container(
                  width: 40,
                  height: 40,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                )
              else
                pw.Container(
                  width: 40,
                  height: 40,
                  child: pw.Padding(
                    padding: pw.EdgeInsets.all(5),
                    child: pw.DecoratedBox(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          "H",
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              pw.SizedBox(width: 10),
              // Organization name and address
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      AppConstants.organizationName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        font: boldTtf,
                      ),
                    ),
                    pw.Text(
                      AppConstants.organizationAddress,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        font: ttf,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          if (isAdvanceSettlement)
            pw.Text(
              reportHeaderTitle,
              style: pw.TextStyle(font: boldTtf, fontSize: 18),
            ),
          if (isAdvanceSettlement) pw.SizedBox(height: 6),
          pw.Text(
            '${report.reportNumber} - $reportSubtitle',
            style: pw.TextStyle(font: boldTtf, fontSize: 20),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Period: ${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                ),
              ),
              if (isAdvanceSettlement)
                pw.Expanded(
                  child: pw.Text(
                    'Advance Taken Date: ${dateFormat.format(report.advanceTakenDate ?? report.periodStart)}',
                    style: pw.TextStyle(font: ttf, fontSize: 10),
                  ),
                ),
              pw.Expanded(
                child: pw.Text(
                  'Requested by: ${report.custodianName}',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'Date',
              'Receipt No',
              'Description',
              'Category',
              'Amount',
              'Payment',
              'Status',
            ],
            data: tableRows,
            border: pw.TableBorder.all(color: PdfColors.grey400),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(font: boldTtf, fontSize: 9),
            cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {4: pw.Alignment.centerRight},
            cellDecoration: (index, data, rowNum) => rowNum == totalRowNum
                ? pw.BoxDecoration(color: PdfColors.grey200)
                : const pw.BoxDecoration(),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(1),
            },
          ),
          pw.SizedBox(height: 8),
          if (needsSummaryPage) pw.NewPage(),
          if (needsSummaryPage) ...[
            pw.Text(
              '$reportHeaderTitle - Summary',
              style: pw.TextStyle(font: boldTtf, fontSize: 18),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${report.reportNumber} - $reportSubtitle',
              style: pw.TextStyle(font: ttf, fontSize: 12),
            ),
            pw.Text(
              'Period: ${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
              style: pw.TextStyle(font: ttf, fontSize: 10),
            ),
            pw.SizedBox(height: 16),
            buildSummaryAndSignature(),
          ] else ...[
            buildSummaryAndSignature(),
          ],
        ],
      ),
    );

    // Support documents are NOT included in transaction list printing
    // to avoid slow processing. Users can print support documents separately
    // from the voucher preview dialog.

    // Show preview dialog
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAdvanceSettlement
                          ? 'Advance Settlement Report Preview'
                          : 'Transactions Report Preview',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: PdfPreview(
                          build: (format) async => pdf.save(),
                          allowPrinting: true,
                          allowSharing: true,
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          canDebug: false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
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
    if (number < 0) return 'Minus ${_numberToWords(-number)}';

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
