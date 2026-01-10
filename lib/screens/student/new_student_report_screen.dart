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
  bool _isCreating = false;

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
      });
    }
  }

  Future<void> _createReport() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

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

      // Check if report already exists for this month
      final existingReport = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('studentId', isEqualTo: user.id)
          .where('month', isEqualTo: month)
          .get();

      if (existingReport.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A report for $monthDisplay already exists'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isCreating = false);
        return;
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
        month: month,
        monthDisplay: monthDisplay,
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Create Monthly Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
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
            ),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.event,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      monthDisplayFormat.format(_selectedMonth),
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
                                  'After creating the report, you can add time entries for this month',
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
  );
}
}
