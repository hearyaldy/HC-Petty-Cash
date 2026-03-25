import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/traveling_report.dart';
import '../../services/firestore_service.dart';
import '../../utils/responsive_helper.dart';

class AdminTravelingReportsScreen extends StatefulWidget {
  const AdminTravelingReportsScreen({super.key});

  @override
  State<AdminTravelingReportsScreen> createState() =>
      _AdminTravelingReportsScreenState();
}

class _AdminTravelingReportsScreenState
    extends State<AdminTravelingReportsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildWelcomeHeader(),
              ),
              _buildFilterBar(),
              Expanded(
                child: StreamBuilder<List<TravelingReport>>(
                  stream: _firestoreService.travelingReportsStream(),
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
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
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
              // My Reports button
              _buildHeaderActionButton(
                icon: Icons.person,
                tooltip: 'My Traveling Reports',
                onPressed: () => context.push('/traveling-reports'),
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
                      'Traveling Reports Management',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review and manage all traveling reports',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flight_takeoff,
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
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
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
              Icon(Icons.filter_list, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Filter by Status',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: Icon(
                      Icons.label,
                      color: Colors.indigo.shade600,
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
            'No traveling reports',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/admin/traveling-reports/${report.id}');
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                            Colors.indigo.shade400,
                            Colors.indigo.shade600,
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
                        border: Border.all(color: statusColor),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person, report.reporterName),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.location_on, report.placeName),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.flag, report.purpose),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              Icons.business,
                              report.department,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoRow(
                              Icons.people,
                              '${report.totalMembers} member${report.totalMembers > 1 ? 's' : ''}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.indigo.shade50,
                        Colors.indigo.shade100.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAmountColumn(
                        'Mileage',
                        '฿${currencyFormat.format(report.mileageAmount)}',
                        Icons.directions_car,
                        Colors.blue.shade600,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.indigo.shade200,
                      ),
                      _buildAmountColumn(
                        'Per Diem',
                        '฿${currencyFormat.format(report.perDiemTotal)}',
                        Icons.restaurant,
                        Colors.green.shade600,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.indigo.shade200,
                      ),
                      _buildAmountColumn(
                        'Total',
                        '฿${currencyFormat.format(report.grandTotal)}',
                        Icons.account_balance_wallet,
                        Colors.indigo.shade700,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountColumn(
    String label,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
