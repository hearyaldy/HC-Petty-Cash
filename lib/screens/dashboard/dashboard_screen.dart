import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/enums.dart';
import '../../utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReports();
      context.read<TransactionProvider>().loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reportProvider = context.watch<ReportProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final user = authProvider.currentUser;

    final allReports = reportProvider.reports;
    final myReports = user != null
        ? allReports.where((r) => r.custodianId == user.id).toList()
        : [];
    final draftReports = allReports
        .where((r) => r.status == ReportStatus.draft.name)
        .toList();
    final pendingApprovals = transactionProvider.getPendingApprovals();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user?.name ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.role.userRoleDisplayName ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, ${user?.name ?? ''}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            _buildStatCards(
              context,
              allReports.length,
              myReports.length,
              draftReports.length,
              pendingApprovals.length,
              authProvider.canApprove(),
            ),
            const SizedBox(height: 32),
            _buildQuickActions(context, authProvider),
            const SizedBox(height: 32),
            _buildRecentReports(context, myReports),
            if (authProvider.canApprove()) ...[
              const SizedBox(height: 32),
              _buildPendingApprovals(context, pendingApprovals),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(
    BuildContext context,
    int totalReports,
    int myReports,
    int draftReports,
    int pendingApprovals,
    bool canApprove,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Reports',
              totalReports.toString(),
              Icons.description,
              Colors.blue,
            ),
            _buildStatCard(
              'My Reports',
              myReports.toString(),
              Icons.person,
              Colors.green,
            ),
            _buildStatCard(
              'Draft Reports',
              draftReports.toString(),
              Icons.edit_document,
              Colors.orange,
            ),
            if (canApprove)
              _buildStatCard(
                'Pending Approvals',
                pendingApprovals.toString(),
                Icons.pending_actions,
                Colors.red,
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildActionButton(
              'New Report',
              Icons.add_circle,
              Colors.deepPurple,
              () => context.go('/reports/new'),
            ),
            _buildActionButton(
              'View All Reports',
              Icons.list,
              Colors.blue,
              () => context.go('/reports'),
            ),
            _buildActionButton(
              'Transactions Summary',
              Icons.receipt_long,
              Colors.teal,
              () => context.go('/transactions'),
            ),
            if (authProvider.canApprove())
              _buildActionButton(
                'Approvals',
                Icons.check_circle,
                Colors.green,
                () => context.go('/approvals'),
              ),
            if (authProvider.canManageUsers())
              _buildActionButton(
                'Manage Users',
                Icons.people,
                Colors.orange,
                () => context.go('/admin'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  Widget _buildRecentReports(BuildContext context, List reports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Recent Reports',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.go('/reports'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (reports.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No reports yet. Create your first report!'),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reports.length > 5 ? 5 : reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(report.statusEnum),
                    child: const Icon(Icons.description, color: Colors.white),
                  ),
                  title: Text(report.reportNumber),
                  subtitle: Text(
                    '${report.department} • ${report.status.reportStatusDisplayName}',
                  ),
                  trailing: Text(
                    '${AppConstants.currencySymbol}${report.totalDisbursements.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () => context.go('/reports/${report.id}'),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPendingApprovals(BuildContext context, List transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Approvals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.go('/approvals'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No pending approvals')),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length > 5 ? 5 : transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.pending, color: Colors.white),
                  ),
                  title: Text(transaction.description),
                  subtitle: Text(
                    '${transaction.category.expenseCategoryDisplayName} • ${transaction.receiptNo}',
                  ),
                  trailing: Text(
                    '${AppConstants.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () => context.go('/approvals'),
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return Colors.grey;
      case ReportStatus.submitted:
        return Colors.blue;
      case ReportStatus.underReview:
        return Colors.orange;
      case ReportStatus.approved:
        return Colors.green;
      case ReportStatus.closed:
        return Colors.purple;
    }
  }
}
