import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import '../../models/student_timesheet.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/student_rate_config.dart';
import '../../services/student_pdf_export_service.dart';

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
  Map<String, dynamic>? _studentProfile;
  List<StudentTimesheet> _timesheets = [];
  TimesheetSortOption _sortOption = TimesheetSortOption.dateNewest;
  bool _isApproving = false;
  bool _isUpdatingRate = false;
  bool _isUpdatingAction = false;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _fallbackPeriodStart() {
    final parts = widget.month.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        return DateTime(year, month, 1);
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime _fallbackPeriodEnd() {
    final parts = widget.month.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null) {
        return DateTime(year, month + 1, 0);
      }
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0);
  }

  DateTime _getPeriodStart() {
    final raw = _reportData?['periodStart'];
    if (raw is Timestamp) {
      return _dateOnly(raw.toDate());
    }
    return _fallbackPeriodStart();
  }

  DateTime _getPeriodEnd() {
    final raw = _reportData?['periodEnd'];
    if (raw is Timestamp) {
      return _dateOnly(raw.toDate());
    }
    return _fallbackPeriodEnd();
  }

  String _formatPeriodDisplay() {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return '${dateFormat.format(_getPeriodStart())} - ${dateFormat.format(_getPeriodEnd())}';
  }

  Future<void> _showEditReportDialog() async {
    if (_reportData == null) return;
    if ((_reportData?['isFinalized'] ?? false) == true) return;

    String monthValue = _reportData?['month'] ?? widget.month;
    final monthDisplayFormat = DateFormat('MMMM yyyy');
    final monthController = TextEditingController(
      text: monthDisplayFormat.format(DateTime.parse('$monthValue-01')),
    );
    final statusController = TextEditingController(
      text: _reportData?['status'] ?? 'draft',
    );
    final notesController = TextEditingController(
      text: _reportData?['notes'] ?? '',
    );
    DateTime periodStart = _getPeriodStart();
    DateTime periodEnd = _getPeriodEnd();
    final dayFormat = DateFormat('MMM dd, yyyy');

    DateTime deriveMonthStart(String month) {
      final parts = month.split('-');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final monthNum = int.tryParse(parts[1]);
        if (year != null && monthNum != null) {
          return DateTime(year, monthNum, 1);
        }
      }
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    }

    DateTime deriveMonthEnd(String month) {
      final parts = month.split('-');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final monthNum = int.tryParse(parts[1]);
        if (year != null && monthNum != null) {
          return DateTime(year, monthNum + 1, 0);
        }
      }
      final now = DateTime.now();
      return DateTime(now.year, now.month + 1, 0);
    }

    Future<void> selectPeriodStart(StateSetter setState) async {
      final monthStart = deriveMonthStart(monthValue);
      final monthEnd = deriveMonthEnd(monthValue);
      final picked = await showDatePicker(
        context: context,
        initialDate: periodStart.isBefore(monthStart)
            ? monthStart
            : periodStart.isAfter(monthEnd)
                ? monthEnd
                : periodStart,
        firstDate: monthStart,
        lastDate: monthEnd,
      );
      if (picked != null) {
        setState(() {
          periodStart = picked;
          if (periodStart.isAfter(periodEnd)) {
            periodEnd = periodStart;
          }
        });
      }
    }

    Future<void> selectPeriodEnd(StateSetter setState) async {
      final monthStart = deriveMonthStart(monthValue);
      final monthEnd = deriveMonthEnd(monthValue);
      final picked = await showDatePicker(
        context: context,
        initialDate: periodEnd.isBefore(monthStart)
            ? monthStart
            : periodEnd.isAfter(monthEnd)
                ? monthEnd
                : periodEnd,
        firstDate: monthStart,
        lastDate: monthEnd,
      );
      if (picked != null) {
        setState(() {
          periodEnd = picked;
          if (periodEnd.isBefore(periodStart)) {
            periodStart = periodEnd;
          }
        });
      }
    }

    Future<void> selectMonth(StateSetter setState) async {
      final initial = DateTime.parse('$monthValue-01');
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) {
        setState(() {
          monthValue = DateFormat('yyyy-MM').format(picked);
          monthController.text = monthDisplayFormat.format(picked);
          final monthStart = deriveMonthStart(monthValue);
          final monthEnd = deriveMonthEnd(monthValue);
          if (periodStart.isBefore(monthStart) ||
              periodStart.isAfter(monthEnd)) {
            periodStart = monthStart;
          }
          if (periodEnd.isBefore(monthStart) || periodEnd.isAfter(monthEnd)) {
            periodEnd = monthEnd;
          }
          if (periodEnd.isBefore(periodStart)) {
            periodEnd = periodStart;
          }
        });
      }
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => selectMonth(setDialogState),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(monthController.text),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => selectPeriodStart(setDialogState),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Period Start',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(dayFormat.format(periodStart)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => selectPeriodEnd(setDialogState),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Period End',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(dayFormat.format(periodEnd)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: statusController.text,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(
                      value: 'submitted',
                      child: Text('Submitted'),
                    ),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      statusController.text = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isUpdatingAction
                  ? null
                  : () async {
                      final month = monthValue;
                      final status = statusController.text.trim();
                      final notes = notesController.text.trim();

                      if (status.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Status cannot be empty'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final monthStart = deriveMonthStart(month);
                      final monthEnd = deriveMonthEnd(month);
                      if (periodStart.isBefore(monthStart) ||
                          periodEnd.isAfter(monthEnd) ||
                          periodStart.isAfter(periodEnd)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Report period must be within the selected month',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => _isUpdatingAction = true);
                      try {
                        final monthDisplay = DateFormat('MMMM yyyy')
                            .format(DateTime.parse('$month-01'));
                        final Map<String, dynamic> updates = {
                          'month': month,
                          'monthDisplay': monthDisplay,
                          'periodStart': Timestamp.fromDate(periodStart),
                          'periodEnd': Timestamp.fromDate(periodEnd),
                          'status': status,
                          'notes': notes.isEmpty ? null : notes,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                        if (status == 'draft') {
                          updates['submittedAt'] = null;
                          updates['submittedBy'] = null;
                        } else if (status == 'submitted') {
                          updates['submittedAt'] = DateTime.now();
                          updates['submittedBy'] = 'Admin';
                        }

                        await FirebaseFirestore.instance
                            .collection('student_monthly_reports')
                            .doc(widget.reportId)
                            .update(updates);

                        final timesheetQuery = await FirebaseFirestore.instance
                            .collection('student_timesheets')
                            .where('reportId', isEqualTo: widget.reportId)
                            .get();
                        final batch = FirebaseFirestore.instance.batch();
                        for (final doc in timesheetQuery.docs) {
                          batch.update(doc.reference, {'status': status});
                        }
                        await batch.commit();
                        if (mounted) {
                          Navigator.pop(dialogContext);
                          await _loadReportDetails();
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
                      } finally {
                        if (mounted) {
                          setState(() => _isUpdatingAction = false);
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final status = _reportData?['status'] ?? 'draft';
    final paymentStatus = _reportData?['paymentStatus'] ?? 'not_paid';
    final canApprove = status == 'submitted';
    final isFinalized = _reportData?['isFinalized'] ?? false;
    final canSubmit = status == 'draft' || status == 'rejected';
    final canUnsubmit =
        (status == 'submitted' || status == 'approved') && !isFinalized;
    final canFinalize = !isFinalized;
    final canUnfinalize = isFinalized;
    final canEdit = !isFinalized;
    final hasAdminActions =
        canSubmit || canUnsubmit || canFinalize || canUnfinalize || canEdit;

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'submitted':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
            Colors.deepOrange.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            children: [
              // Top action bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;

                  final actions = <Widget>[
                    if (canApprove && !_isApproving) ...[
                      _buildHeaderActionButton(
                        icon: Icons.check_circle,
                        tooltip: 'Approve',
                        onPressed: () => _showApprovalDialog('approve'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderActionButton(
                        icon: Icons.cancel,
                        tooltip: 'Reject',
                        onPressed: () => _showApprovalDialog('reject'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildHeaderActionButton(
                      icon: Icons.print,
                      tooltip: 'Print Report',
                      onPressed: _generatePdf,
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderActionButton(
                      icon: Icons.tune,
                      tooltip: 'Rate & Grade Settings',
                      onPressed: _showRateAndGradeDialog,
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderActionButton(
                      icon: Icons.payment,
                      tooltip: 'Update Payment Status',
                      onPressed: _showPaymentStatusDialog,
                    ),
                    const SizedBox(width: 8),
                    if (hasAdminActions)
                      PopupMenuButton<String>(
                        tooltip: 'Report Actions',
                        enabled: !_isUpdatingAction,
                        onSelected: (value) {
                          switch (value) {
                            case 'submit':
                              _confirmReportAction(
                                title: 'Submit Report',
                                message:
                                    'Submit this report on behalf of the student?',
                                action: () =>
                                    _setReportSubmissionStatus(submit: true),
                              );
                              break;
                            case 'unsubmit':
                              _confirmReportAction(
                                title: 'Unsubmit Report',
                                message:
                                    'Move this report back to draft status?',
                                action: () => _setReportSubmissionStatus(
                                  submit: false,
                                ),
                              );
                              break;
                            case 'edit':
                              _showEditReportDialog();
                              break;
                            case 'finalize':
                              _confirmReportAction(
                                title: 'Finalize Report',
                                message:
                                    'Finalize this report to prevent further edits?',
                                action: () =>
                                    _setFinalizedStatus(finalize: true),
                              );
                              break;
                            case 'unfinalize':
                              _confirmReportAction(
                                title: 'Unfinalize Report',
                                message:
                                    'Allow edits by unfinalizing this report?',
                                action: () =>
                                    _setFinalizedStatus(finalize: false),
                              );
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (canSubmit)
                            const PopupMenuItem(
                              value: 'submit',
                              child: Row(
                                children: [
                                  Icon(Icons.send, size: 18),
                                  SizedBox(width: 8),
                                  Text('Submit Report'),
                                ],
                              ),
                            ),
                          if (canUnsubmit)
                            const PopupMenuItem(
                              value: 'unsubmit',
                              child: Row(
                                children: [
                                  Icon(Icons.undo, size: 18),
                                  SizedBox(width: 8),
                                  Text('Unsubmit Report'),
                                ],
                              ),
                            ),
                          if (canSubmit || canUnsubmit || canEdit)
                            const PopupMenuDivider(),
                          if (canEdit)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_calendar, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit Report'),
                                ],
                              ),
                            ),
                          if (canFinalize)
                            const PopupMenuItem(
                              value: 'finalize',
                              child: Row(
                                children: [
                                  Icon(Icons.lock, size: 18),
                                  SizedBox(width: 8),
                                  Text('Finalize Report'),
                                ],
                              ),
                            ),
                          if (canUnfinalize)
                            const PopupMenuItem(
                              value: 'unfinalize',
                              child: Row(
                                children: [
                                  Icon(Icons.lock_open, size: 18),
                                  SizedBox(width: 8),
                                  Text('Unfinalize Report'),
                                ],
                              ),
                            ),
                        ],
                        icon: const Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    if (hasAdminActions) const SizedBox(width: 8),
                    _buildSortButton(),
                  ];

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildHeaderActionButton(
                              icon: Icons.arrow_back,
                              tooltip: 'Back',
                              onPressed: () => context.pop(),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: actions,
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderActionButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                      ),
                      Row(children: actions),
                    ],
                  );
                },
              ),
              SizedBox(height: isMobile ? 16 : 20),
              // Content with icon and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Report Review',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPeriodDisplay(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if ((_reportData?['isFinalized'] ?? false) == true) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'FINALIZED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPaymentStatusColor(paymentStatus)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _formatPaymentStatus(paymentStatus).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getPaymentStatusColor(paymentStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<TimesheetSortOption>(
      tooltip: 'Sort Options',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.sort, color: Colors.white, size: 20),
      ),
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
    );
  }

  Widget _buildLoadingHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
            Colors.deepOrange.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -34,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
            Colors.deepOrange.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -34,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'not_paid':
        return Colors.red;
      case 'review':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

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

        // Load student profile
        final studentId = _reportData!['studentId'];
        if (studentId != null) {
          final profileDoc = await FirebaseFirestore.instance
              .collection('student_profiles')
              .doc(studentId)
              .get();
          if (profileDoc.exists) {
            _studentProfile = profileDoc.data() as Map<String, dynamic>;
          }
        }

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
      debugPrint('Error loading report details: $e');
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

  Future<void> _setReportSubmissionStatus({required bool submit}) async {
    setState(() => _isUpdatingAction = true);

    try {
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
            'status': submit ? 'submitted' : 'draft',
            'submittedAt': submit ? DateTime.now() : null,
            'submittedBy': submit ? 'Admin' : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      final timesheetQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('reportId', isEqualTo: widget.reportId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in timesheetQuery.docs) {
        batch.update(doc.reference, {
          'status': submit ? 'submitted' : 'draft',
        });
      }
      await batch.commit();

      await _loadReportDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submit
                  ? 'Report submitted successfully'
                  : 'Report moved back to draft',
            ),
            backgroundColor: submit ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating submission status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAction = false);
      }
    }
  }

  Future<void> _setFinalizedStatus({required bool finalize}) async {
    setState(() => _isUpdatingAction = true);

    try {
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
            'isFinalized': finalize,
            'finalizedAt': finalize ? DateTime.now() : null,
            'finalizedBy': finalize ? 'Admin' : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await _loadReportDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalize ? 'Report finalized' : 'Report unfinalized',
            ),
            backgroundColor: finalize ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating finalized status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAction = false);
      }
    }
  }

  Future<void> _confirmReportAction({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await action();
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

  Future<void> _updatePaymentStatus(String newPaymentStatus) async {
    setState(() => _isApproving = true);

    try {
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
            'paymentStatus': newPaymentStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Reload to get updated data
      await _loadReportDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment status updated to $newPaymentStatus successfully',
            ),
            backgroundColor: newPaymentStatus == 'paid'
                ? Colors.green
                : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating payment status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isApproving = false);
    }
  }

  void _showPaymentStatusDialog() {
    final paymentStatusOptions = ['paid', 'not_paid', 'review'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Payment Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: paymentStatusOptions
              .map(
                (status) => RadioListTile<String>(
                  title: Text(_formatPaymentStatus(status)),
                  value: status,
                  groupValue: _reportData?['paymentStatus'] ?? 'not_paid',
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.of(context).pop();
                      _updatePaymentStatus(value);
                    }
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatPaymentStatus(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'not_paid':
        return 'Not Paid';
      case 'review':
        return 'Review';
      default:
        return status;
    }
  }

  void _showRateAndGradeDialog() {
    final currentRate = (_reportData?['hourlyRate'] ?? 0.0).toDouble();
    final currentGrade = _studentProfile?['grade'] as String?;
    final studentRole = _studentProfile?['role'] as String? ?? 'Other';
    final totalHours = (_reportData?['totalHours'] ?? 0.0).toDouble();

    final rateController = TextEditingController(
      text: currentRate.toStringAsFixed(2),
    );
    String? selectedGrade = currentGrade;
    bool overrideRate = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Calculate total based on entered rate
          double displayRate =
              double.tryParse(rateController.text) ?? currentRate;
          double newTotal = totalHours * displayRate;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.settings, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text('Rate & Grade Settings'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Report Info',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Role:'),
                            Text(
                              studentRole,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Hours:'),
                            Text(
                              '${totalHours.toStringAsFixed(2)}h',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Rate:'),
                            Text(
                              '${AppConstants.currencySymbol}${currentRate.toStringAsFixed(2)}/h',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Grade:'),
                            Text(
                              currentGrade ?? 'Not Set',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: currentGrade != null
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Grade Selection with rates
                  const Text(
                    'Select Grade (auto-calculates rate)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...StudentRateConfig.grades.map((grade) {
                    final gradeRate = StudentRateConfig.getRate(
                      studentRole,
                      grade,
                    );
                    final isSelected = selectedGrade == grade;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedGrade = grade;
                            if (!overrideRate) {
                              rateController.text = gradeRate.toStringAsFixed(
                                2,
                              );
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _getGradeColor(grade)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? _getGradeColor(grade)
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Grade $grade',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              Text(
                                '${AppConstants.currencySymbol}${gradeRate.toStringAsFixed(2)}/h',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),

                  // Override checkbox
                  CheckboxListTile(
                    value: overrideRate,
                    onChanged: (value) {
                      setDialogState(() {
                        overrideRate = value ?? false;
                        if (!overrideRate && selectedGrade != null) {
                          final gradeRate = StudentRateConfig.getRate(
                            studentRole,
                            selectedGrade,
                          );
                          rateController.text = gradeRate.toStringAsFixed(2);
                        }
                      });
                    },
                    title: const Text('Override rate manually'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),

                  // Hourly Rate Input (only editable if override is checked)
                  TextField(
                    controller: rateController,
                    enabled: overrideRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Hourly Rate',
                      prefixText: '${AppConstants.currencySymbol} ',
                      suffixText: '/hour',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      filled: !overrideRate,
                      fillColor: Colors.grey.shade100,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // New Total Amount
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('New Total Amount:'),
                        Text(
                          '${AppConstants.currencySymbol}${newTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Changes will update this report and the student\'s profile for future reports.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isUpdatingRate
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _updateRateAndGrade(
                          newRate:
                              double.tryParse(rateController.text) ??
                              currentRate,
                          newGrade: selectedGrade,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateRateAndGrade({
    required double newRate,
    String? newGrade,
  }) async {
    setState(() => _isUpdatingRate = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final studentId = _reportData?['studentId'];
      final totalHours = (_reportData?['totalHours'] ?? 0.0).toDouble();
      final newTotalAmount = totalHours * newRate;

      // Update the monthly report
      final reportRef = FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId);

      batch.update(reportRef, {
        'hourlyRate': newRate,
        'totalAmount': newTotalAmount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update all timesheets in this report
      for (final timesheet in _timesheets) {
        final timesheetRef = FirebaseFirestore.instance
            .collection('student_timesheets')
            .doc(timesheet.id);

        final timesheetAmount = timesheet.totalHours * newRate;
        batch.update(timesheetRef, {
          'hourlyRate': newRate,
          'totalAmount': timesheetAmount,
        });
      }

      // Update student profile - always update rate and grade
      if (studentId != null) {
        final profileRef = FirebaseFirestore.instance
            .collection('student_profiles')
            .doc(studentId);

        Map<String, dynamic> profileUpdates = {
          'hourlyRate': newRate, // Always update the rate
        };

        if (newGrade != null) {
          profileUpdates['grade'] = newGrade;
        }

        batch.update(profileRef, profileUpdates);
      }

      await batch.commit();

      // Reload to get updated data
      await _loadReportDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Updated: Rate ${AppConstants.currencySymbol}${newRate.toStringAsFixed(2)}/h'
                    '${newGrade != null ? ", Grade $newGrade" : ""}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdatingRate = false);
    }
  }

  Future<void> _generatePdf() async {
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;

    // Get student profile to get grade
    String? grade;
    try {
      final studentProfileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(_reportData?['studentId'])
          .get();

      if (studentProfileDoc.exists) {
        final profileData = studentProfileDoc.data() as Map<String, dynamic>;
        grade = profileData['grade'];
      }
    } catch (e) {
      debugPrint('Error getting student profile: $e');
    }

    // Get student profile to get additional fields
    String? course, yearLevel, phoneNumber, language, role;
    try {
      final studentProfileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(_reportData?['studentId'])
          .get();

      if (studentProfileDoc.exists) {
        final profileData = studentProfileDoc.data() as Map<String, dynamic>;
        course = profileData['course'];
        yearLevel = profileData['yearLevel'];
        phoneNumber = profileData['phoneNumber'];
        language = profileData['language'];
        role = profileData['role'];
      }
    } catch (e) {
      debugPrint('Error getting student profile: $e');
    }

    final service = StudentPdfExportService();
    final pdfBytes = await service.exportStudentReport(
      studentName: _reportData?['studentName'] ?? 'Unknown',
      studentNumber: _reportData?['studentNumber'] ?? 'Unknown',
      monthDisplay: _formatPeriodDisplay(),
      reportId: widget.reportId,
      status: _reportData?['status'] ?? 'draft',
      hourlyRate: hourlyRate,
      timesheets: _timesheets,
      grade: grade,
      course: course,
      yearLevel: yearLevel,
      phoneNumber: phoneNumber,
      language: language,
      role: role,
      paymentStatus: _reportData?['paymentStatus'] ?? 'not_paid',
    );

    // Show the PDF using the printing package
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: ResponsiveContainer(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildLoadingHeader(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reportData == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: ResponsiveContainer(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildErrorHeader(),
                const Expanded(child: Center(child: Text('Report not found'))),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: ResponsiveContainer(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildWelcomeHeader(),
              const SizedBox(height: 16),
              _buildReportSummaryCard(),
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
      ),
    );
  }

  Widget _buildReportSummaryCard() {
    final studentName = _reportData!['studentName'] ?? 'Unknown';
    final status = _reportData!['status'] ?? 'draft';
    final paymentStatus = _reportData!['paymentStatus'] ?? 'not_paid';
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

    Color paymentStatusColor;
    switch (paymentStatus) {
      case 'paid':
        paymentStatusColor = Colors.green;
        break;
      case 'not_paid':
        paymentStatusColor = Colors.red;
        break;
      case 'review':
        paymentStatusColor = Colors.orange;
        break;
      default:
        paymentStatusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
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
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                    style: TextStyle(
                      color: Colors.orange.shade700,
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
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPeriodDisplay(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: paymentStatusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatPaymentStatus(paymentStatus).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: paymentStatusColor,
                      ),
                    ),
                  ),
                  if (_studentProfile?['grade'] != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getGradeColor(_studentProfile!['grade']),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'GRADE ${_studentProfile!['grade']}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItemLight(
                'Total Hours',
                '${totalHours.toStringAsFixed(1)}h',
                Icons.access_time,
                Colors.blue,
              ),
              _buildSummaryItemLight(
                'Hourly Rate',
                '${AppConstants.currencySymbol}${hourlyRate.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
              _buildSummaryItemLight(
                'Total Amount',
                '${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                Icons.payments,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItemLight(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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

    // Task status colors and icons
    Color taskStatusColor;
    IconData taskStatusIcon;
    final taskStatus = timesheet.taskStatusEnum;
    switch (taskStatus) {
      case TaskStatus.completed:
        taskStatusColor = Colors.green;
        taskStatusIcon = Icons.check_circle;
        break;
      case TaskStatus.inProgress:
        taskStatusColor = Colors.orange;
        taskStatusIcon = Icons.timelapse;
        break;
      case TaskStatus.onHold:
        taskStatusColor = Colors.red;
        taskStatusIcon = Icons.pause_circle;
        break;
      case TaskStatus.notStarted:
        taskStatusColor = Colors.grey;
        taskStatusIcon = Icons.radio_button_unchecked;
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
            // Header: Date, Time, Status
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
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
                    if (timesheet.taskStatus != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: taskStatusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              taskStatusIcon,
                              size: 12,
                              color: taskStatusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              taskStatus.displayName,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: taskStatusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Task Info Section
            if (timesheet.taskType != null || timesheet.taskTitle != null) ...[
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task Type
                    Row(
                      children: [
                        Icon(
                          _getTaskTypeIcon(timesheet.taskTypeEnum),
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Task: ${timesheet.taskTypeDisplayName}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (timesheet.taskTitle != null &&
                        timesheet.taskTitle!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.title, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timesheet.taskTitle!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (timesheet.taskDescription != null &&
                        timesheet.taskDescription!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timesheet.taskDescription!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Progress Bar
                    if (timesheet.taskProgress > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Progress:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: timesheet.taskProgress / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  timesheet.taskProgress >= 100
                                      ? Colors.green
                                      : timesheet.taskProgress >= 50
                                      ? Colors.orange
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${timesheet.taskProgress}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (timesheet.task.isNotEmpty) ...[
              // Backward compatibility: show old task field if new fields are not set
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.task, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timesheet.task,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20),
            // Stats Row
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

  IconData _getTaskTypeIcon(TaskType type) {
    switch (type) {
      case TaskType.videoEditing:
        return Icons.video_library;
      case TaskType.contentCreation:
        return Icons.create;
      case TaskType.translation:
        return Icons.translate;
      case TaskType.research:
        return Icons.science;
      case TaskType.production:
        return Icons.movie;
      case TaskType.languageEditing:
        return Icons.language;
      case TaskType.other:
        return Icons.work;
    }
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
