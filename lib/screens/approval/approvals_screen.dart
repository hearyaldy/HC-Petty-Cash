import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/project_report_provider.dart';
import '../../models/transaction.dart';
import '../../models/traveling_report.dart';
import '../../models/petty_cash_report.dart';
import '../../models/enums.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<ReportProvider>().loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    if (!authProvider.canApprove()) {
      return Scaffold(
        appBar: _buildTopBar(context, 0),
        drawer: const AppDrawer(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('Access Denied', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('You do not have permission to approve transactions', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin-hub'),
                icon: const Icon(Icons.home),
                label: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<dynamic>>(
      stream: _combineApprovalStreams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allItems = snapshot.data ?? [];
        final pendingTransactions = allItems.whereType<Transaction>().toList();
        final submittedTravelingReports = allItems
            .whereType<TravelingReport>()
            .toList();

        // Sort by creation date (newest first)
        pendingTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        submittedTravelingReports.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );

        final totalPending =
            pendingTransactions.length + submittedTravelingReports.length;

        return Scaffold(
          appBar: _buildTopBar(context, totalPending),
          drawer: const AppDrawer(),
          body: Column(
            children: [
              Builder(builder: (context) {
                final hPad = ResponsiveHelper.getScreenPadding(context);
                final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad.left, 14, hPad.right, 0),
                      child: _buildSummaryBanner(
                        context,
                        totalPending,
                        pendingTransactions.length,
                        submittedTravelingReports.length,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Expanded(
                child: totalPending == 0
                    ? _buildEmptyState()
                    : _buildCombinedApprovalsList(
                        pendingTransactions,
                        submittedTravelingReports,
                        authProvider,
                        transactionProvider,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTopBar(BuildContext context, int totalPending) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text('HC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Pending Approvals', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(
                            '$totalPending item${totalPending == 1 ? '' : 's'} awaiting review',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (totalPending > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$totalPending',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Summary banner ────────────────────────────────────────────────────────

  Widget _buildSummaryBanner(BuildContext context, int total, int transactions, int travel) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.85), cs.primary],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pending Approvals', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Review and approve submitted items',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Row(
            children: [
              _buildBannerStat('Total', total),
              const SizedBox(width: 20),
              _buildBannerStat('Transactions', transactions),
              const SizedBox(width: 20),
              _buildBannerStat('Travel', travel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 10)),
      ],
    );
  }

  Stream<List<dynamic>> _combineApprovalStreams() {
    final firestoreService = FirestoreService();

    // Stream for pending transactions directly from Firestore
    final transactionStream = firestoreService.pendingTransactionsStream();

    // Stream for submitted traveling reports
    final travelingStream = firestoreService.travelingReportsStream().map(
      (reports) => reports.where((r) => r.status == 'submitted').toList(),
    );

    // Combine the streams using StreamZip-like pattern
    return transactionStream.asyncMap((transactions) async {
      final travelingReports = await travelingStream.first;
      return [...transactions, ...travelingReports];
    });
  }


  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    final hPad = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
        margin: EdgeInsets.all(hPad.left),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'No pending approvals at the moment',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildCombinedApprovalsList(
    List<Transaction> transactions,
    List<TravelingReport> travelingReports,
    AuthProvider authProvider,
    TransactionProvider transactionProvider,
  ) {
    final reportProvider = context.watch<ReportProvider>();
    final totalItems = transactions.length + travelingReports.length;

    final hPad = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: hPad.left, vertical: 16),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Handle transactions first
        if (index < transactions.length) {
          final transaction = transactions[index];
          final report = reportProvider.reports
              .cast<PettyCashReport?>()
              .firstWhere(
                (r) => r?.id == transaction.reportId,
                orElse: () => null,
              );

          // Skip this item if report not found
          if (report == null) {
            return const SizedBox.shrink();
          }

          final cs = Theme.of(context).colorScheme;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              childrenPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade600,
                child: Icon(
                  _getCategoryIcon(transaction.category.toExpenseCategory()),
                  color: Colors.white,
                ),
              ),
              title: Text(
                transaction.description,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Report: ${report.reportNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${transaction.categoryDisplayName} • ${DateFormat('MMM d, y').format(transaction.date)}',
                  ),
                  Text(
                    'Receipt: ${transaction.receiptNo}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: Text(
                '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Amount',
                        '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                      ),
                      _buildDetailRow(
                        'Payment Method',
                        transaction.paymentMethod.paymentMethodDisplayName,
                      ),
                      _buildDetailRow('Receipt Number', transaction.receiptNo),
                      _buildDetailRow(
                        'Category',
                        transaction.categoryDisplayName,
                      ),
                      _buildDetailRow(
                        'Date',
                        DateFormat('MMM dd, yyyy').format(transaction.date),
                      ),
                      _buildDetailRow('Report', report.reportNumber),
                      _buildDetailRow('Department', report.department),
                      _buildDetailRow(
                        'Submitted',
                        DateFormat(
                          'MMM dd, yyyy HH:mm',
                        ).format(transaction.createdAt),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showRejectDialog(
                              transaction,
                              authProvider,
                              transactionProvider,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _approveTransaction(
                              transaction,
                              authProvider,
                              transactionProvider,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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
        } else {
          // Handle traveling reports
          final travelingIndex = index - transactions.length;
          final travelingReport = travelingReports[travelingIndex];

          final tcs = Theme.of(context).colorScheme;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: tcs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tcs.outlineVariant.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              childrenPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.cyan.shade700,
                child: const Icon(Icons.flight, color: Colors.white),
              ),
              title: Text(
                'Traveling Report: ${travelingReport.reportNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Purpose: ${travelingReport.purpose}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text('Destination: ${travelingReport.placeName}'),
                  Text(
                    'Submitted: ${DateFormat('MMM d, y').format(travelingReport.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: Text(
                '${AppConstants.currencySymbol}${travelingReport.grandTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Total Amount',
                        '${AppConstants.currencySymbol}${travelingReport.grandTotal.toStringAsFixed(2)}',
                      ),
                      _buildDetailRow('Purpose', travelingReport.purpose),
                      _buildDetailRow('Destination', travelingReport.placeName),
                      _buildDetailRow(
                        'Travel Dates',
                        '${DateFormat('MMM dd, yyyy').format(travelingReport.departureTime)} - ${DateFormat('MMM dd, yyyy').format(travelingReport.destinationTime)}',
                      ),
                      _buildDetailRow('Department', travelingReport.department),
                      _buildDetailRow(
                        'Submitted',
                        DateFormat(
                          'MMM dd, yyyy HH:mm',
                        ).format(travelingReport.createdAt),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showRejectTravelingReportDialog(
                              travelingReport,
                              authProvider,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _approveTravelingReport(
                              travelingReport,
                              authProvider,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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
      },
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

  Future<void> _approveTransaction(
    Transaction transaction,
    AuthProvider authProvider,
    TransactionProvider transactionProvider,
  ) async {
    final user = authProvider.currentUser!;

    await transactionProvider.approveTransaction(
      transaction.id,
      user.id,
      user.name,
      comments: 'Approved',
    );

    if (!mounted) return;

    final reportProvider = context.read<ReportProvider>();
    final projectReportProvider = context.read<ProjectReportProvider>();
    final txProvider = context.read<TransactionProvider>();

    await reportProvider.loadReports();
    await projectReportProvider.loadProjectReports();
    await txProvider.loadTransactions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showRejectDialog(
    Transaction transaction,
    AuthProvider authProvider,
    TransactionProvider transactionProvider,
  ) async {
    final commentsController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
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
                Expanded(
                  child: Text(
                    'Reject Transaction',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Are you sure you want to reject this transaction?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
                    final user = authProvider.currentUser!;
                    final txProvider = context.read<TransactionProvider>();
                    final projectProvider = context.read<ProjectReportProvider>();
                    final reportProvider = context.read<ReportProvider>();

                    await transactionProvider.rejectTransaction(
                      transaction.id,
                      user.id,
                      user.name,
                      comments: commentsController.text.isEmpty
                          ? 'Rejected'
                          : commentsController.text,
                    );

                    if (!context.mounted) return;
                    await txProvider.loadTransactions();
                    await projectProvider.loadProjectReports();
                    await reportProvider.loadReports();

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction rejected'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _approveTravelingReport(
    TravelingReport travelingReport,
    AuthProvider authProvider,
  ) async {
    final user = authProvider.currentUser!;
    final firestoreService = FirestoreService();

    try {
      final updatedReport = TravelingReport(
        id: travelingReport.id,
        reportNumber: travelingReport.reportNumber,
        reporterId: travelingReport.reporterId,
        reporterName: travelingReport.reporterName,
        department: travelingReport.department,
        reportDate: travelingReport.reportDate,
        purpose: travelingReport.purpose,
        placeName: travelingReport.placeName,
        departureTime: travelingReport.departureTime,
        destinationTime: travelingReport.destinationTime,
        totalMembers: travelingReport.totalMembers,
        travelLocation: travelingReport.travelLocation,
        mileageStart: travelingReport.mileageStart,
        mileageEnd: travelingReport.mileageEnd,
        perDiemTotal: travelingReport.perDiemTotal,
        perDiemDays: travelingReport.perDiemDays,
        status: 'approved',
        createdAt: travelingReport.createdAt,
        submittedAt: travelingReport.submittedAt,
        submittedBy: travelingReport.submittedBy,
        approvedAt: DateTime.now(),
        approvedBy: user.name,
        rejectionReason: null,
        notes: 'Approved',
        supportDocumentUrls: travelingReport.supportDocumentUrls,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateTravelingReport(updatedReport);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Traveling report approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve traveling report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRejectTravelingReportDialog(
    TravelingReport travelingReport,
    AuthProvider authProvider,
  ) async {
    final commentsController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reject Traveling Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Report: ${travelingReport.reportNumber}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Required)',
                border: OutlineInputBorder(),
                hintText: 'Please provide a reason for rejection...',
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (commentsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please provide a rejection reason'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _rejectTravelingReport(
                      travelingReport,
                      authProvider,
                      commentsController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reject'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectTravelingReport(
    TravelingReport travelingReport,
    AuthProvider authProvider,
    String comments,
  ) async {
    final firestoreService = FirestoreService();
    final messenger = ScaffoldMessenger.of(context);
    final txProvider = context.read<TransactionProvider>();
    final projectProvider = context.read<ProjectReportProvider>();
    final reportProvider = context.read<ReportProvider>();

    try {
      final updatedReport = TravelingReport(
        id: travelingReport.id,
        reportNumber: travelingReport.reportNumber,
        reporterId: travelingReport.reporterId,
        reporterName: travelingReport.reporterName,
        department: travelingReport.department,
        reportDate: travelingReport.reportDate,
        purpose: travelingReport.purpose,
        placeName: travelingReport.placeName,
        departureTime: travelingReport.departureTime,
        destinationTime: travelingReport.destinationTime,
        totalMembers: travelingReport.totalMembers,
        travelLocation: travelingReport.travelLocation,
        mileageStart: travelingReport.mileageStart,
        mileageEnd: travelingReport.mileageEnd,
        perDiemTotal: travelingReport.perDiemTotal,
        perDiemDays: travelingReport.perDiemDays,
        status: 'rejected',
        createdAt: travelingReport.createdAt,
        submittedAt: travelingReport.submittedAt,
        submittedBy: travelingReport.submittedBy,
        approvedAt: null,
        approvedBy: null,
        rejectionReason: comments,
        notes: null,
        supportDocumentUrls: travelingReport.supportDocumentUrls,
        updatedAt: DateTime.now(),
      );

      await firestoreService.updateTravelingReport(updatedReport);

      if (!mounted) return;

      // Reload all providers to update the UI
      await txProvider.loadTransactions();
      await projectProvider.loadProjectReports();
      await reportProvider.loadReports();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Traveling report rejected'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject traveling report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
