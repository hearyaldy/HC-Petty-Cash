import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/student_timesheet.dart';
import '../../utils/constants.dart';

enum TimesheetSortOption { dateNewest, dateOldest, hoursHighest, hoursLowest }

extension TimesheetSortOptionExtension on TimesheetSortOption {
  String get displayName {
    switch (this) {
      case TimesheetSortOption.dateNewest:
        return 'Date (Newest First)';
      case TimesheetSortOption.dateOldest:
        return 'Date (Oldest First)';
      case TimesheetSortOption.hoursHighest:
        return 'Hours (Highest First)';
      case TimesheetSortOption.hoursLowest:
        return 'Hours (Lowest First)';
    }
  }

  IconData get icon {
    switch (this) {
      case TimesheetSortOption.dateNewest:
      case TimesheetSortOption.dateOldest:
        return Icons.calendar_today;
      case TimesheetSortOption.hoursHighest:
      case TimesheetSortOption.hoursLowest:
        return Icons.timelapse;
    }
  }
}

class AdminStudentReportDetailScreen extends StatefulWidget {
  final String reportId;
  final String month;
  final String monthDisplay;

  const AdminStudentReportDetailScreen({
    super.key,
    required this.reportId,
    required this.month,
    required this.monthDisplay,
  });

  @override
  State<AdminStudentReportDetailScreen> createState() =>
      _AdminStudentReportDetailScreenState();
}

class _AdminStudentReportDetailScreenState
    extends State<AdminStudentReportDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  List<StudentTimesheet> _timesheets = [];
  TimesheetSortOption _sortOption = TimesheetSortOption.dateNewest;
  bool _isApproving = false;

  @override
  void initState() {
    super.initState();
    _loadReportDetails();
  }

  Future<void> _loadReportDetails() async {
    setState(() => _isLoading = true);

    try {
      // Load the monthly report
      final reportDoc = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .get();

      if (reportDoc.exists) {
        _reportData = reportDoc.data() as Map<String, dynamic>;

        // Load associated timesheets
        final timesheetsQuery = await FirebaseFirestore.instance
            .collection('student_timesheets')
            .where('reportId', isEqualTo: widget.reportId)
            .get();

        _timesheets = timesheetsQuery.docs
            .map((doc) => StudentTimesheet.fromFirestore(doc))
            .toList();

        _sortTimesheets();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading report details: $e');
      setState(() => _isLoading = false);
    }
  }

  void _sortTimesheets() {
    switch (_sortOption) {
      case TimesheetSortOption.dateNewest:
        _timesheets.sort((a, b) => b.date.compareTo(a.date));
        break;
      case TimesheetSortOption.dateOldest:
        _timesheets.sort((a, b) => a.date.compareTo(b.date));
        break;
      case TimesheetSortOption.hoursHighest:
        _timesheets.sort((a, b) => b.totalHours.compareTo(a.totalHours));
        break;
      case TimesheetSortOption.hoursLowest:
        _timesheets.sort((a, b) => a.totalHours.compareTo(b.totalHours));
        break;
    }
  }

  Future<void> _updateReportStatus(String newStatus) async {
    setState(() => _isApproving = true);

    try {
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Reload to get updated data
      await _loadReportDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report ${newStatus == "approved" ? "approved" : "rejected"} successfully',
            ),
            backgroundColor: newStatus == 'approved'
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isApproving = false);
    }
  }

  void _showApprovalDialog(String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action == "approve" ? "Approve" : "Reject"} Report'),
        content: Text('Are you sure you want to $action this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateReportStatus(
                action == 'approve' ? 'approved' : 'rejected',
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: action == 'approve' ? Colors.green : Colors.red,
            ),
            child: Text(action == 'approve' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_reportData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Report not found')),
      );
    }

    final status = _reportData!['status'] ?? 'draft';
    final canApprove = status == 'submitted';

    return Scaffold(
      appBar: AppBar(
        title: Text('Report - ${widget.monthDisplay}'),
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
          if (canApprove && !_isApproving) ...[
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: () => _showApprovalDialog('approve'),
              tooltip: 'Approve',
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => _showApprovalDialog('reject'),
              tooltip: 'Reject',
            ),
          ],
          PopupMenuButton<TimesheetSortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() {
                _sortOption = option;
                _sortTimesheets();
              });
            },
            itemBuilder: (context) => TimesheetSortOption.values
                .map(
                  (option) => PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        Icon(option.icon, size: 20),
                        const SizedBox(width: 12),
                        Text(option.displayName),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildReportSummary(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time Entries (${_timesheets.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Sorted by: ${_sortOption.displayName.split('(')[1].replaceAll(')', '')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _timesheets.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _timesheets.length,
                    itemBuilder: (context, index) {
                      return _buildTimesheetCard(_timesheets[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummary() {
    final studentName = _reportData!['studentName'] ?? 'Unknown';
    final status = _reportData!['status'] ?? 'draft';
    final totalHours = (_reportData!['totalHours'] ?? 0.0).toDouble();
    final hourlyRate = (_reportData!['hourlyRate'] ?? 0.0).toDouble();
    final totalAmount = (_reportData!['totalAmount'] ?? 0.0).toDouble();

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'submitted':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.edit_document;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200,
            blurRadius: 12,
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.monthDisplay,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total Hours',
                '${totalHours.toStringAsFixed(1)}h',
              ),
              _buildSummaryItem(
                'Hourly Rate',
                '${AppConstants.currencySymbol}${hourlyRate.toStringAsFixed(2)}',
              ),
              _buildSummaryItem(
                'Total Amount',
                '${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTimesheetCard(StudentTimesheet timesheet) {
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    Color statusColor;
    IconData statusIcon;

    switch (timesheet.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'submitted':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.edit_document;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(timesheet.date),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${timeFormat.format(timesheet.startTime)} - ${timeFormat.format(timesheet.endTime)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        timesheet.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimesheetStat(
                  icon: Icons.timelapse,
                  label: 'Hours',
                  value: '${timesheet.totalHours.toStringAsFixed(2)}h',
                  color: Colors.blue,
                ),
                _buildTimesheetStat(
                  icon: Icons.attach_money,
                  label: 'Rate',
                  value:
                      '${AppConstants.currencySymbol}${timesheet.hourlyRate.toStringAsFixed(2)}/h',
                  color: Colors.green,
                ),
                _buildTimesheetStat(
                  icon: Icons.payments,
                  label: 'Amount',
                  value:
                      '${AppConstants.currencySymbol}${timesheet.totalAmount.toStringAsFixed(2)}',
                  color: Colors.orange,
                ),
              ],
            ),
            if (timesheet.notes != null && timesheet.notes!.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timesheet.notes!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No time entries found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
