import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
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

  // Store reports in state to avoid StreamBuilder issues on web
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reports = [];
  bool _isLoadingReports = true;
  String? _reportsError;

  final List<String> _statusOptions = [
    'draft',
    'submitted',
    'approved',
    'rejected',
  ];

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

      // Remove duplicates by creating a map with unique IDs, then converting back to list
      final uniqueStudentsMap = <String, Map<String, dynamic>>{};
      for (final doc in studentsQuery.docs) {
        final data = doc.data();
        final id = doc.id;
        uniqueStudentsMap[id] = {
          'id': id,
          'name': data['studentName'] ?? 'Unknown',
          'photoUrl': data['photoUrl'] as String?,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Reports Management'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: ResponsiveContainer(
        child: Column(
          children: [
            _buildFilterBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildReportsList()),
          ],
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
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final reportDoc = _reports[index];
        final reportData = reportDoc.data();
        return _buildReportCard(reportDoc.id, reportData);
      },
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
            Row(
              children: [
                Expanded(
                  child: _isLoadingStudents
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: _selectedStudentId,
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
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
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
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String reportId, Map<String, dynamic> reportData) {
    final studentName = reportData['studentName'] ?? 'Unknown';
    final studentId = reportData['studentId'] ?? '';
    final photoUrl =
        _students.firstWhere(
              (s) => s['id'] == studentId,
              orElse: () => const {'photoUrl': null},
            )['photoUrl']
            as String?;
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

    // Format month display (YYYY-MM to Month Year)
    DateTime? monthDate;
    String monthDisplay = month;
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        monthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        monthDisplay = DateFormat('MMMM yyyy').format(monthDate);
      }
    } catch (e) {
      // Keep original month string if parsing fails
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          context.push(
            '/admin/student-reports/$reportId?month=$month&monthDisplay=${Uri.encodeComponent(monthDisplay)}',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
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
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      monthDisplay,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
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
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.access_time,
                    label: 'Entries',
                    value: timesheetCount.toString(),
                    color: Colors.blue,
                  ),
                  _buildStatItem(
                    icon: Icons.timelapse,
                    label: 'Hours',
                    value: '${totalHours.toStringAsFixed(1)}h',
                    color: Colors.green,
                  ),
                  _buildStatItem(
                    icon: Icons.attach_money,
                    label: 'Amount',
                    value:
                        '${AppConstants.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                    color: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
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
