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
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    if (!authProvider.canApprove()) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have permission to approve transactions',
                  style: TextStyle(color: Colors.grey),
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
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildWelcomeHeader(totalPending),
                ),
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
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(int totalPending) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
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
              // Pending count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalPending Pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                      'Pending Approvals',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review and approve pending items',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.approval,
                  size: isMobile ? 36 : 48,
                  color: Colors.white,
                ),
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
    return Center(
      child: Column(
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange,
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.orange,
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

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
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

                    await transactionProvider.rejectTransaction(
                      transaction.id,
                      user.id,
                      user.name,
                      comments: commentsController.text.isEmpty
                          ? 'Rejected'
                          : commentsController.text,
                    );

                    if (!context.mounted) return;
                    await context
                        .read<TransactionProvider>()
                        .loadTransactions();
                    await context
                        .read<ProjectReportProvider>()
                        .loadProjectReports();
                    await context.read<ReportProvider>().loadReports();

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
      await context.read<TransactionProvider>().loadTransactions();
      await context.read<ProjectReportProvider>().loadProjectReports();
      await context.read<ReportProvider>().loadReports();

      ScaffoldMessenger.of(context).showSnackBar(
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
