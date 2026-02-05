import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
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
    final currentStatus = _reportData?['status'] ?? 'draft';
    final paymentStatusOptions = ['paid', 'not_paid', 'review'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Payment Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: paymentStatusOptions.map((status) => RadioListTile<String>(
            title: Text(_formatPaymentStatus(status)),
            value: status,
            groupValue: _reportData?['paymentStatus'] ?? 'not_paid',
            onChanged: (value) {
              if (value != null) {
                Navigator.of(context).pop();
                _updatePaymentStatus(value);
              }
            },
          )).toList(),
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

    final rateController = TextEditingController(text: currentRate.toStringAsFixed(2));
    String? selectedGrade = currentGrade;
    bool overrideRate = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Calculate total based on entered rate
          double displayRate = double.tryParse(rateController.text) ?? currentRate;
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
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                                color: currentGrade != null ? Colors.blue : Colors.grey,
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
                    final gradeRate = StudentRateConfig.getRate(studentRole, grade);
                    final isSelected = selectedGrade == grade;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedGrade = grade;
                            if (!overrideRate) {
                              rateController.text = gradeRate.toStringAsFixed(2);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? _getGradeColor(grade) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? _getGradeColor(grade) : Colors.grey.shade300,
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
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                '${AppConstants.currencySymbol}${gradeRate.toStringAsFixed(2)}/h',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
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
                          final gradeRate = StudentRateConfig.getRate(studentRole, selectedGrade);
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Hourly Rate',
                      prefixText: '${AppConstants.currencySymbol} ',
                      suffixText: '/hour',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Changes will update this report and the student\'s profile for future reports.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
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
                          newRate: double.tryParse(rateController.text) ?? currentRate,
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
    final timesheetCount = _timesheets.length;
    final totalHours = _timesheets.fold<double>(
      0.0,
      (sum, ts) => sum + ts.totalHours,
    );
    final hourlyRate = _reportData?['hourlyRate'] ?? 0.0;
    final totalAmount = totalHours * hourlyRate;

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
      print('Error getting student profile: $e');
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
      print('Error getting student profile: $e');
    }

    final service = StudentPdfExportService();
    final pdfBytes = await service.exportStudentReport(
      studentName: _reportData?['studentName'] ?? 'Unknown',
      studentNumber: _reportData?['studentNumber'] ?? 'Unknown',
      monthDisplay: widget.monthDisplay,
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
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
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
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _generatePdf,
            tooltip: 'Print Report',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showRateAndGradeDialog,
            tooltip: 'Rate & Grade Settings',
          ),
          IconButton(
            icon: const Icon(Icons.payment),
            onPressed: _showPaymentStatusDialog,
            tooltip: 'Update Payment Status',
          ),
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
              Column(
                children: [
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
                  const SizedBox(height: 4),
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getGradeColor(_studentProfile!['grade']),
                        borderRadius: BorderRadius.circular(20),
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
      default:
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
                    if (timesheet.taskStatus != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: taskStatusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(taskStatusIcon, size: 12, color: taskStatusColor),
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
                    if (timesheet.taskTitle != null && timesheet.taskTitle!.isNotEmpty) ...[
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
                    if (timesheet.taskDescription != null && timesheet.taskDescription!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.description, size: 16, color: Colors.grey[600]),
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
                          Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
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
