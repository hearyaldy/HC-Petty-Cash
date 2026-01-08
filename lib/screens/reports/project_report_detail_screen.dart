import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/project_report.dart';
import '../../models/enums.dart';
import '../../utils/constants.dart';

class ProjectReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ProjectReportDetailScreen({super.key, required this.reportId});

  @override
  State<ProjectReportDetailScreen> createState() =>
      _ProjectReportDetailScreenState();
}

class _ProjectReportDetailScreenState extends State<ProjectReportDetailScreen> {
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
    final projectReportProvider = context.watch<ProjectReportProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    final report = projectReportProvider.projectReports.firstWhere(
      (r) => r.id == widget.reportId,
      orElse: () => throw Exception('Project report not found'),
    );

    final transactions = transactionProvider.transactions
        .where((t) => t.projectId == report.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(report.reportNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'submit') {
                await _submitReport(report, projectReportProvider);
              } else if (value == 'approve') {
                await _approveReport(report, projectReportProvider);
              } else if (value == 'close') {
                await _closeReport(report, projectReportProvider);
              }
            },
            itemBuilder: (context) => [
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(report),
            const SizedBox(height: 24),
            _buildFinancialSummary(report),
            const SizedBox(height: 24),
            _buildTransactionsList(transactions, authProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ProjectReport report) {
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
                        report.projectName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.reportNumber,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(report.statusEnum),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow(Icons.person, 'Custodian', report.custodianName),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Project Period',
              '${DateFormat('MMM dd, yyyy').format(report.startDate)} - ${DateFormat('MMM dd, yyyy').format(report.endDate)}',
            ),
            if (report.description != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.description,
                'Description',
                report.description!,
              ),
            ],
          ],
        ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildFinancialSummary(ProjectReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAmountCard(
                    'Total Budget',
                    report.budget,
                    Colors.blue,
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAmountCard(
                    'Total Expenses',
                    report.totalExpenses,
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
                    'Remaining Budget',
                    report.remainingBudget,
                    Colors.green,
                    Icons.savings,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProgressCard(
                    'Budget Used',
                    report.budget > 0
                        ? (report.totalExpenses / report.budget * 100)
                        : 0,
                    Colors.orange,
                  ),
                ),
              ],
            ),
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
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String label, double percentage, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    List<dynamic> transactions,
    AuthProvider authProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (transactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No transactions yet'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTransactionColor(
                        transaction.statusEnum,
                      ),
                      child: Icon(
                        _getTransactionIcon(transaction.categoryEnum),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(transaction.description),
                    subtitle: Text(
                      '${transaction.categoryEnum.displayName} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
                    ),
                    trailing: Text(
                      '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
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
}
