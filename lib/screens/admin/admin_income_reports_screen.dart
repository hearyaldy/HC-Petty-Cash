import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/income_report.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

class AdminIncomeReportsScreen extends StatefulWidget {
  const AdminIncomeReportsScreen({super.key});

  @override
  State<AdminIncomeReportsScreen> createState() =>
      _AdminIncomeReportsScreenState();
}

class _AdminIncomeReportsScreenState extends State<AdminIncomeReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Income Reports (Admin)'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/income/new'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'New Report',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<IncomeReport>>(
        stream: _firestoreService.incomeReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allReports = snapshot.data ?? [];
          final filteredReports = _filterReports(allReports);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Income Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/income/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('New Report'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade200),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSummaryHeader(allReports),
                  _buildFilterChips(allReports),
                  Expanded(
                    child: filteredReports.isEmpty
                        ? _buildEmptyState()
                        : _buildReportsList(filteredReports),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<IncomeReport> _filterReports(List<IncomeReport> reports) {
    switch (_selectedFilter) {
      case 'submitted':
        return reports.where((r) => r.status == 'submitted').toList();
      case 'approved':
        return reports.where((r) => r.status == 'approved').toList();
      case 'draft':
        return reports.where((r) => r.status == 'draft').toList();
      default:
        return reports;
    }
  }

  Widget _buildSummaryHeader(List<IncomeReport> reports) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final totalIncome = reports.fold<double>(
      0,
      (sum, r) => sum + r.totalIncome,
    );
    final pendingCount = reports.where((r) => r.status == 'submitted').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Income Recorded',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppConstants.currencySymbol}${currencyFormat.format(totalIncome)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Pending',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<IncomeReport> reports) {
    final filters = [
      {'key': 'all', 'label': 'All', 'count': reports.length},
      {
        'key': 'submitted',
        'label': 'Pending',
        'count': reports.where((r) => r.status == 'submitted').length,
      },
      {
        'key': 'approved',
        'label': 'Approved',
        'count': reports.where((r) => r.status == 'approved').length,
      },
      {
        'key': 'draft',
        'label': 'Draft',
        'count': reports.where((r) => r.status == 'draft').length,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('${filter['label']} (${filter['count']})'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter['key'] as String);
              },
              selectedColor: Colors.green.shade100,
              checkmarkColor: Colors.green.shade700,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No reports found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(List<IncomeReport> reports) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MMM dd, yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => context.push('/admin/income/${report.id}'),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.reportName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.reportNumber,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(report.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        report.createdByName,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(report.periodStart),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Income'),
                        Text(
                          '${AppConstants.currencySymbol}${currencyFormat.format(report.totalIncome)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (report.status == 'submitted') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _approveReport(report),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'draft':
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = 'Draft';
        break;
      case 'submitted':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        label = 'Pending';
        break;
      case 'approved':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        label = 'Approved';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _approveReport(IncomeReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Report'),
        content: Text(
          'Are you sure you want to approve "${report.reportName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.approveIncomeReport(report.id, 'Admin');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report approved successfully!'),
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
}
