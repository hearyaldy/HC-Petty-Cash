import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/student_timesheet.dart';
import '../../utils/responsive_helper.dart';

class NewStudentReportScreen extends StatefulWidget {
  const NewStudentReportScreen({super.key});

  @override
  State<NewStudentReportScreen> createState() => _NewStudentReportScreenState();
}

class _NewStudentReportScreenState extends State<NewStudentReportScreen> {
  DateTime _selectedMonth = DateTime.now();
  late DateTime _periodStart;
  late DateTime _periodEnd;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _syncPeriodWithMonth();
  }

  void _syncPeriodWithMonth() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    _periodStart = firstDay;
    _periodEnd = lastDay;
  }

  DateTime _monthFirstDay() =>
      DateTime(_selectedMonth.year, _selectedMonth.month, 1);

  DateTime _monthLastDay() =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

  Future<void> _selectPeriodStart() async {
    final firstDay = _monthFirstDay();
    final lastDay = _monthLastDay();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _periodStart.isBefore(firstDay)
          ? firstDay
          : _periodStart.isAfter(lastDay)
              ? lastDay
              : _periodStart,
      firstDate: firstDay,
      lastDate: lastDay,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _periodStart = picked;
        if (_periodStart.isAfter(_periodEnd)) {
          _periodEnd = _periodStart;
        }
      });
    }
  }

  Future<void> _selectPeriodEnd() async {
    final firstDay = _monthFirstDay();
    final lastDay = _monthLastDay();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _periodEnd.isBefore(firstDay)
          ? firstDay
          : _periodEnd.isAfter(lastDay)
              ? lastDay
              : _periodEnd,
      firstDate: firstDay,
      lastDate: lastDay,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _periodEnd = picked;
        if (_periodEnd.isBefore(_periodStart)) {
          _periodStart = _periodEnd;
        }
      });
    }
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

  Widget _buildWelcomeHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
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
            right: -28,
            top: -28,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -36,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
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
                  const SizedBox(width: 8),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 20),
              // Content with icon and title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create New Monthly Report',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the month for your timesheet report',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _syncPeriodWithMonth();
      });
    }
  }

  Future<void> _createReport() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    if (_periodStart.isAfter(_periodEnd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report period start must be before end'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Load student profile
      final profileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(user.id)
          .get();

      if (!profileDoc.exists) {
        throw 'Student profile not found';
      }

      final profile = StudentProfile.fromFirestore(profileDoc);

      // Format month
      final monthFormat = DateFormat('yyyy-MM');
      final monthDisplayFormat = DateFormat('MMMM yyyy');
      final month = monthFormat.format(_selectedMonth);
      final monthDisplay = monthDisplayFormat.format(_selectedMonth);

      // Check for overlapping report periods within the same month
      final existingReport = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('studentId', isEqualTo: user.id)
          .where('month', isEqualTo: month)
          .get();

      if (existingReport.docs.isNotEmpty) {
        for (final doc in existingReport.docs) {
          final data = doc.data();
          DateTime existingStart;
          DateTime existingEnd;

          if (data['periodStart'] is Timestamp &&
              data['periodEnd'] is Timestamp) {
            existingStart = (data['periodStart'] as Timestamp).toDate();
            existingEnd = (data['periodEnd'] as Timestamp).toDate();
          } else {
            // Fallback to full month range for legacy reports
            existingStart = DateTime(
              _selectedMonth.year,
              _selectedMonth.month,
              1,
            );
            existingEnd = DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
              0,
            );
          }

          final overlaps = !_periodEnd.isBefore(existingStart) &&
              !_periodStart.isAfter(existingEnd);

          if (overlaps) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Report period overlaps with an existing report for $monthDisplay',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isCreating = false);
            return;
          }
        }
      }

      // Create new report
      final reportRef = FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc();

      final report = StudentMonthlyReport(
        id: reportRef.id,
        studentId: user.id,
        studentName: user.name,
        studentEmail: user.email,
        studentNumber: profile.studentNumber,
        department:
            '', // Department can be added later if needed from user collection
        month: month,
        monthDisplay: monthDisplay,
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        timesheetCount: 0,
        totalHours: 0.0,
        hourlyRate: profile.hourlyRate,
        totalAmount: 0.0,
        status: 'draft',
        createdAt: DateTime.now(),
      );

      await reportRef.set(report.toFirestore());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report for $monthDisplay created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to report detail
      context.push(
        '/student-monthly-report-detail',
        extra: {
          'reportId': report.id,
          'month': report.month,
          'monthDisplay': report.monthDisplay,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthDisplayFormat = DateFormat('MMMM yyyy');
    final dayFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Welcome Header
                _buildWelcomeHeader(),
                const SizedBox(height: 32),

                // Month Selection Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.calendar_month,
                                color: Colors.orange.shade600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Report Period',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Month',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _selectMonth,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange.shade50,
                                      Colors.orange.shade100,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.event,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          monthDisplayFormat.format(
                                            _selectedMonth,
                                          ),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.edit_calendar,
                                      color: Colors.orange.shade600,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Report Period',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectPeriodStart,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Start',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            dayFormat.format(_periodStart),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectPeriodEnd,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'End',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            dayFormat.format(_periodEnd),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'After creating the report, you can add time entries for the selected period. Backdating is limited to the last 7 days.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Create Button
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isCreating ? null : _createReport,
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: _isCreating
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    'Create Report',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
