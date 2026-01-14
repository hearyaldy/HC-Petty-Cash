import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../models/traveling_report.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/edit_traveling_report_dialog.dart';

class TravelingReportsScreen extends StatefulWidget {
  const TravelingReportsScreen({super.key});

  @override
  State<TravelingReportsScreen> createState() => _TravelingReportsScreenState();
}

class _TravelingReportsScreenState extends State<TravelingReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedStatus;

  final List<String> _statusOptions = [
    'all',
    'draft',
    'submitted',
    'approved',
    'rejected',
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'closed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _createNewReport() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found')));
      }
      return;
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditTravelingReportDialog(
        reporterId: user.id,
        reporterName: user.name,
      ),
    );

    if (result != null && mounted) {
      try {
        final reportNumber = _firestoreService.generateTravelingReportNumber();
        final newReport = TravelingReport(
          id: const Uuid().v4(),
          reportNumber: reportNumber,
          reporterId: user.id,
          reporterName: user.name,
          department: result['department'] as String,
          reportDate: result['reportDate'] as DateTime,
          purpose: result['purpose'] as String,
          placeName: result['placeName'] as String,
          departureTime: result['departureTime'] as DateTime,
          destinationTime: result['destinationTime'] as DateTime,
          totalMembers: result['totalMembers'] as int,
          travelLocation: result['travelLocation'] as String,
          mileageStart: result['mileageStart'] as double,
          mileageEnd: result['mileageEnd'] as double,
          notes: result['notes'] as String,
          createdAt: DateTime.now(),
        );

        await _firestoreService.saveTravelingReport(newReport);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report created successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to detail screen
          context.push('/traveling-reports/${newReport.id}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editReport(TravelingReport report) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditTravelingReportDialog(
        report: report,
        reporterId: user.id,
        reporterName: user.name,
      ),
    );

    if (result != null && mounted) {
      try {
        // Create updated report by copying existing one with new values
        final updatedReport = report.copyWith(
          reportDate: result['reportDate'] as DateTime,
          purpose: result['purpose'] as String,
          placeName: result['placeName'] as String,
          departureTime: result['departureTime'] as DateTime,
          destinationTime: result['destinationTime'] as DateTime,
          totalMembers: result['totalMembers'] as int,
          travelLocation: result['travelLocation'] as String,
          mileageStart: result['mileageStart'] as double,
          mileageEnd: result['mileageEnd'] as double,
          notes: result['notes'] as String,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updateTravelingReport(updatedReport);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report updated successfully'),
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

  Future<void> _deleteReport(TravelingReport report) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    // Only allow deletion of user's own draft reports
    if (report.reporterId != user.id || report.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only delete your own draft reports'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete "${report.reportNumber}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteTravelingReport(report.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Report "${report.reportNumber}" deleted successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Traveling Reports'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<TravelingReport>>(
              stream: _firestoreService.travelingReportsByReporterStream(
                user.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var reports = snapshot.data!;

                // Apply status filter
                if (_selectedStatus != null && _selectedStatus != 'all') {
                  reports = reports
                      .where((report) => report.status == _selectedStatus)
                      .toList();
                }

                if (reports.isEmpty) {
                  return _buildEmptyState();
                }

                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 16),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        return _buildReportCard(report);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewReport,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.filter_alt),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status == 'all' ? 'All Statuses' : status.toUpperCase(),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flight_takeoff, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No traveling reports yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to create your first report',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(TravelingReport report) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final statusColor = _getStatusColor(report.status);

    IconData statusIcon;
    switch (report.status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        break;
      case 'submitted':
        statusIcon = Icons.pending;
        break;
      default:
        statusIcon = Icons.edit_document;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/traveling-reports/${report.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.reportNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(report.reportDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          report.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.placeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.flag, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.purpose,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.people, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    '${report.totalMembers} member${report.totalMembers > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 20),
                  Icon(Icons.public, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    report.travelLocationEnum.displayName,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAmountColumn(
                      'Mileage',
                      '฿${currencyFormat.format(report.mileageAmount)}',
                      Icons.directions_car,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.orange.shade200,
                    ),
                    _buildAmountColumn(
                      'Per Diem',
                      '฿${currencyFormat.format(report.perDiemTotal)}',
                      Icons.restaurant,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.orange.shade200,
                    ),
                    _buildAmountColumn(
                      'Total',
                      '฿${currencyFormat.format(report.grandTotal)}',
                      Icons.account_balance_wallet,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/traveling-reports/${report.id}'),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                  if (report.status == 'draft') ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _editReport(report),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteReport(report),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountColumn(
    String label,
    String amount,
    IconData icon, {
    bool isTotal = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: isTotal ? Colors.orange.shade700 : Colors.grey.shade600,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.orange.shade700 : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
