import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io' show File;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/report_provider.dart';
import '../../models/transaction.dart';
import '../../models/petty_cash_report.dart';
import '../../models/enums.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/logger.dart';

enum TransactionSortField { date, amount, category, status }
enum SortOrder { ascending, descending }

class TransactionsSummaryScreen extends StatefulWidget {
  const TransactionsSummaryScreen({super.key});

  @override
  State<TransactionsSummaryScreen> createState() =>
      _TransactionsSummaryScreenState();
}

class _TransactionsSummaryScreenState extends State<TransactionsSummaryScreen> {
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  String? _selectedStatus;
  TransactionSortField _sortField = TransactionSortField.date;
  SortOrder _sortOrder = SortOrder.descending;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<ReportProvider>().loadReports();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    var filtered = List<Transaction>.from(transactions);

    // Filter by category
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered
          .where((t) => t.categoryDisplayName == _selectedCategory)
          .toList();
    }

    // Filter by payment method
    if (_selectedPaymentMethod != null && _selectedPaymentMethod != 'All') {
      filtered = filtered
          .where(
            (t) =>
                t.paymentMethod.paymentMethodDisplayName ==
                _selectedPaymentMethod,
          )
          .toList();
    }

    // Filter by status
    if (_selectedStatus != null && _selectedStatus != 'All') {
      filtered = filtered
          .where(
            (t) => t.status.transactionStatusDisplayName == _selectedStatus,
          )
          .toList();
    }

    // Filter by search text
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered
          .where(
            (t) =>
                t.description.toLowerCase().contains(searchLower) ||
                t.receiptNo.toLowerCase().contains(searchLower),
          )
          .toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case TransactionSortField.date:
          comparison = a.date.compareTo(b.date);
          break;
        case TransactionSortField.amount:
          comparison = a.amount.compareTo(b.amount);
          break;
        case TransactionSortField.category:
          comparison = a.categoryDisplayName.compareTo(b.categoryDisplayName);
          break;
        case TransactionSortField.status:
          comparison = a.status.compareTo(b.status);
          break;
      }
      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return filtered;
  }

  Map<String, double> _getCategorySummary(List<Transaction> transactions) {
    final summary = <String, double>{};
    for (var transaction in transactions) {
      final category = transaction.categoryDisplayName;
      summary[category] = (summary[category] ?? 0) + transaction.amount;
    }
    return summary;
  }

  Map<String, double> _getPaymentMethodSummary(List<Transaction> transactions) {
    final summary = <String, double>{};
    for (var transaction in transactions) {
      final method = transaction.paymentMethod.paymentMethodDisplayName;
      summary[method] = (summary[method] ?? 0) + transaction.amount;
    }
    return summary;
  }

  Map<String, int> _getStatusSummary(List<Transaction> transactions) {
    final summary = <String, int>{};
    for (var transaction in transactions) {
      final status = transaction.status.transactionStatusDisplayName;
      summary[status] = (summary[status] ?? 0) + 1;
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final reportProvider = context.watch<ReportProvider>();
    final user = authProvider.currentUser;
    final canViewAll = authProvider.canViewAllReports();

    // Filter transactions based on user role
    // Regular users only see transactions from their own reports
    final userReportIds = canViewAll
        ? null // null means show all
        : reportProvider.reports
              .where((r) => r.custodianId == user?.id)
              .map((r) => r.id)
              .toSet();

    final allTransactions = canViewAll
        ? transactionProvider.transactions
        : transactionProvider.transactions
              .where((t) => userReportIds?.contains(t.reportId) ?? false)
              .toList();

    final filteredTransactions = _getFilteredTransactions(allTransactions);

    final totalAmount = filteredTransactions.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    final categorySummary = _getCategorySummary(filteredTransactions);
    final paymentMethodSummary = _getPaymentMethodSummary(filteredTransactions);
    final statusSummary = _getStatusSummary(filteredTransactions);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: transactionProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: ResponsiveContainer(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildWelcomeHeader(
                          filteredTransactions.length,
                          totalAmount,
                        ),
                      ),
                      // Summary Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSummaryCards(
                          filteredTransactions.length,
                          totalAmount,
                          categorySummary,
                          paymentMethodSummary,
                          statusSummary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filters
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildFilters(allTransactions),
                      ),
                      const SizedBox(height: 24),

                      // Transactions Table
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildTransactionsTable(
                          filteredTransactions,
                          reportProvider,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWelcomeHeader(int transactionCount, double totalAmount) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
    );

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
                  _buildHeaderActionButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: () {
                      context.read<TransactionProvider>().loadTransactions();
                    },
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
                      'Transactions Summary',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$transactionCount transactions • ${currencyFormat.format(totalAmount)}',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              // Logo
              Image.asset(
                AppConstants.companyLogo,
                width: isMobile ? 40 : 50,
                height: isMobile ? 40 : 50,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      size: isMobile ? 28 : 36,
                      color: Colors.white,
                    ),
                  );
                },
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

  Widget _buildSummaryCards(
    int count,
    double total,
    Map<String, double> categorySummary,
    Map<String, double> paymentMethodSummary,
    Map<String, int> statusSummary,
  ) {
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
      decimalDigits: 0,
    );
    final isMobile = ResponsiveHelper.isMobile(context);

    // Calculate insights
    final avgTransaction = count > 0 ? total / count : 0.0;
    final topCategory = categorySummary.entries.isNotEmpty
        ? categorySummary.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final topPaymentMethod = paymentMethodSummary.entries.isNotEmpty
        ? paymentMethodSummary.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final totalStatusCount = statusSummary.values.fold(0, (a, b) => a + b);
    final approvedCount = statusSummary['Approved'] ?? 0;
    final approvalRate = totalStatusCount > 0 ? (approvedCount / totalStatusCount) * 100 : 0.0;

    // Category colors for charts
    final categoryColors = [
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.orange.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.indigo.shade400,
      Colors.amber.shade400,
      Colors.cyan.shade400,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Insights Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo.shade500, Colors.purple.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
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
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI-Powered Insights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildInsightChip(
                    icon: Icons.trending_up,
                    label: 'Avg. Transaction',
                    value: currencyFormat.format(avgTransaction),
                    color: Colors.white,
                  ),
                  if (topCategory != null)
                    _buildInsightChip(
                      icon: Icons.category,
                      label: 'Top Category',
                      value: topCategory.key,
                      color: Colors.white,
                    ),
                  _buildInsightChip(
                    icon: Icons.check_circle,
                    label: 'Approval Rate',
                    value: '${approvalRate.toStringAsFixed(1)}%',
                    color: Colors.white,
                  ),
                  if (topPaymentMethod != null)
                    _buildInsightChip(
                      icon: Icons.payment,
                      label: 'Preferred Payment',
                      value: topPaymentMethod.key,
                      color: Colors.white,
                    ),
                ],
              ),
              if (count > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _generateInsightText(
                            count,
                            total,
                            topCategory,
                            approvalRate,
                            avgTransaction,
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Stats Row
        Row(
          children: [
            Expanded(
              child: _buildQuickStatCard(
                icon: Icons.receipt_long,
                value: count.toString(),
                label: 'Transactions',
                gradient: [Colors.blue.shade400, Colors.blue.shade600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickStatCard(
                icon: Icons.attach_money,
                value: currencyFormat.format(total),
                label: 'Total Amount',
                gradient: [Colors.green.shade400, Colors.green.shade600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickStatCard(
                icon: Icons.show_chart,
                value: currencyFormat.format(avgTransaction),
                label: 'Average',
                gradient: [Colors.orange.shade400, Colors.orange.shade600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Category Distribution with Visual Chart
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.pie_chart, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Spending by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${categorySummary.length} categories',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Mini pie chart representation using progress bars
                    if (categorySummary.isNotEmpty && total > 0)
                      ...categorySummary.entries.toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final percentage = (item.value / total) * 100;
                        final color = categoryColors[index % categoryColors.length];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.key,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        currencyFormat.format(item.value),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                  minHeight: 8,
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
        ),
        const SizedBox(height: 16),

        // Payment Method & Status side by side
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPaymentMethodCard(paymentMethodSummary, total, currencyFormat)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatusCard(statusSummary, totalStatusCount)),
            ],
          )
        else ...[
          _buildPaymentMethodCard(paymentMethodSummary, total, currencyFormat),
          const SizedBox(height: 16),
          _buildStatusCard(statusSummary, totalStatusCount),
        ],
      ],
    );
  }

  Widget _buildInsightChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String value,
    required String label,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, size: 28, color: Colors.white),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    Map<String, double> paymentMethodSummary,
    double total,
    NumberFormat currencyFormat,
  ) {
    final methodColors = [
      Colors.orange.shade400,
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.purple.shade400,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: paymentMethodSummary.entries.toList().asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final percentage = total > 0 ? (item.value / total) * 100 : 0.0;
                final color = methodColors[index % methodColors.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            _getPaymentIcon(item.key),
                            color: color,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyFormat.format(item.value),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, int> statusSummary, int totalCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.teal.shade600],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.donut_large, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Status Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: statusSummary.entries.map((entry) {
                final percentage = totalCount > 0 ? (entry.value / totalCount) * 100 : 0.0;
                final color = _getStatusColor(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            _getStatusIcon(entry.key),
                            color: color,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          entry.value.toString(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _generateInsightText(
    int count,
    double total,
    MapEntry<String, double>? topCategory,
    double approvalRate,
    double avgTransaction,
  ) {
    final insights = <String>[];

    if (topCategory != null) {
      final percentage = (topCategory.value / total) * 100;
      insights.add('${topCategory.key} accounts for ${percentage.toStringAsFixed(0)}% of spending');
    }

    if (approvalRate >= 90) {
      insights.add('Excellent approval rate at ${approvalRate.toStringAsFixed(0)}%');
    } else if (approvalRate >= 70) {
      insights.add('Good approval rate - ${approvalRate.toStringAsFixed(0)}% transactions approved');
    } else if (approvalRate > 0) {
      insights.add('Consider reviewing rejection reasons - ${approvalRate.toStringAsFixed(0)}% approval rate');
    }

    if (count > 10) {
      insights.add('Active period with $count transactions recorded');
    }

    return insights.isNotEmpty ? insights.join('. ') + '.' : 'Add more transactions to see insights.';
  }

  IconData _getPaymentIcon(String method) {
    final lowerMethod = method.toLowerCase();
    if (lowerMethod.contains('cash')) return Icons.money;
    if (lowerMethod.contains('card') || lowerMethod.contains('credit')) return Icons.credit_card;
    if (lowerMethod.contains('transfer') || lowerMethod.contains('bank')) return Icons.account_balance;
    if (lowerMethod.contains('wallet') || lowerMethod.contains('digital')) return Icons.account_balance_wallet;
    return Icons.payment;
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('approved') || lowerStatus.contains('processed')) return Colors.green;
    if (lowerStatus.contains('pending')) return Colors.orange;
    if (lowerStatus.contains('rejected')) return Colors.red;
    if (lowerStatus.contains('draft')) return Colors.grey;
    return Colors.blue;
  }

  IconData _getStatusIcon(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('approved')) return Icons.check_circle;
    if (lowerStatus.contains('processed')) return Icons.verified;
    if (lowerStatus.contains('pending')) return Icons.pending;
    if (lowerStatus.contains('rejected')) return Icons.cancel;
    if (lowerStatus.contains('draft')) return Icons.edit_note;
    return Icons.info;
  }

  Widget _buildFilters(List<Transaction> transactions) {
    final isMobile = ResponsiveHelper.isMobile(context);

    // Get all unique categories from transactions (includes custom categories)
    final uniqueCategories = transactions
        .map((t) => t.categoryDisplayName)
        .toSet()
        .toList()
      ..sort();

    // Reset selected category if it's no longer valid
    final validSelectedCategory = _selectedCategory != null &&
            uniqueCategories.contains(_selectedCategory)
        ? _selectedCategory
        : null;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search field - full width
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: isMobile
                        ? 'Description or receipt #'
                        : 'Description or receipt number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isMobile ? 12 : 16,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // Filter dropdowns - responsive layout
                if (isMobile) ...[
                  // Mobile: Stack filters vertically in 2 columns
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: validSelectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All'),
                            ),
                            ...uniqueCategories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All'),
                            ),
                            ...TransactionStatus.values.map((status) {
                              return DropdownMenuItem(
                                value: status.displayName,
                                child: Text(
                                  status.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedStatus = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ...PaymentMethod.values.map((method) {
                        return DropdownMenuItem(
                          value: method.displayName,
                          child: Text(
                            method.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedPaymentMethod = value),
                  ),
                ] else
                  // Desktop/Tablet: All filters in a row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: validSelectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All'),
                            ),
                            ...uniqueCategories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All'),
                            ),
                            ...PaymentMethod.values.map((method) {
                              return DropdownMenuItem(
                                value: method.displayName,
                                child: Text(method.displayName),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedPaymentMethod = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All'),
                            ),
                            ...TransactionStatus.values.map((status) {
                              return DropdownMenuItem(
                                value: status.displayName,
                                child: Text(status.displayName),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedStatus = value),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: isMobile ? 12 : 16),
                // Sort options
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TransactionSortField>(
                        value: _sortField,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Sort By',
                          border: const OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isMobile ? 12 : 16,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TransactionSortField.date,
                            child: Text('Date'),
                          ),
                          DropdownMenuItem(
                            value: TransactionSortField.amount,
                            child: Text('Amount'),
                          ),
                          DropdownMenuItem(
                            value: TransactionSortField.category,
                            child: Text('Category'),
                          ),
                          DropdownMenuItem(
                            value: TransactionSortField.status,
                            child: Text('Status'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortField = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _sortOrder == SortOrder.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: Colors.blue.shade600,
                        ),
                        tooltip: _sortOrder == SortOrder.ascending
                            ? 'Ascending'
                            : 'Descending',
                        onPressed: () {
                          setState(() {
                            _sortOrder = _sortOrder == SortOrder.ascending
                                ? SortOrder.descending
                                : SortOrder.ascending;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(
    List<Transaction> transactions,
    ReportProvider reportProvider,
  ) {
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
    );
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Transactions (${transactions.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Export to PDF',
                  onPressed: () {
                    _exportToPdf(transactions, reportProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                border: TableBorder.all(color: Colors.grey.shade300),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Receipt No.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Payment Method',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Report',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: transactions.map((transaction) {
                  final report = reportProvider.reports
                      .cast<PettyCashReport?>()
                      .firstWhere(
                        (r) => r?.id == transaction.reportId,
                        orElse: () => null,
                      );
                  final reportNumber = report?.reportNumber ?? 'Unknown';

                  return DataRow(
                    cells: [
                      DataCell(Text(dateFormat.format(transaction.date))),
                      DataCell(Text(transaction.receiptNo)),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            transaction.description,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(Text(transaction.categoryDisplayName)),
                      DataCell(
                        Text(
                          transaction.paymentMethod.paymentMethodDisplayName,
                        ),
                      ),
                      DataCell(
                        Text(
                          currencyFormat.format(transaction.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(_buildStatusChip(transaction.statusEnum)),
                      DataCell(Text(reportNumber)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(TransactionStatus status) {
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
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _exportToPdf(
    List<Transaction> transactions,
    ReportProvider reportProvider,
  ) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy');
      final currencyFormat = NumberFormat.currency(
        symbol: '${AppConstants.currencySymbol} ',
      );

      // Calculate summaries
      final totalAmount = transactions.fold<double>(
        0,
        (sum, t) => sum + t.amount,
      );
      final categorySummary = _getCategorySummary(transactions);
      final paymentMethodSummary = _getPaymentMethodSummary(transactions);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            // Header
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Add logo if it exists - simplified approach for PDF
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
                            ),
                          ),
                          pw.Text(
                            AppConstants.organizationAddress,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'ALL TRANSACTIONS SUMMARY REPORT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated: ${dateFormat.format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            ),

            // Overall Summary
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'Total Transactions',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        transactions.length.toString(),
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(width: 1, height: 40, color: PdfColors.grey300),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Total Amount',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        currencyFormat.format(totalAmount),
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Category Breakdown
            pw.Text(
              'Breakdown by Category',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Category',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  ...categorySummary.entries.map(
                    (e) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            e.key,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            currencyFormat.format(e.value),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Payment Method Breakdown
            pw.Text(
              'Breakdown by Payment Method',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Payment Method',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  ...paymentMethodSummary.entries.map(
                    (e) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            e.key,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            currencyFormat.format(e.value),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Transactions Table
            pw.Text(
              'All Transactions (${transactions.length})',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FixedColumnWidth(60),
                6: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Date',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Receipt',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Description',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Category',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Payment',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Status',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                // Data Rows
                ...transactions.map((transaction) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          dateFormat.format(transaction.date),
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          transaction.receiptNo,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          transaction.description,
                          style: const pw.TextStyle(fontSize: 7),
                          maxLines: 2,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          transaction.categoryDisplayName,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          transaction.paymentMethod.paymentMethodDisplayName,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          currencyFormat.format(transaction.amount),
                          style: const pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          transaction.status.transactionStatusDisplayName,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final fileName =
          'transactions_summary_${dateFormat.format(DateTime.now()).replaceAll('/', '-')}.pdf';

      if (kIsWeb) {
        // Web platform - trigger download using printing package
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        // Mobile/Desktop platform
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final output = await File(filePath).writeAsBytes(bytes);
        AppLogger.info('PDF saved to ${output.path}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF exported successfully: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
      }
    }
  }
}
