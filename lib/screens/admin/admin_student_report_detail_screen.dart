import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel_package;
import 'package:provider/provider.dart';
import '../../models/student_timesheet.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

enum TimesheetSortOption { dateNewest, dateOldest, hoursHighest, hoursLowest }
enum ViewMode { card, table }

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
  ViewMode _viewMode = ViewMode.table;

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
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'approved') {
        updateData['approvedAt'] = DateTime.now();
        updateData['approvedBy'] = user?.name ?? 'Unknown';
      }

      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update(updateData);

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
        content: Text('Are you sure you want to ${action} this report?'),
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

  Future<void> _markAsPaid() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue.shade600),
            const SizedBox(width: 12),
            const Text('Mark as Paid'),
          ],
        ),
        content: const Text('Are you sure you want to mark this report as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isApproving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
        'status': 'paid',
        'paidAt': DateTime.now(),
        'paidBy': user?.name ?? 'Unknown',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload to get updated data
      await _loadReportDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report marked as paid successfully'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking as paid: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isApproving = false);
    }
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
    final canMarkAsPaid = status == 'approved';

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
          if (canMarkAsPaid && !_isApproving)
            IconButton(
              icon: const Icon(Icons.payment),
              onPressed: _markAsPaid,
              tooltip: 'Mark as Paid',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: 'Export',
            onSelected: (value) {
              if (value == 'pdf') {
                _generatePdf();
              } else if (value == 'excel') {
                _generateExcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export as Excel'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_viewMode == ViewMode.table ? Icons.view_list : Icons.view_module),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == ViewMode.table ? ViewMode.card : ViewMode.table;
              });
            },
            tooltip: _viewMode == ViewMode.table ? 'Card View' : 'Table View',
          ),
          PopupMenuButton<TimesheetSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
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
      body: ResponsiveContainer(
        child: Column(
          children: [
            _buildReportSummary(),
            const SizedBox(height: 8),
            Row(
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
            const SizedBox(height: 8),
            Expanded(
              child: _timesheets.isEmpty
                  ? _buildEmptyState()
                  : _viewMode == ViewMode.table
                      ? _buildTableView()
                      : ListView.builder(
                          itemCount: _timesheets.length,
                          itemBuilder: (context, index) {
                            return _buildTimesheetCard(_timesheets[index]);
                          },
                        ),
            ),
          ],
        ),
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
      case 'paid':
        statusColor = Colors.blue;
        statusIcon = Icons.payment;
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
          if (_reportData!['submittedBy'] != null ||
              _reportData!['approvedBy'] != null ||
              _reportData!['paidBy'] != null) ...[
            const Divider(height: 32, color: Colors.white24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_reportData!['submittedBy'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.send, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Submitted by: ${_reportData!['submittedBy']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_reportData!['approvedBy'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Approved by: ${_reportData!['approvedBy']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_reportData!['paidBy'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.payment, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Paid by: ${_reportData!['paidBy']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
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
      case 'paid':
        statusColor = Colors.blue;
        statusIcon = Icons.payment;
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

  Widget _buildTableView() {
    return SingleChildScrollView(
      child: Container(
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
            // Table Header
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Time Range',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Hours',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Table Rows
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _timesheets.length,
              itemBuilder: (context, index) {
                final ts = _timesheets[index];
                final dateFormat = DateFormat('dd/MM/yyyy');
                final timeFormat = DateFormat('HH:mm');

                Color statusColor;
                switch (ts.status) {
                  case 'approved':
                    statusColor = Colors.green;
                    break;
                  case 'rejected':
                    statusColor = Colors.red;
                    break;
                  case 'submitted':
                    statusColor = Colors.orange;
                    break;
                  case 'paid':
                    statusColor = Colors.blue;
                    break;
                  default:
                    statusColor = Colors.grey;
                }

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: index == _timesheets.length - 1
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            dateFormat.format(ts.date),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${timeFormat.format(ts.startTime)} - ${timeFormat.format(ts.endTime)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${ts.totalHours.toStringAsFixed(2)} h',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${AppConstants.currencySymbol}${ts.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ts.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    final timesheetCount = _timesheets.length;
    final totalHours = _timesheets.fold<double>(0.0, (sum, ts) => sum + ts.totalHours);
    final hourlyRate = (_reportData?['hourlyRate'] ?? 0.0).toDouble();
    final totalAmount = totalHours * hourlyRate;
    final studentName = _reportData?['studentName'] ?? 'Unknown';

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            'Student Labour Report - ${widget.monthDisplay}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Student: $studentName',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Report Period: ${widget.monthDisplay}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Entries'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total Hours'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Hourly Rate'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total Amount'),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$timesheetCount'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${totalHours.toStringAsFixed(2)} h'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('THB ${hourlyRate.toStringAsFixed(2)}/h'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('THB ${totalAmount.toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Detailed Timesheet Entries',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Start Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('End Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Hours', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ..._timesheets.map(
                    (ts) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(DateFormat('dd/MM/yyyy').format(ts.date)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(DateFormat('HH:mm').format(ts.startTime)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(DateFormat('HH:mm').format(ts.endTime)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${ts.totalHours.toStringAsFixed(2)} h'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('THB ${ts.totalAmount.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(ts.status),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Student Signature
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Student Signature',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide()),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Name: $studentName',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      if (_reportData?['submittedAt'] != null)
                        pw.Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format((_reportData!['submittedAt'] as Timestamp).toDate())}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                  // Approved By Signature
                  if (_reportData?['approvedBy'] != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Approved By',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          width: 150,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide()),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Name: ${_reportData!['approvedBy']}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        if (_reportData?['approvedAt'] != null)
                          pw.Text(
                            'Date: ${DateFormat('dd/MM/yyyy').format((_reportData!['approvedAt'] as Timestamp).toDate())}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                      ],
                    ),
                ],
              ),
              if (_reportData?['paidBy'] != null) ...[
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    // Paid By Signature
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Payment Confirmed By',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Container(
                          width: 150,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide()),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Name: ${_reportData!['paidBy']}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        if (_reportData?['paidAt'] != null)
                          pw.Text(
                            'Date: ${DateFormat('dd/MM/yyyy').format((_reportData!['paidAt'] as Timestamp).toDate())}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _generateExcel() async {
    final excel = excel_package.Excel.createExcel();
    final sheet = excel['Student_Labour_Report_${widget.monthDisplay.replaceAll(' ', '_')}'];

    var rowIndex = 0;

    // Header
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Student Labour Report - ${widget.monthDisplay}');
    rowIndex++;
    rowIndex++; // Empty row

    // Report Info
    final studentName = _reportData?['studentName'] ?? 'Unknown';
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Student:');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
        excel_package.TextCellValue(studentName);
    rowIndex++;

    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Report Period:');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
        excel_package.TextCellValue(widget.monthDisplay);
    rowIndex++;
    rowIndex++; // Empty row

    // Summary
    final timesheetCount = _timesheets.length;
    final totalHours = _timesheets.fold<double>(0.0, (sum, ts) => sum + ts.totalHours);
    final hourlyRate = (_reportData?['hourlyRate'] ?? 0.0).toDouble();
    final totalAmount = totalHours * hourlyRate;

    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('SUMMARY');
    rowIndex++;

    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Entries');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Total Hours');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Hourly Rate');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Total Amount');
    rowIndex++;

    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.IntCellValue(timesheetCount);
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
        excel_package.TextCellValue(totalHours.toStringAsFixed(2));
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('THB ${hourlyRate.toStringAsFixed(2)}/h');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('THB ${totalAmount.toStringAsFixed(2)}');
    rowIndex++;
    rowIndex++; // Empty row

    // Detailed entries
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('DETAILED TIMESHEET ENTRIES');
    rowIndex++;

    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Date');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Start Time');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('End Time');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Hours');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Amount');
    sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
        excel_package.TextCellValue('Status');
    rowIndex++;

    for (final ts in _timesheets) {
      sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
          excel_package.TextCellValue(DateFormat('dd/MM/yyyy').format(ts.date));
      sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
          excel_package.TextCellValue(DateFormat('HH:mm').format(ts.startTime));
      sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
          excel_package.TextCellValue(DateFormat('HH:mm').format(ts.endTime));
      sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
          excel_package.TextCellValue(ts.totalHours.toStringAsFixed(2));
      sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
          excel_package.TextCellValue(ts.totalAmount.toStringAsFixed(2));
      sheet.cell(excel_package.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
          excel_package.TextCellValue(ts.status);
      rowIndex++;
    }

    // Save the Excel file
    final bytes = excel.save();
    if (bytes != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Download Excel')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_download, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text('Excel file generated successfully!'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
