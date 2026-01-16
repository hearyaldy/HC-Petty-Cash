import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../providers/auth_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/project_report.dart';
import '../../models/transaction.dart';
import '../../models/enums.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/edit_project_report_dialog.dart';

class ProjectReportDetailScreen extends StatefulWidget {
  final String reportId;
  final bool autoLaunchAddTransaction;

  const ProjectReportDetailScreen({
    super.key,
    required this.reportId,
    this.autoLaunchAddTransaction = false,
  });

  @override
  State<ProjectReportDetailScreen> createState() =>
      _ProjectReportDetailScreenState();
}

class _ProjectReportDetailScreenState extends State<ProjectReportDetailScreen> {
  bool _pendingAutoAddTransaction = false;

  @override
  void initState() {
    super.initState();
    _pendingAutoAddTransaction = widget.autoLaunchAddTransaction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<ProjectReportProvider>().loadProjectReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final projectReportProvider = context.watch<ProjectReportProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    final report = projectReportProvider.projectReports.firstWhere(
      (r) => r.id == widget.reportId,
      orElse: () => throw Exception('Project report not found'),
    );

    // Auto-launch add transaction dialog if requested
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
        .where((t) => t.projectId == report.id)
        .toList();

    // Calculate actual expenses from transactions
    final actualExpenses = transactions
        .where(
          (t) =>
              t.statusEnum == TransactionStatus.approved ||
              t.statusEnum == TransactionStatus.processed,
        )
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    final remainingBudget = report.budget - actualExpenses;

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
          if (report.statusEnum != ReportStatus.closed)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddTransactionDialog(report),
              tooltip: 'Add Transaction',
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await _showEditReportDialog(report, projectReportProvider);
              } else if (value == 'submit') {
                await _submitReport(report, projectReportProvider);
              } else if (value == 'approve') {
                await _approveReport(report, projectReportProvider);
              } else if (value == 'close') {
                await _closeReport(report, projectReportProvider);
              }
            },
            itemBuilder: (context) => [
              if (report.statusEnum == ReportStatus.draft ||
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
              if (report.statusEnum == ReportStatus.draft)
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
                  (report.statusEnum == ReportStatus.submitted ||
                      report.statusEnum == ReportStatus.underReview))
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Approve Report'),
                    ],
                  ),
                ),
              if (authProvider.canApprove() &&
                  report.statusEnum == ReportStatus.approved)
                const PopupMenuItem(
                  value: 'close',
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.purple),
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
              _buildHeader(report),
              const SizedBox(height: 24),
              _buildFinancialSummary(report, actualExpenses, remainingBudget),
              const SizedBox(height: 24),
              _buildTransactionsList(transactions, authProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ProjectReport report) {
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
                      report.projectName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.reportNumber,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(report.statusEnum),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.person,
                  'Custodian',
                  report.custodianName,
                  isWhite: true,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Project Period',
                  '${DateFormat('MMM dd, yyyy').format(report.startDate)} - ${DateFormat('MMM dd, yyyy').format(report.endDate)}',
                  isWhite: true,
                ),
                if (report.description != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.description,
                    'Description',
                    report.description!,
                    isWhite: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color color;
    Color backgroundColor;
    switch (status) {
      case ReportStatus.draft:
        color = Colors.white;
        backgroundColor = Colors.grey.shade700;
        break;
      case ReportStatus.submitted:
        color = Colors.white;
        backgroundColor = Colors.blue.shade700;
        break;
      case ReportStatus.underReview:
        color = Colors.white;
        backgroundColor = Colors.orange.shade700;
        break;
      case ReportStatus.approved:
        color = Colors.white;
        backgroundColor = Colors.green.shade700;
        break;
      case ReportStatus.closed:
        color = Colors.white;
        backgroundColor = Colors.purple.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isWhite = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isWhite ? Colors.white.withOpacity(0.9) : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: isWhite ? Colors.white : Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummary(
    ProjectReport report,
    double actualExpenses,
    double remainingBudget,
  ) {
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Financial Summary',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildAmountCard('Total Budget', report.budget, [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                ], Icons.account_balance_wallet),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAmountCard('Total Expenses', actualExpenses, [
                  Colors.red.shade400,
                  Colors.red.shade600,
                ], Icons.money_off),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAmountCard('Remaining Budget', remainingBudget, [
                  Colors.green.shade400,
                  Colors.green.shade600,
                ], Icons.savings),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProgressCard(
                  'Budget Used',
                  report.budget > 0
                      ? (actualExpenses / report.budget * 100)
                      : 0,
                  [Colors.orange.shade400, Colors.orange.shade600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(
    String label,
    double amount,
    List<Color> gradientColors,
    IconData icon,
  ) {
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(amount),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    String label,
    double percentage,
    List<Color> gradientColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percentage / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    List<dynamic> transactions,
    AuthProvider authProvider,
  ) {
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Project Transactions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: [
                  if (transactions.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () => _printTransactionsTable(
                          transactions.cast<Transaction>(),
                        ),
                        icon: Icon(Icons.print, color: Colors.purple.shade700),
                        tooltip: 'Print Transactions',
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTransactionDialog(
                      context.read<ProjectReportProvider>().projectReports.firstWhere(
                        (r) => r.id == widget.reportId,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: _getTransactionColor(
                        transaction.statusEnum,
                      ),
                      child: Icon(
                        _getTransactionIcon(transaction.categoryEnum),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      transaction.description,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${transaction.categoryEnum.displayName} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    trailing: Text(
                      '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getTransactionColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.draft:
        return Colors.grey;
      case TransactionStatus.pendingApproval:
        return Colors.blue;
      case TransactionStatus.approved:
        return Colors.green;
      case TransactionStatus.rejected:
        return Colors.red;
      case TransactionStatus.processed:
        return Colors.purple;
    }
  }

  IconData _getTransactionIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.travel:
        return Icons.directions_car;
      case ExpenseCategory.meals:
        return Icons.restaurant;
      case ExpenseCategory.supplies:
        return Icons.shopping_bag;
      case ExpenseCategory.utilities:
        return Icons.power;
      case ExpenseCategory.office:
        return Icons.business;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  Future<void> _showEditReportDialog(
    ProjectReport report,
    ProjectReportProvider provider,
  ) async {
    final updatedReport = await showDialog<ProjectReport>(
      context: context,
      builder: (context) => EditProjectReportDialog(report: report),
    );

    if (updatedReport != null) {
      try {
        await provider.updateProjectReport(updatedReport);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project report updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitReport(
    ProjectReport report,
    ProjectReportProvider provider,
  ) async {
    try {
      await provider.submitProjectReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project report submitted successfully'),
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

  Future<void> _approveReport(
    ProjectReport report,
    ProjectReportProvider provider,
  ) async {
    try {
      await provider.approveProjectReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project report approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _closeReport(
    ProjectReport report,
    ProjectReportProvider provider,
  ) async {
    try {
      await provider.closeProjectReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project report closed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error closing report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddTransactionDialog(ProjectReport report) async {
    // Show dialog explaining that transactions for project reports
    // should be added through petty cash reports
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Transaction to Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To add a transaction to this project report:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('1. Navigate to a Petty Cash Report'),
            const SizedBox(height: 8),
            const Text('2. Click "Add Transaction"'),
            const SizedBox(height: 8),
            const Text('3. Select this project in the "Link to Project" dropdown'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Project: ${report.projectName}',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/reports');
            },
            child: const Text('Go to Reports'),
          ),
        ],
      ),
    );
  }

  Future<void> _printTransactionsTable(List<Transaction> transactions) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
    );

    final projectReportProvider = context.read<ProjectReportProvider>();
    final report = projectReportProvider.projectReports.firstWhere(
      (r) => r.id == widget.reportId,
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

    // Define constants for pagination
    const maxRowsPerPage = 25; // Adjust based on content height
    final transactionChunks = <List<Transaction>>[];

    // Split transactions into chunks
    for (int i = 0; i < transactions.length; i += maxRowsPerPage) {
      final end = (i + maxRowsPerPage < transactions.length)
          ? i + maxRowsPerPage
          : transactions.length;
      transactionChunks.add(transactions.sublist(i, end));
    }

    // Add pages for each chunk of transactions
    for (int pageIndex = 0; pageIndex < transactionChunks.length; pageIndex++) {
      final chunk = transactionChunks[pageIndex];
      final isLastPage = pageIndex == transactionChunks.length - 1;
      final isFirstPage = pageIndex == 0;

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
                // Header (only on first page)
                if (isFirstPage) ...[
                  pw.Text(
                    'Project Transactions Report',
                    style: pw.TextStyle(font: boldTtf, fontSize: 20),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${report.reportNumber} - ${report.projectName}',
                    style: pw.TextStyle(font: ttf, fontSize: 12),
                  ),
                  pw.Text(
                    'Period: ${dateFormat.format(report.startDate)} - ${dateFormat.format(report.endDate)}',
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
                ],
                pw.SizedBox(height: 8),
                pw.Text(
                  'Page ${pageIndex + 1} of ${transactionChunks.length}',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                ),
                pw.SizedBox(height: 12),

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
                    // Header row (on each page where needed)
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
                    // Data rows for this chunk
                    ...chunk.map((transaction) {
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
                              transaction.categoryEnum.displayName,
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
                    // Total row only on the last page
                    if (isLastPage)
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

                // Only add balance summary and signature section on the last page
                if (isLastPage) ...[
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
              ],
            );
          },
        ),
      );
    }

    // Show preview dialog
    if (!mounted) return;
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
                    'Project Transactions Report Preview',
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
}
