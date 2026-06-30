import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../services/student_summary_pdf_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class AdminStudentReportsScreen extends StatefulWidget {
  const AdminStudentReportsScreen({super.key});

  @override
  State<AdminStudentReportsScreen> createState() =>
      _AdminStudentReportsScreenState();
}

class _AdminStudentReportsScreenState extends State<AdminStudentReportsScreen> {
  String? _selectedStudentId;
  String? _selectedStatus;
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = true;

  // Full profile data for PDF reports (studentId → profile fields)
  final Map<String, Map<String, dynamic>> _profiles = {};

  // Store reports in state to avoid StreamBuilder issues on web
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reports = [];
  bool _isLoadingReports = true;
  String? _reportsError;

  // Grouped reports by student
  final Map<String, List<Map<String, dynamic>>> _groupedReports = {};

  // Track expanded state for each student
  final Set<String> _expandedStudents = {};

  final List<String> _statusOptions = [
    'draft',
    'submitted',
    'approved',
    'rejected',
  ];

  String _formatReportPeriod(Map<String, dynamic> reportData) {
    final startRaw = reportData['periodStart'];
    final endRaw = reportData['periodEnd'];
    if (startRaw is Timestamp && endRaw is Timestamp) {
      final start = startRaw.toDate();
      final end = endRaw.toDate();
      final format = DateFormat('MMM dd, yyyy');
      return '${format.format(start)} - ${format.format(end)}';
    }

    final month = reportData['month'] ?? '';
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final monthDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        return DateFormat('MMMM yyyy').format(monthDate);
      }
    } catch (_) {}

    return month.isNotEmpty ? month : 'Unknown';
  }

  DateTime? _reportPeriodStart(Map<String, dynamic> reportData) {
    final startRaw = reportData['periodStart'];
    if (startRaw is Timestamp) {
      return startRaw.toDate();
    }
    final month = reportData['month'];
    if (month is String) {
      final parts = month.split('-');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final monthNum = int.tryParse(parts[1]);
        if (year != null && monthNum != null) {
          return DateTime(year, monthNum, 1);
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadReports();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);

    try {
      final studentsQuery = await FirebaseFirestore.instance
          .collection('student_profiles')
          .get(const GetOptions(source: Source.server));

      final uniqueStudentsMap = <String, Map<String, dynamic>>{};
      _profiles.clear();

      for (final doc in studentsQuery.docs) {
        final data = doc.data();
        final id = doc.id;
        uniqueStudentsMap[id] = {
          'id': id,
          'name': data['studentName'] ?? 'Unknown',
          'photoUrl': data['photoUrl'] as String?,
        };
        // Store full profile for PDF reports
        _profiles[id] = {
          'language': data['language'] ?? '',
          'role': data['role'] ?? '',
          'grade': data['grade'] ?? '',
          'hourlyRate': (data['hourlyRate'] as num?)?.toDouble() ?? 0.0,
        };
      }
      _students = uniqueStudentsMap.values.toList();

      setState(() => _isLoadingStudents = false);
    } catch (e) {
      debugPrint('Error loading students: $e');
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
      _reportsError = null;
    });

    try {
      final query = _buildQuery();
      final snapshot = await query.get(const GetOptions(source: Source.server));

      if (mounted) {
        setState(() {
          _reports = snapshot.docs;
          _groupReportsByStudent();
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) {
        setState(() {
          _reportsError = e.toString();
          _isLoadingReports = false;
        });
      }
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('student_monthly_reports')
        .orderBy('month', descending: true);

    if (_selectedStudentId != null) {
      query = query.where('studentId', isEqualTo: _selectedStudentId);
    }

    if (_selectedStatus != null) {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return query;
  }

  void _groupReportsByStudent() {
    _groupedReports.clear();

    for (final doc in _reports) {
      final data = doc.data();
      final studentId = data['studentId'] ?? 'unknown';
      final studentName = data['studentName'] ?? 'Unknown';

      if (!_groupedReports.containsKey(studentId)) {
        _groupedReports[studentId] = [];
      }

      _groupedReports[studentId]!.add({
        'reportId': doc.id,
        'studentId': studentId,
        'studentName': studentName,
        ...data,
      });
    }

    // Sort reports within each student by month (newest first)
    for (final reports in _groupedReports.values) {
      reports.sort((a, b) {
        final startA = _reportPeriodStart(a);
        final startB = _reportPeriodStart(b);
        if (startA != null && startB != null) {
          return startB.compareTo(startA);
        }
        final monthA = a['month'] ?? '';
        final monthB = b['month'] ?? '';
        return monthB.compareTo(monthA);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: ResponsiveContainer(
          child: Column(
            children: [
              _buildWelcomeHeader(),
              _buildFilterBar(),
              const SizedBox(height: 24),
              Expanded(child: _buildReportsList()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReportOptionsDialog() async {
    StudentSummaryReportType? selectedType;
    bool generating = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.picture_as_pdf, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Print Summary Report'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose the type of report to generate. Data is based on the current filter (${_reports.length} reports).',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  _reportTypeCard(
                    type: StudentSummaryReportType.workSummary,
                    selected: selectedType,
                    icon: Icons.people_outline,
                    title: 'Student Work Summary',
                    subtitle: 'All students — total hours, amounts, approval status in one table.',
                    onTap: () => setS(() => selectedType = StudentSummaryReportType.workSummary),
                  ),
                  const SizedBox(height: 8),
                  _reportTypeCard(
                    type: StudentSummaryReportType.paymentByLanguage,
                    selected: selectedType,
                    icon: Icons.language,
                    title: 'Payment by Language',
                    subtitle: 'Students grouped by language with subtotals and grand total.',
                    onTap: () => setS(() => selectedType = StudentSummaryReportType.paymentByLanguage),
                  ),
                  const SizedBox(height: 8),
                  _reportTypeCard(
                    type: StudentSummaryReportType.taskByLanguage,
                    selected: selectedType,
                    icon: Icons.category_outlined,
                    title: 'Work Type × Language',
                    subtitle: 'Cross-reference of task types per language (uses timesheet detail).',
                    onTap: () => setS(() => selectedType = StudentSummaryReportType.taskByLanguage),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: generating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: (selectedType == null || generating)
                    ? null
                    : () async {
                        setS(() => generating = true);
                        final nav = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _generateReport(selectedType!);
                          if (mounted) nav.pop();
                        } catch (e) {
                          if (mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to generate report: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.print),
                label: Text(generating ? 'Generating…' : 'Generate PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reportTypeCard({
    required StudentSummaryReportType type,
    required StudentSummaryReportType? selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == type;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.orange.shade600 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.orange.shade50 : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: isSelected ? Colors.orange.shade700 : Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected ? Colors.orange.shade800 : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.orange.shade600, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _generateReport(StudentSummaryReportType type) async {
    final reportData = _reports.map((doc) => {'reportId': doc.id, ...doc.data()}).toList();

    List<Map<String, dynamic>> timesheets = [];
    if (type == StudentSummaryReportType.taskByLanguage) {
      final reportIds = reportData.map((r) => r['reportId'] as String).toList();
      final chunks = <List<String>>[];
      for (var i = 0; i < reportIds.length; i += 30) {
        chunks.add(reportIds.sublist(i, i + 30 < reportIds.length ? i + 30 : reportIds.length));
      }
      for (final chunk in chunks) {
        final snap = await FirebaseFirestore.instance
            .collection('student_timesheets')
            .where('reportId', whereIn: chunk)
            .get(const GetOptions(source: Source.server));
        timesheets.addAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
      }
    }

    // Infer report year from the data (use current year as fallback)
    int reportYear = DateTime.now().year;
    for (final r in reportData) {
      final month = r['month'] as String? ?? '';
      final parts = month.split('-');
      if (parts.isNotEmpty) {
        final y = int.tryParse(parts[0]);
        if (y != null && y > 2000) { reportYear = y; break; }
      }
    }

    // Fetch budget data for comparison
    Map<String, dynamic>? budgetData;
    try {
      final budgetDoc = await FirebaseFirestore.instance
          .collection('student_labor_budgets')
          .doc('$reportYear')
          .get();
      if (budgetDoc.exists) budgetData = budgetDoc.data();
    } catch (_) {}

    final statusLabel = _selectedStatus != null ? _selectedStatus!.toUpperCase() : 'All';
    final bytes = await StudentSummaryPdfService().generateReport(
      type: type,
      reports: reportData,
      profiles: _profiles,
      timesheets: timesheets,
      statusFilter: _selectedStatus != null ? statusLabel : null,
      budgetData: budgetData,
    );

    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Widget _buildWelcomeHeader() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Student Reports',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      _buildHeaderActionButton(
                        icon: Icons.picture_as_pdf,
                        tooltip: 'Print Summary Report',
                        onPressed: _showReportOptionsDialog,
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderActionButton(
                        icon: Icons.refresh,
                        tooltip: 'Refresh',
                        onPressed: _loadReports,
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderActionButton(
                        icon: Icons.home_outlined,
                        tooltip: 'Home',
                        onPressed: () => context.go('/admin-hub'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.school, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Reports Management',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_reports.length} total reports',
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

  Widget _buildReportsList() {
    if (_reportsError != null) {
      return Center(child: Text('Error: $_reportsError'));
    }
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reports.isEmpty) {
      return _buildEmptyState();
    }

    // Get sorted list of students (by name)
    final sortedStudentIds = _groupedReports.keys.toList()
      ..sort((a, b) {
        final nameA = _groupedReports[a]!.first['studentName'] ?? '';
        final nameB = _groupedReports[b]!.first['studentName'] ?? '';
        return nameA.toString().compareTo(nameB.toString());
      });

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: sortedStudentIds.length,
      itemBuilder: (context, index) {
        final studentId = sortedStudentIds[index];
        final studentReports = _groupedReports[studentId]!;
        return _buildStudentReportsGroup(studentId, studentReports);
      },
    );
  }

  Widget _buildStudentReportsGroup(
    String studentId,
    List<Map<String, dynamic>> reports,
  ) {
    final studentName = reports.first['studentName'] ?? 'Unknown';
    final photoUrl =
        _students.firstWhere(
              (s) => s['id'] == studentId,
              orElse: () => const {'photoUrl': null},
            )['photoUrl']
            as String?;

    final isExpanded = _expandedStudents.contains(studentId);

    // Calculate totals for this student
    final totalReports = reports.length;
    double totalHours = 0;
    double totalAmount = 0;
    int approvedCount = 0;
    int pendingCount = 0;

    for (final report in reports) {
      totalHours += (report['totalHours'] ?? 0.0).toDouble();
      totalAmount += (report['totalAmount'] ?? 0.0).toDouble();
      final status = report['status'] ?? 'draft';
      if (status == 'approved') approvedCount++;
      if (status == 'submitted') pendingCount++;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Student Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedStudents.remove(studentId);
                } else {
                  _expandedStudents.add(studentId);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isExpanded
                    ? LinearGradient(
                        colors: [Colors.orange.shade50, Colors.orange.shade100],
                      )
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildAvatar(studentName, photoUrl),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$totalReports ${totalReports == 1 ? 'Report' : 'Reports'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                                if (approvedCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$approvedCount Approved',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$pendingCount Pending',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  if (!isExpanded) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat(
                          icon: Icons.timelapse,
                          value: '${totalHours.toStringAsFixed(1)}h',
                          color: Colors.green,
                        ),
                        _buildMiniStat(
                          icon: Icons.attach_money,
                          value:
                              '${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Expandable Reports List
          if (isExpanded)
            Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  const Divider(height: 1),
                  ...reports.asMap().entries.map((entry) {
                    final index = entry.key;
                    final report = entry.value;
                    return Column(
                      children: [
                        _buildReportItem(report),
                        if (index < reports.length - 1)
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: Colors.grey.shade300,
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildReportItem(Map<String, dynamic> reportData) {
    final reportId = reportData['reportId'] ?? '';
    final month = reportData['month'] ?? '';
    final status = reportData['status'] ?? 'draft';
    final totalHours = (reportData['totalHours'] ?? 0.0).toDouble();
    final totalAmount = (reportData['totalAmount'] ?? 0.0).toDouble();
    final timesheetCount = reportData['timesheetCount'] ?? 0;

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

    final paymentStatus =
        reportData['paymentStatus'] as String? ?? 'not_paid';
    final (Color payColor, String payLabel, IconData payIcon) =
        switch (paymentStatus) {
      'paid' => (Colors.green, 'PAID', Icons.check_circle_outline),
      'review' => (Colors.orange, 'IN REVIEW', Icons.pending_outlined),
      _ => (Colors.grey, 'UNPAID', Icons.money_off_outlined),
    };

    final monthDisplay = _formatReportPeriod(reportData);

    return InkWell(
      onTap: () {
        context.push(
          '/admin/student-reports/$reportId?month=$month&monthDisplay=${Uri.encodeComponent(monthDisplay)}',
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_month,
                color: Colors.orange.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthDisplay,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isTight = constraints.maxWidth < 200;
                      final mutedStyle =
                          TextStyle(fontSize: 12, color: Colors.grey[600]);
                      if (isTight) {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text('$timesheetCount entries', style: mutedStyle),
                            Text('${totalHours.toStringAsFixed(1)}h',
                                style: mutedStyle),
                            Text(
                              '${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                              style: mutedStyle.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Text(
                            '$timesheetCount entries',
                            style: mutedStyle,
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(width: 8),
                          Text(
                            '${totalHours.toStringAsFixed(1)}h',
                            style: mutedStyle,
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(width: 8),
                          Text(
                            '${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                            style: mutedStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: payColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: payColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(payIcon, size: 11, color: payColor),
                      const SizedBox(width: 3),
                      Text(
                        payLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: payColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Report'),
                      content: const Text(
                        'Are you sure you want to delete this report? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('student_monthly_reports')
                          .doc(reportId)
                          .delete();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report deleted'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadReports();
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
                } else if (value == 'payment_paid' ||
                    value == 'payment_not_paid' ||
                    value == 'payment_review') {
                  final newStatus = value.replaceFirst('payment_', '');
                  try {
                    await FirebaseFirestore.instance
                        .collection('student_monthly_reports')
                        .doc(reportId)
                        .update({'paymentStatus': newStatus});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Payment status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadReports();
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
                  }
                }
              },
              itemBuilder: (_) {
                final currentPayment =
                    reportData['paymentStatus'] as String? ?? 'not_paid';
                return [
                  const PopupMenuItem<String>(
                    enabled: false,
                    height: 28,
                    child: Text('Payment Status',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                  ),
                  PopupMenuItem<String>(
                    value: 'payment_paid',
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          size: 16,
                          color: currentPayment == 'paid'
                              ? Colors.green
                              : Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Paid'),
                      if (currentPayment == 'paid') ...[
                        const Spacer(),
                        const Icon(Icons.done, size: 14, color: Colors.green),
                      ],
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'payment_review',
                    child: Row(children: [
                      Icon(Icons.pending_outlined,
                          size: 16,
                          color: currentPayment == 'review'
                              ? Colors.orange
                              : Colors.grey),
                      const SizedBox(width: 8),
                      const Text('In Review'),
                      if (currentPayment == 'review') ...[
                        const Spacer(),
                        const Icon(Icons.done, size: 14, color: Colors.orange),
                      ],
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'payment_not_paid',
                    child: Row(children: [
                      Icon(Icons.money_off_outlined,
                          size: 16,
                          color: currentPayment == 'not_paid'
                              ? Colors.red
                              : Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Not Paid'),
                      if (currentPayment == 'not_paid') ...[
                        const Spacer(),
                        const Icon(Icons.done, size: 14, color: Colors.red),
                      ],
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ];
              },
              icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text(
                  'Filter Reports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final studentField = _isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedStudentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Student',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Students'),
                          ),
                          ..._students.map(
                            (student) => DropdownMenuItem(
                              value: student['id'].toString(),
                              child: Text(student['name']),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStudentId = value;
                          });
                          _loadReports();
                        },
                      );

                final statusField = DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.flag),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Status'),
                    ),
                    ..._statusOptions.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _loadReports();
                  },
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      studentField,
                      const SizedBox(height: 12),
                      statusField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: studentField),
                    const SizedBox(width: 16),
                    Expanded(child: statusField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String studentName, String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: Colors.grey.shade200,
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
          Icon(Icons.article_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No reports found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
