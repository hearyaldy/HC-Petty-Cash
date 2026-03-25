import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel_package;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/student_timesheet.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../services/student_pdf_export_service.dart';

class StudentMonthlyReportDetailScreen extends StatefulWidget {
  final String reportId;
  final String month;
  final String monthDisplay;

  const StudentMonthlyReportDetailScreen({
    super.key,
    required this.reportId,
    required this.month,
    required this.monthDisplay,
  });

  @override
  State<StudentMonthlyReportDetailScreen> createState() =>
      _StudentMonthlyReportDetailScreenState();
}

class _StudentMonthlyReportDetailScreenState
    extends State<StudentMonthlyReportDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  List<StudentTimesheet> _timesheets = [];
  bool _isUpdatingReport = false;

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

  DateTime _getAllowedDateMin() => _getPeriodStart();

  DateTime _getAllowedDateMax() {
    final periodEnd = _getPeriodEnd();
    final today = _dateOnly(DateTime.now());
    return periodEnd.isBefore(today) ? periodEnd : today;
  }

  bool _isDateAllowed(DateTime date) {
    final min = _getAllowedDateMin();
    final max = _getAllowedDateMax();
    return !date.isBefore(min) && !date.isAfter(max);
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
              onPressed: _isUpdatingReport
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

                      final studentId = _reportData?['studentId'];
                      if (studentId != null) {
                        final existingReport = await FirebaseFirestore.instance
                            .collection('student_monthly_reports')
                            .where('studentId', isEqualTo: studentId)
                            .where('month', isEqualTo: month)
                            .get();

                        for (final doc in existingReport.docs) {
                          if (doc.id == widget.reportId) continue;
                          final data = doc.data();
                          DateTime existingStart;
                          DateTime existingEnd;
                          if (data['periodStart'] is Timestamp &&
                              data['periodEnd'] is Timestamp) {
                            existingStart = (data['periodStart'] as Timestamp)
                                .toDate();
                            existingEnd = (data['periodEnd'] as Timestamp)
                                .toDate();
                          } else {
                            existingStart = monthStart;
                            existingEnd = monthEnd;
                          }

                          final overlaps =
                              !periodEnd.isBefore(existingStart) &&
                              !periodStart.isAfter(existingEnd);
                          if (overlaps) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Report period overlaps with another report in this month',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }
                      }

                      setState(() => _isUpdatingReport = true);
                      try {
                        final monthDisplay = DateFormat(
                          'MMMM yyyy',
                        ).format(DateTime.parse('$month-01'));
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
                          updates['submittedBy'] =
                              context.read<AuthProvider>().currentUser?.name ??
                              'Student';
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
                          setState(() => _isUpdatingReport = false);
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

  Future<void> _unsubmitReport() async {
    if ((_reportData?['status'] ?? 'draft') != 'submitted') return;
    if ((_reportData?['isFinalized'] ?? false) == true) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsubmit Report'),
        content: const Text('Move this report back to draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
            'status': 'draft',
            'submittedAt': null,
            'submittedBy': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      final timesheetQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('reportId', isEqualTo: widget.reportId)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in timesheetQuery.docs) {
        batch.update(doc.reference, {'status': 'draft'});
      }
      await batch.commit();

      if (mounted) {
        await _loadReportDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report moved back to draft'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unsubmit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWelcomeHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final status = _reportData?['status'] ?? 'draft';

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
              width: 140,
              height: 140,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  Row(
                    children: [
                      _buildHeaderActionButton(
                        icon: Icons.print,
                        tooltip: 'Print Report',
                        onPressed: _generatePdf,
                      ),
                      const SizedBox(width: 8),
                      if ((_reportData?['status'] ?? 'draft') == 'submitted' &&
                          (_reportData?['isFinalized'] ?? false) == false)
                        _buildHeaderActionButton(
                          icon: Icons.undo,
                          tooltip: 'Unsubmit Report',
                          onPressed: _unsubmitReport,
                        ),
                      if ((_reportData?['status'] ?? 'draft') == 'draft' &&
                          (_reportData?['isFinalized'] ?? false) == false)
                        _buildHeaderActionButton(
                          icon: Icons.edit_calendar,
                          tooltip: 'Edit Report Period',
                          onPressed: _showEditReportDialog,
                        ),
                      if ((_reportData?['status'] ?? 'draft') == 'draft' &&
                          (_reportData?['isFinalized'] ?? false) == false)
                        const SizedBox(width: 8),
                      _buildHeaderActionButton(
                        icon: Icons.picture_as_pdf,
                        tooltip: 'Export as PDF',
                        onPressed: _generatePdf,
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderActionButton(
                        icon: Icons.table_chart,
                        tooltip: 'Export as Excel',
                        onPressed: _generateExcel,
                      ),
                    ],
                  ),
                ],
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
                      Icons.description,
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
                          'Report Details',
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
        final timesheetQuery = await FirebaseFirestore.instance
            .collection('student_timesheets')
            .where('reportId', isEqualTo: widget.reportId)
            .orderBy('date', descending: false)
            .get();

        _timesheets = timesheetQuery.docs
            .map((doc) => StudentTimesheet.fromFirestore(doc))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading report details: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _generatePdf() async {
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
      hourlyRate: _reportData?['hourlyRate'] ?? 0.0,
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

  Future<void> _generateExcel() async {
    final excel = excel_package.Excel.createExcel();
    final sheet =
        excel['Student_Labour_Report_${widget.monthDisplay.replaceAll(' ', '_')}'];

    var rowIndex = 0;

    // Header
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Student Labour Report - ${_formatPeriodDisplay()}',
    );
    rowIndex++;

    rowIndex++; // Empty row

    // Report Info
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Student:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      _reportData?['studentName'] ?? '',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Student ID:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      _reportData?['studentId'] ?? '',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Report Period:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      _formatPeriodDisplay(),
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Report ID:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      widget.reportId,
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Status:',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      _reportData?['status'] ?? 'Unknown',
    );
    rowIndex++;

    rowIndex++; // Empty row

    // Summary
    final timesheetCount = _timesheets.length;
    final totalHours = _timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
    final totalAmount = totalHours * hourlyRate;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'SUMMARY',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Entries',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Total Hours',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Hourly Rate',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Total Amount',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.IntCellValue(
      timesheetCount,
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      totalHours.toStringAsFixed(2),
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      '฿${hourlyRate.toStringAsFixed(2)}/h',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      '฿${totalAmount.toStringAsFixed(2)}',
    );
    rowIndex++;

    rowIndex++; // Empty row

    // Detailed entries
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'DETAILED TIMESHEET ENTRIES',
    );
    rowIndex++;

    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Date',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Start Time',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'End Time',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Task',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 4,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Hours',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Amount',
    );
    sheet
        .cell(
          excel_package.CellIndex.indexByColumnRow(
            columnIndex: 6,
            rowIndex: rowIndex,
          ),
        )
        .value = excel_package.TextCellValue(
      'Status',
    );
    rowIndex++;

    for (final ts in _timesheets) {
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        DateFormat('dd/MM/yyyy').format(ts.date),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        DateFormat('HH:mm').format(ts.startTime),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        DateFormat('HH:mm').format(ts.endTime),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 3,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.task,
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.totalHours.toStringAsFixed(2),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 5,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.totalAmount.toStringAsFixed(2),
      );
      sheet
          .cell(
            excel_package.CellIndex.indexByColumnRow(
              columnIndex: 6,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_package.TextCellValue(
        ts.status,
      );
      rowIndex++;
    }

    // Save the Excel file
    final bytes = excel.save();
    if (bytes != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.grey[100],
            body: SingleChildScrollView(
              child: ResponsiveContainer(
                padding: ResponsiveHelper.getScreenPadding(context).copyWith(
                  top: MediaQuery.of(context).padding.top + 16,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade600, Colors.green.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.table_chart, size: 40, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Download Excel',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Export timesheet data',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                    Icon(Icons.file_download, size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text('Excel file generated successfully!'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // In a real app, you would save the file to device storage
                        // For now, we'll just show a success message
                        Navigator.of(context).pop();
                      },
                      child: const Text('Download File'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? SingleChildScrollView(
              child: ResponsiveContainer(
                padding: ResponsiveHelper.getScreenPadding(context).copyWith(
                  top: MediaQuery.of(context).padding.top + 16,
                ),
                child: Column(
                  children: [
                    _buildLoadingHeader(),
                    const SizedBox(height: 100),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            )
          : _reportData == null
          ? SingleChildScrollView(
              child: ResponsiveContainer(
                padding: ResponsiveHelper.getScreenPadding(context).copyWith(
                  top: MediaQuery.of(context).padding.top + 16,
                ),
                child: Column(
                  children: [
                    _buildErrorHeader(),
                    const SizedBox(height: 100),
                    const Center(child: Text('Report not found')),
                  ],
                ),
              ),
            )
          : _buildContent(),
      floatingActionButton:
          (_reportData?['status'] ?? 'draft') == 'draft' &&
              (_reportData?['isFinalized'] ?? false) == false
          ? FloatingActionButton.extended(
              onPressed: _showAddTimesheetDialog,
              backgroundColor: Colors.orange.shade600,
              icon: const Icon(Icons.add),
              label: const Text('Add Time Entry'),
            )
          : null,
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
                      Icons.description,
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

  Widget _buildContent() {
    final timesheetCount = _timesheets.length;
    final totalHours = _timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
    final totalAmount = totalHours * hourlyRate;

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Welcome Header with actions
            _buildWelcomeHeader(),
            const SizedBox(height: 16),
            // Report Summary Card
            Container(
              width: double.infinity,
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
                  // Title Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Student Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Student Information Grid
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name and Student Number
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRowLight(
                              Icons.person,
                              'Student Name',
                              _reportData?['studentName'] ?? 'N/A',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRowLight(
                              Icons.badge,
                              'Student Number',
                              _reportData?['studentNumber'] ?? 'N/A',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Row 2: Email and Department
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRowLight(
                              Icons.email,
                              'Email',
                              _reportData?['studentEmail'] ?? 'N/A',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRowLight(
                              Icons.business,
                              'Department',
                              _reportData?['department'] ?? 'N/A',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Row 3: Report ID and Hourly Rate
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRowLight(
                              Icons.fingerprint,
                              'Report ID',
                              '${widget.reportId.substring(0, 8)}...',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRowLight(
                              Icons.attach_money,
                              'Hourly Rate',
                              '฿${hourlyRate.toStringAsFixed(2)}/hr',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_note, color: Colors.orange.shade700),
                        const SizedBox(height: 8),
                        Text(
                          '$timesheetCount',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Entries',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue.shade700),
                        const SizedBox(height: 8),
                        Text(
                          totalHours.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.attach_money, color: Colors.green.shade700),
                        const SizedBox(height: 8),
                        Text(
                          '฿${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(_reportData?['status']).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(
                    _reportData?['status'],
                  ).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(_reportData?['status']),
                    color: _getStatusColor(_reportData?['status']),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${_reportData?['status']?.toUpperCase() ?? 'UNKNOWN'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(_reportData?['status']),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Detailed Table/Card View (responsive)
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detailed Timesheet Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_timesheets.length} entries',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Use LayoutBuilder to detect screen size
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Card-based layout for mobile
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _timesheets.length,
                          itemBuilder: (context, index) {
                            final ts = _timesheets[index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Date and Status Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat(
                                                'dd MMM yyyy',
                                              ).format(ts.date),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                  ts.status,
                                                ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                ts.status.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(
                                                    ts.status,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // View/Edit/Delete menu
                                            PopupMenuButton<String>(
                                              icon: Icon(
                                                Icons.more_vert,
                                                size: 20,
                                                color: Colors.grey[600],
                                              ),
                                              padding: EdgeInsets.zero,
                                              onSelected: (value) {
                                                if (value == 'view') {
                                                  _showViewTimesheetDialog(ts);
                                                } else if (value == 'edit') {
                                                  _showEditTimesheetDialog(ts);
                                                } else if (value == 'delete') {
                                                  _showDeleteTimesheetDialog(
                                                    ts,
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'view',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.visibility,
                                                        size: 18,
                                                        color: Colors.green,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('View Details'),
                                                    ],
                                                  ),
                                                ),
                                                // Only show Edit/Delete when report is draft and not finalized
                                                if ((_reportData?['status'] ??
                                                            'draft') ==
                                                        'draft' &&
                                                    (_reportData?['isFinalized'] ??
                                                            false) ==
                                                        false) ...[
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.edit,
                                                          size: 18,
                                                          color: Colors.blue,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('Edit'),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          size: 18,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.red,
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
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    const SizedBox(height: 12),

                                    // Time Range
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Time:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${DateFormat('HH:mm').format(ts.startTime)} - ${DateFormat('HH:mm').format(ts.endTime)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Task Description
                                    if (ts.task.isNotEmpty) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.task_alt,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Task:',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  ts.task,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Hours and Amount Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 16,
                                              color: Colors.blue.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Hours:',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${ts.totalHours.toStringAsFixed(2)} h',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.attach_money,
                                              size: 16,
                                              color: Colors.green.shade600,
                                            ),
                                            Text(
                                              '฿${ts.totalAmount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        // Table layout for larger screens
                        return Column(
                          children: [
                            // Table Header
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
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
                                      flex: 3,
                                      child: Text(
                                        'Task',
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
                                    // Actions column - only show when draft
                                    if ((_reportData?['status'] ?? 'draft') ==
                                        'draft')
                                      const SizedBox(
                                        width: 50,
                                        child: Text(
                                          '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
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
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _timesheets.length,
                              itemBuilder: (context, index) {
                                final ts = _timesheets[index];
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(ts.date),
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${DateFormat('HH:mm').format(ts.startTime)} - ${DateFormat('HH:mm').format(ts.endTime)}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            ts.task,
                                            style: TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${ts.totalHours.toStringAsFixed(2)} h',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '฿${ts.totalAmount.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                ts.status,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              ts.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _getStatusColor(
                                                  ts.status,
                                                ),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        // Actions menu
                                        SizedBox(
                                          width: 50,
                                          child: PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_vert,
                                              size: 20,
                                              color: Colors.grey[600],
                                            ),
                                            padding: EdgeInsets.zero,
                                            onSelected: (value) {
                                              if (value == 'view') {
                                                _showViewTimesheetDialog(ts);
                                              } else if (value == 'edit') {
                                                _showEditTimesheetDialog(ts);
                                              } else if (value == 'delete') {
                                                _showDeleteTimesheetDialog(ts);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'view',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.visibility,
                                                      size: 18,
                                                      color: Colors.green,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('View Details'),
                                                  ],
                                                ),
                                              ),
                                              // Only show Edit/Delete when report is draft and not finalized
                                              if ((_reportData?['status'] ??
                                                          'draft') ==
                                                      'draft' &&
                                                  (_reportData?['isFinalized'] ??
                                                          false) ==
                                                      false) ...[
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit,
                                                        size: 18,
                                                        color: Colors.blue,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('Edit'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete,
                                                        size: 18,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button (only show for draft status)
            if ((_reportData?['status'] ?? 'draft') == 'draft' &&
                (_reportData?['isFinalized'] ?? false) == false &&
                _timesheets.isNotEmpty)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade500, Colors.green.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submitReport,
                    borderRadius: BorderRadius.circular(12),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Submit Report for Approval',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Info message for draft reports
            if ((_reportData?['status'] ?? 'draft') == 'draft' &&
                (_reportData?['isFinalized'] ?? false) == false &&
                _timesheets.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add at least one time entry before submitting your report',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Status message for submitted reports
            if ((_reportData?['status'] ?? 'draft') != 'draft' ||
                (_reportData?['isFinalized'] ?? false) == true)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (_reportData?['isFinalized'] ?? false) == true
                            ? 'This report has been finalized and cannot be edited'
                            : 'This report has been submitted and cannot be edited',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowLight(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange.shade400, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'paid':
        return Colors.blue;
      case 'submitted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'paid':
        return Icons.payment;
      case 'submitted':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _showAddTimesheetDialog() async {
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    TaskType selectedTaskType = TaskType.other;
    final customTaskTypeController = TextEditingController();
    final taskTitleController = TextEditingController();
    final taskDescriptionController = TextEditingController();
    int taskProgress = 0;
    TaskStatus selectedTaskStatus = TaskStatus.inProgress;
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange.shade600),
                const SizedBox(width: 12),
                const Expanded(child: Text('Add Time Entry')),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Picker
                    Text(
                      'Date *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final minDate = _getAllowedDateMin();
                        final maxDate = _getAllowedDateMax();

                        if (maxDate.isBefore(minDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No available dates for this report period',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        DateTime initialDate = selectedDate ?? maxDate;
                        if (initialDate.isBefore(minDate)) {
                          initialDate = minDate;
                        } else if (initialDate.isAfter(maxDate)) {
                          initialDate = maxDate;
                        }

                        final date = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: minDate,
                          lastDate: maxDate,
                        );
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate == null
                                  ? 'Select date'
                                  : DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(selectedDate!),
                            ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time Row
                    Row(
                      children: [
                        // Start Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: startTime ?? TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setDialogState(() => startTime = time);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        startTime == null
                                            ? 'Start'
                                            : startTime!.format(context),
                                      ),
                                      const Icon(Icons.access_time, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // End Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: endTime ?? TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setDialogState(() => endTime = time);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        endTime == null
                                            ? 'End'
                                            : endTime!.format(context),
                                      ),
                                      const Icon(Icons.access_time, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Divider(),
                    const SizedBox(height: 8),

                    // Task Type Dropdown
                    Text(
                      'Task Type *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskType>(
                      initialValue: selectedTaskType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: TaskType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedTaskType = value);
                        }
                      },
                    ),
                    // Custom Task Type field (shown when "Other" is selected)
                    if (selectedTaskType == TaskType.other) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Specify Task Type *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: customTaskTypeController,
                        decoration: InputDecoration(
                          hintText: 'Enter custom task type name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Task Title
                    Text(
                      'Task Title *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskTitleController,
                      decoration: InputDecoration(
                        hintText: 'Enter a title for this task',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Task Description
                    Text(
                      'Description *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskDescriptionController,
                      decoration: InputDecoration(
                        hintText: 'Describe the work done in detail',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Progress Slider
                    Text(
                      'Progress *: $taskProgress%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('0%'),
                        Expanded(
                          child: Slider(
                            value: taskProgress.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            activeColor: Colors.orange.shade600,
                            label: '$taskProgress%',
                            onChanged: (value) {
                              setDialogState(
                                () => taskProgress = value.toInt(),
                              );
                            },
                          ),
                        ),
                        const Text('100%'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Task Status Dropdown
                    Text(
                      'Status *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskStatus>(
                      initialValue: selectedTaskStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: TaskStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              Icon(
                                _getTaskStatusIcon(status),
                                size: 18,
                                color: _getTaskStatusColor(status),
                              ),
                              const SizedBox(width: 8),
                              Text(status.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedTaskStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add any additional notes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validate required fields
                  if (selectedDate == null ||
                      startTime == null ||
                      endTime == null ||
                      taskTitleController.text.trim().isEmpty ||
                      taskDescriptionController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (selectedDate != null && !_isDateAllowed(selectedDate!)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Date must be within the report period',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Validate custom task type when "Other" is selected
                  if (selectedTaskType == TaskType.other &&
                      customTaskTypeController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please specify the task type'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Calculate hours
                  final start = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    startTime!.hour,
                    startTime!.minute,
                  );
                  final end = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    endTime!.hour,
                    endTime!.minute,
                  );
                  final duration = end.difference(start);
                  final hours = duration.inMinutes / 60.0;

                  if (hours <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Create timesheet entry
                  final timesheetRef = FirebaseFirestore.instance
                      .collection('student_timesheets')
                      .doc();

                  final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
                  final timesheet = StudentTimesheet(
                    id: timesheetRef.id,
                    studentId: _reportData!['studentId'],
                    studentName: _reportData!['studentName'],
                    studentEmail: _reportData!['studentEmail'],
                    department: _reportData!['department'] ?? '',
                    studentNumber: _reportData!['studentNumber'] ?? '',
                    date: selectedDate!,
                    startTime: start,
                    endTime: end,
                    totalHours: hours,
                    hourlyRate: hourlyRate,
                    totalAmount: hours * hourlyRate,
                    status: 'draft',
                    task: taskTitleController.text
                        .trim(), // For backward compatibility
                    taskType: selectedTaskType.value,
                    customTaskType: selectedTaskType == TaskType.other
                        ? customTaskTypeController.text.trim()
                        : null,
                    taskTitle: taskTitleController.text.trim(),
                    taskDescription: taskDescriptionController.text.isNotEmpty
                        ? taskDescriptionController.text.trim()
                        : null,
                    taskProgress: taskProgress,
                    taskStatus: selectedTaskStatus.value,
                    notes: notesController.text.isNotEmpty
                        ? notesController.text
                        : null,
                    createdAt: DateTime.now(),
                    reportId: widget.reportId,
                    reportMonth: widget.month,
                  );

                  await timesheetRef.set(timesheet.toFirestore());

                  // Update report totals
                  await _updateReportTotals();

                  Navigator.pop(context);
                  _loadReportDetails();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Time entry added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Entry'),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getTaskStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.notStarted:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.timelapse;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.onHold:
        return Icons.pause_circle;
    }
  }

  Color _getTaskStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.notStarted:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.orange;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.onHold:
        return Colors.red;
    }
  }

  Future<void> _showEditTimesheetDialog(StudentTimesheet timesheet) async {
    DateTime? selectedDate = timesheet.date;
    TimeOfDay? startTime = TimeOfDay.fromDateTime(timesheet.startTime);
    TimeOfDay? endTime = TimeOfDay.fromDateTime(timesheet.endTime);
    TaskType selectedTaskType = timesheet.taskTypeEnum;
    final customTaskTypeController = TextEditingController(
      text: timesheet.customTaskType ?? '',
    );
    final taskTitleController = TextEditingController(
      text: timesheet.taskTitle ?? timesheet.task,
    );
    final taskDescriptionController = TextEditingController(
      text: timesheet.taskDescription ?? '',
    );
    int taskProgress = timesheet.taskProgress;
    TaskStatus selectedTaskStatus = timesheet.taskStatusEnum;
    final notesController = TextEditingController(text: timesheet.notes ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                const Expanded(child: Text('Edit Time Entry')),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Picker
                    Text(
                      'Date *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final minDate = _getAllowedDateMin();
                        final maxDate = _getAllowedDateMax();

                        if (maxDate.isBefore(minDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No available dates for this report period',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        DateTime initialDate = selectedDate ?? maxDate;
                        if (initialDate.isBefore(minDate)) {
                          initialDate = minDate;
                        } else if (initialDate.isAfter(maxDate)) {
                          initialDate = maxDate;
                        }

                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: initialDate,
                          firstDate: minDate,
                          lastDate: maxDate,
                        );
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate == null
                                  ? 'Select date'
                                  : DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(selectedDate!),
                            ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: startTime ?? TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setDialogState(() => startTime = time);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        startTime?.format(dialogContext) ??
                                            'Start',
                                      ),
                                      const Icon(Icons.access_time, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: endTime ?? TimeOfDay.now(),
                                  );
                                  if (time != null) {
                                    setDialogState(() => endTime = time);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        endTime?.format(dialogContext) ?? 'End',
                                      ),
                                      const Icon(Icons.access_time, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Divider(),
                    const SizedBox(height: 8),

                    // Task Type Dropdown
                    Text(
                      'Task Type *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskType>(
                      initialValue: selectedTaskType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: TaskType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedTaskType = value);
                        }
                      },
                    ),
                    // Custom Task Type field (shown when "Other" is selected)
                    if (selectedTaskType == TaskType.other) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Specify Task Type *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: customTaskTypeController,
                        decoration: InputDecoration(
                          hintText: 'Enter custom task type name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Task Title
                    Text(
                      'Task Title *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskTitleController,
                      decoration: InputDecoration(
                        hintText: 'Enter a title for this task',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Task Description
                    Text(
                      'Description *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: taskDescriptionController,
                      decoration: InputDecoration(
                        hintText: 'Describe the work done in detail',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Progress Slider
                    Text(
                      'Progress *: $taskProgress%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('0%'),
                        Expanded(
                          child: Slider(
                            value: taskProgress.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            activeColor: Colors.orange.shade600,
                            label: '$taskProgress%',
                            onChanged: (value) {
                              setDialogState(
                                () => taskProgress = value.toInt(),
                              );
                            },
                          ),
                        ),
                        const Text('100%'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Task Status Dropdown
                    Text(
                      'Status *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TaskStatus>(
                      initialValue: selectedTaskStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: TaskStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              Icon(
                                _getTaskStatusIcon(status),
                                size: 18,
                                color: _getTaskStatusColor(status),
                              ),
                              const SizedBox(width: 8),
                              Text(status.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedTaskStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'Add any additional notes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validate required fields
                  if (selectedDate == null ||
                      startTime == null ||
                      endTime == null ||
                      taskTitleController.text.trim().isEmpty ||
                      taskDescriptionController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Validate custom task type when "Other" is selected
                  if (selectedTaskType == TaskType.other &&
                      customTaskTypeController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please specify the task type'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (selectedDate != null && !_isDateAllowed(selectedDate!)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Date must be within the report period',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Calculate hours
                  final start = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    startTime!.hour,
                    startTime!.minute,
                  );
                  final end = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    endTime!.hour,
                    endTime!.minute,
                  );
                  final duration = end.difference(start);
                  final hours = duration.inMinutes / 60.0;

                  if (hours <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Update timesheet entry
                  final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
                  await FirebaseFirestore.instance
                      .collection('student_timesheets')
                      .doc(timesheet.id)
                      .update({
                        'date': Timestamp.fromDate(selectedDate!),
                        'startTime': Timestamp.fromDate(start),
                        'endTime': Timestamp.fromDate(end),
                        'totalHours': hours,
                        'totalAmount': hours * hourlyRate,
                        'task': taskTitleController.text.trim(),
                        'taskType': selectedTaskType.value,
                        'customTaskType': selectedTaskType == TaskType.other
                            ? customTaskTypeController.text.trim()
                            : null,
                        'taskTitle': taskTitleController.text.trim(),
                        'taskDescription':
                            taskDescriptionController.text.isNotEmpty
                            ? taskDescriptionController.text.trim()
                            : null,
                        'taskProgress': taskProgress,
                        'taskStatus': selectedTaskStatus.value,
                        'notes': notesController.text.isNotEmpty
                            ? notesController.text
                            : null,
                      });

                  // Update report totals
                  await _updateReportTotals();

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _loadReportDetails();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Time entry updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
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

  void _showViewTimesheetDialog(StudentTimesheet timesheet) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.visibility, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Time Entry Details')),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(dialogContext).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date Section
                _buildViewSection(
                  'Date',
                  dateFormat.format(timesheet.date),
                  Icons.calendar_today,
                  Colors.blue,
                ),
                const SizedBox(height: 16),

                // Time Section
                _buildViewSection(
                  'Time',
                  '${timeFormat.format(timesheet.startTime)} - ${timeFormat.format(timesheet.endTime)}',
                  Icons.access_time,
                  Colors.orange,
                ),
                const SizedBox(height: 16),

                // Hours & Earnings Row
                Row(
                  children: [
                    Expanded(
                      child: _buildViewSection(
                        'Total Hours',
                        '${timesheet.totalHours.toStringAsFixed(2)} hrs',
                        Icons.timelapse,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildViewSection(
                        'Earnings',
                        '฿${timesheet.totalAmount.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Divider(),
                const SizedBox(height: 16),

                // Task Type Section
                _buildViewSection(
                  'Task Type',
                  timesheet.taskTypeDisplayName,
                  Icons.category,
                  Colors.indigo,
                ),
                const SizedBox(height: 16),

                // Task Title Section
                if (timesheet.taskTitle != null &&
                    timesheet.taskTitle!.isNotEmpty) ...[
                  _buildViewSection(
                    'Task Title',
                    timesheet.taskTitle!,
                    Icons.title,
                    Colors.teal,
                  ),
                  const SizedBox(height: 16),
                ],

                // Task Description Section
                if (timesheet.taskDescription != null &&
                    timesheet.taskDescription!.isNotEmpty) ...[
                  _buildViewSection(
                    'Description',
                    timesheet.taskDescription!,
                    Icons.description,
                    Colors.blueGrey,
                    isMultiLine: true,
                  ),
                  const SizedBox(height: 16),
                ],

                // Progress & Status Row
                Row(
                  children: [
                    Expanded(
                      child: _buildViewSection(
                        'Progress',
                        '${timesheet.taskProgress}%',
                        Icons.trending_up,
                        Colors.amber,
                        showProgressBar: true,
                        progressValue: timesheet.taskProgress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildViewSection(
                        'Task Status',
                        timesheet.taskStatusEnum.displayName,
                        _getTaskStatusIcon(timesheet.taskStatusEnum),
                        _getTaskStatusColor(timesheet.taskStatusEnum),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes Section
                if (timesheet.notes != null && timesheet.notes!.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildViewSection(
                    'Notes',
                    timesheet.notes!,
                    Icons.note,
                    Colors.grey,
                    isMultiLine: true,
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          timesheet.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(timesheet.status),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(timesheet.status),
                            size: 16,
                            color: _getStatusColor(timesheet.status),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timesheet.status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(timesheet.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          // Show Edit button if report is draft and not finalized
          if ((_reportData?['status'] ?? 'draft') == 'draft' &&
              (_reportData?['isFinalized'] ?? false) == false)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showEditTimesheetDialog(timesheet);
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
            ),
        ],
      ),
    );
  }

  Widget _buildViewSection(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isMultiLine = false,
    bool showProgressBar = false,
    int progressValue = 0,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (showProgressBar) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressValue / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ] else
            Text(
              value,
              style: TextStyle(
                fontSize: isMultiLine ? 14 : 16,
                fontWeight: isMultiLine ? FontWeight.normal : FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDeleteTimesheetDialog(StudentTimesheet timesheet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 12),
            const Text('Delete Entry?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this time entry?'),
            const SizedBox(height: 16),
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
                    DateFormat('MMM dd, yyyy').format(timesheet.date),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('HH:mm').format(timesheet.startTime)} - ${DateFormat('HH:mm').format(timesheet.endTime)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (timesheet.taskTitle != null ||
                      timesheet.task.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timesheet.taskTitle ?? timesheet.task,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('student_timesheets')
            .doc(timesheet.id)
            .delete();

        // Update report totals
        await _updateReportTotals();

        if (mounted) {
          _loadReportDetails();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time entry deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateReportTotals() async {
    final timesheetQuery = await FirebaseFirestore.instance
        .collection('student_timesheets')
        .where('reportId', isEqualTo: widget.reportId)
        .get();

    final timesheets = timesheetQuery.docs
        .map((doc) => StudentTimesheet.fromFirestore(doc))
        .toList();

    final totalHours = timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;

    await FirebaseFirestore.instance
        .collection('student_monthly_reports')
        .doc(widget.reportId)
        .update({
          'timesheetCount': timesheets.length,
          'totalHours': totalHours,
          'totalAmount': totalHours * hourlyRate,
        });
  }

  Future<void> _submitReport() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.send, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Submit Report?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit this report for approval?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will not be able to edit the report after submission',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      // Update report status to submitted
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.reportId)
          .update({
            'status': 'submitted',
            'submittedAt': DateTime.now(),
            'submittedBy': user?.name ?? 'Unknown',
          });

      // Update all associated timesheets to submitted status
      final timesheetQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('reportId', isEqualTo: widget.reportId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in timesheetQuery.docs) {
        batch.update(doc.reference, {'status': 'submitted'});
      }
      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully for approval!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload the report to show updated status
      _loadReportDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
