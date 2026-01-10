import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel_package;
import '../../models/student_timesheet.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class StudentReportScreen extends StatefulWidget {
  const StudentReportScreen({super.key});

  @override
  State<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends State<StudentReportScreen>
    with SingleTickerProviderStateMixin {
  StudentProfile? _studentProfile;
  List<StudentTimesheet> _timesheets = [];
  Map<String, List<StudentTimesheet>> _timesheetsByMonth = {};
  List<String> _availableMonths = [];
  String? _selectedMonth;
  bool _isLoading = true;
  late TabController _tabController;
  int _selectedTabIndex = 0; // 0 = Current Month, 1 = History

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _getMonthDisplay(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month);
    return DateFormat('MMMM yyyy').format(date);
  }

  void _groupTimesheetsByMonth() {
    _timesheetsByMonth.clear();
    _availableMonths.clear();

    for (var timesheet in _timesheets) {
      final monthKey = _getMonthKey(timesheet.date);
      if (!_timesheetsByMonth.containsKey(monthKey)) {
        _timesheetsByMonth[monthKey] = [];
        _availableMonths.add(monthKey);
      }
      _timesheetsByMonth[monthKey]!.add(timesheet);
    }

    // Sort months in descending order (most recent first)
    _availableMonths.sort((a, b) => b.compareTo(a));

    // Set selected month to current month if available
    final currentMonth = _getMonthKey(DateTime.now());
    if (_availableMonths.contains(currentMonth)) {
      _selectedMonth = currentMonth;
    } else if (_availableMonths.isNotEmpty) {
      _selectedMonth = _availableMonths.first;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id ?? '';

    try {
      print('DEBUG STUDENT: Loading student profile for userId: $userId');
      // Load student profile
      final profileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(userId)
          .get();

      if (profileDoc.exists) {
        _studentProfile = StudentProfile.fromFirestore(profileDoc);
        print('DEBUG STUDENT: Profile loaded successfully');
      } else {
        print('DEBUG STUDENT: No profile found for user');
      }

      print('DEBUG STUDENT: Loading timesheets...');
      // Load timesheets
      final timesheetQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('studentId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      _timesheets = timesheetQuery.docs
          .map((doc) => StudentTimesheet.fromFirestore(doc))
          .toList();

      print('DEBUG STUDENT: Loaded ${_timesheets.length} timesheets');

      _groupTimesheetsByMonth();

      setState(() => _isLoading = false);
    } catch (e) {
      print('===========================================');
      print('DEBUG STUDENT: ERROR LOADING DATA');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Full error details: ${e.toString()}');
      print('===========================================');

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text('Error loading data: $e'),
          duration: const Duration(seconds: 10),
        ));
      }
    }
  }

  void _showAddTimesheetDialog() {
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.access_time, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Log Working Hours'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                DateFormat('MMM dd, yyyy').format(selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Start Time
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (picked != null) {
                        setState(() => startTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                startTime.format(context),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // End Time
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (picked != null) {
                        setState(() => endTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                endTime.format(context),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Total Hours Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timelapse, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Hours',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${_calculateHours(startTime, endTime).toStringAsFixed(2)} hours',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Notes
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Describe your work...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                    maxLines: 3,
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      await _submitTimesheet(
                        selectedDate,
                        startTime,
                        endTime,
                        notesController.text.trim(),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Submit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateHours(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return (endMinutes - startMinutes) / 60.0;
  }

  Future<void> _submitTimesheet(
    DateTime date,
    TimeOfDay startTime,
    TimeOfDay endTime,
    String notes,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser!;

    try {
      final startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );
      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        endTime.hour,
        endTime.minute,
      );
      final totalHours = _calculateHours(startTime, endTime);
      final hourlyRate = _studentProfile?.hourlyRate ?? 0.0;

      final timesheet = StudentTimesheet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: user.id,
        studentName: user.name,
        studentEmail: user.email,
        department: user.department,
        studentNumber: _studentProfile?.studentNumber ?? '',
        date: date,
        startTime: startDateTime,
        endTime: endDateTime,
        totalHours: totalHours,
        hourlyRate: hourlyRate,
        totalAmount: totalHours * hourlyRate,
        status: 'submitted',
        notes: notes.isNotEmpty ? notes : null,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('student_timesheets')
          .doc(timesheet.id)
          .set(timesheet.toFirestore());

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timesheet submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting timesheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (mounted) {
        context.go('/');
      }
    }
  }

  void _submitTimesheetReport() async {
    if (_selectedMonth == null || _timesheetsByMonth[_selectedMonth]?.isEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No timesheets to submit for this month'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final monthTimesheets = _timesheetsByMonth[_selectedMonth]!;
    final monthDisplay = _getMonthDisplay(_selectedMonth!);

    // Check if any are draft status
    final draftTimesheets = monthTimesheets.where((t) => t.status == 'draft').toList();
    if (draftTimesheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All timesheets for $monthDisplay have already been submitted'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Calculate total hours
    final totalHours = draftTimesheets.fold<double>(
      0,
      (sum, ts) => sum + ts.totalHours,
    );

    // Show confirmation dialog with summary
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Submit Report - $monthDisplay'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to submit your timesheet report for $monthDisplay:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Entries:'),
                      Text(
                        '${draftTimesheets.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Hours:'),
                      Text(
                        '${totalHours.toStringAsFixed(2)} hrs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Hourly Rate:'),
                      Text(
                        '฿${_studentProfile?.hourlyRate.toStringAsFixed(2) ?? '0.00'}/hr',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '฿${(totalHours * (_studentProfile?.hourlyRate ?? 0)).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Once submitted, your supervisor will review your timesheets.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Create monthly report
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUser;
        final reportId = FirebaseFirestore.instance
            .collection('student_monthly_reports')
            .doc()
            .id;

        final monthlyReport = {
          'id': reportId,
          'studentId': user!.id,
          'studentName': user.name,
          'studentEmail': user.email,
          'month': _selectedMonth,
          'monthDisplay': monthDisplay,
          'timesheetCount': draftTimesheets.length,
          'totalHours': totalHours,
          'hourlyRate': _studentProfile?.hourlyRate ?? 0.0,
          'totalAmount': totalHours * (_studentProfile?.hourlyRate ?? 0.0),
          'status': 'submitted',
          'createdAt': Timestamp.now(),
          'submittedAt': Timestamp.now(),
        };

        // Save monthly report
        await FirebaseFirestore.instance
            .collection('student_monthly_reports')
            .doc(reportId)
            .set(monthlyReport);

        // Update all draft timesheets to submitted status and link to report
        final batch = FirebaseFirestore.instance.batch();
        for (var timesheet in draftTimesheets) {
          final docRef = FirebaseFirestore.instance
              .collection('student_timesheets')
              .doc(timesheet.id);
          batch.update(docRef, {
            'status': 'submitted',
            'reportId': reportId,
            'reportMonth': _selectedMonth,
          });
        }
        await batch.commit();

        // Reload data
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Report for $monthDisplay submitted successfully!\nTotal: ${totalHours.toStringAsFixed(2)} hours',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        print('ERROR submitting report: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting report: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Widget _buildCurrentMonthView() {
    return Column(
      children: [
        _buildProfileCard(),
        _buildMonthSelector(),
        Expanded(child: _buildTimesheetList()),
      ],
    );
  }

  Widget _buildHistoryView() {
    return _buildReportHistory();
  }

  Widget _buildMonthSelector() {
    if (_availableMonths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Select Month:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedMonth,
              isExpanded: true,
              underline: const SizedBox(),
              items: _availableMonths.map((monthKey) {
                final monthTimesheets = _timesheetsByMonth[monthKey]!;
                final draftCount = monthTimesheets.where((t) => t.status == 'draft').length;
                final submittedCount = monthTimesheets.where((t) => t.status == 'submitted').length;

                return DropdownMenuItem(
                  value: monthKey,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getMonthDisplay(monthKey),
                        style: const TextStyle(fontSize: 15),
                      ),
                      Row(
                        children: [
                          if (draftCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$draftCount draft',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (submittedCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$submittedCount submitted',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedMonth = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('studentId', isEqualTo: _studentProfile?.userId ?? '')
          .orderBy('month', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data?.docs ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No submitted reports yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Submit your first monthly report to see it here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final data = reports[index].data() as Map<String, dynamic>;
            final monthDisplay = data['monthDisplay'] ?? '';
            final status = data['status'] ?? 'submitted';
            final totalHours = (data['totalHours'] ?? 0.0).toDouble();
            final totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
            final timesheetCount = data['timesheetCount'] ?? 0;
            final submittedAt = data['submittedAt'] != null
                ? (data['submittedAt'] as Timestamp).toDate()
                : null;

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
              case 'paid':
                statusColor = Colors.blue;
                statusIcon = Icons.payment;
                break;
              default:
                statusColor = Colors.orange;
                statusIcon = Icons.pending;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Navigate to the detailed report screen
                  context.go('/student-monthly-report-detail', extra: {
                    'reportId': reports[index].id,
                    'month': data['month'] ?? '',
                    'monthDisplay': monthDisplay,
                  });
                },
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    monthDisplay,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (submittedAt != null)
                                    Text(
                                      'Submitted ${DateFormat('MMM d, y').format(submittedAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(statusIcon, size: 16, color: statusColor),
                                const SizedBox(width: 4),
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
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(Icons.event_note, '$timesheetCount', 'Entries'),
                          _buildStatItem(Icons.access_time, '${totalHours.toStringAsFixed(1)}h', 'Hours'),
                          _buildStatItem(Icons.attach_money, '฿${totalAmount.toStringAsFixed(2)}', 'Amount'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.orange.shade600),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Working Hours'),
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
          // Submit Report Button (only show on Current Month tab)
          if (_selectedTabIndex == 0 &&
              _selectedMonth != null &&
              _timesheetsByMonth[_selectedMonth]?.any((t) => t.status == 'draft') == true)
            IconButton(
              icon: const Icon(Icons.send),
              tooltip: 'Submit Monthly Report',
              onPressed: _submitTimesheetReport,
            ),
          // Settings/Profile Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') {
                context.go('/settings');
              } else if (value == 'logout') {
                _handleLogout(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.access_time),
              text: 'Current Month',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studentProfile == null
          ? _buildNoProfileState()
          : ResponsiveContainer(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCurrentMonthView(),
                  _buildHistoryView(),
                ],
              ),
            ),
      floatingActionButton: _studentProfile != null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAddTimesheetDialog,
                  borderRadius: BorderRadius.circular(24),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Log Hours',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNoProfileState() {
    return Center(
      child: Text('Profile not found. Please contact administrator.'),
    );
  }

  Widget _buildProfileCard() {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _studentProfile!.studentNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_studentProfile!.course} - ${_studentProfile!.yearLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hourly Rate:',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    currencyFormat.format(_studentProfile!.hourlyRate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetList() {
    final monthTimesheets = _selectedMonth != null
        ? (_timesheetsByMonth[_selectedMonth] ?? [])
        : [];

    if (monthTimesheets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No timesheets yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Log Hours" to add your first entry',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: monthTimesheets.length,
      itemBuilder: (context, index) {
        final timesheet = monthTimesheets[index];
        return _buildTimesheetCard(timesheet);
      },
    );
  }

  Widget _buildTimesheetCard(StudentTimesheet timesheet) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

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
      case 'paid':
        statusColor = Colors.blue;
        statusIcon = Icons.payment;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(timesheet.date),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        timesheet.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
                Expanded(
                  child: _buildInfoRow(
                    Icons.schedule,
                    'Start',
                    timeFormat.format(timesheet.startTime),
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    Icons.schedule,
                    'End',
                    timeFormat.format(timesheet.endTime),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    Icons.timelapse,
                    'Hours',
                    '${timesheet.totalHours.toStringAsFixed(2)}h',
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    Icons.attach_money,
                    'Amount',
                    currencyFormat.format(timesheet.totalAmount),
                  ),
                ),
              ],
            ),
            if (timesheet.notes != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        timesheet.notes!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
