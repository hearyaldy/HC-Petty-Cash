import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/student_timesheet.dart';
import '../../utils/responsive_helper.dart';

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final Color lightColor;

  _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.lightColor,
  });
}

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _isLoading = true;
  StudentProfile? _profile;
  int _totalTimesheets = 0;
  double _totalHours = 0;
  double _totalEarnings = 0;
  int _pendingReports = 0;
  int _approvedReports = 0;
  List<StudentTimesheet> _recentTimesheets = [];
  List<Map<String, dynamic>> _monthlyReports = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id ?? '';

    try {
      // Load student profile
      final profileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(userId)
          .get();

      if (profileDoc.exists) {
        _profile = StudentProfile.fromFirestore(profileDoc);
      }

      // Load all timesheets
      final timesheetsQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('studentId', isEqualTo: userId)
          .get();

      final allTimesheets = timesheetsQuery.docs
          .map((doc) => StudentTimesheet.fromFirestore(doc))
          .toList();

      // Calculate statistics
      _totalTimesheets = allTimesheets.length;
      _totalHours = allTimesheets.fold(0.0, (sum, ts) => sum + ts.totalHours);
      _totalEarnings = allTimesheets.fold(
        0.0,
        (sum, ts) => sum + ts.totalAmount,
      );

      // Get recent timesheets (last 5)
      allTimesheets.sort((a, b) => b.date.compareTo(a.date));
      _recentTimesheets = allTimesheets.take(5).toList();

      // Load monthly reports
      final reportsQuery = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('studentId', isEqualTo: userId)
          .orderBy('month', descending: true)
          .get();

      _monthlyReports = reportsQuery.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      _pendingReports = _monthlyReports
          .where((report) => (report['status'] ?? '') == 'submitted')
          .length;

      _approvedReports = _monthlyReports
          .where((report) => (report['status'] ?? '') == 'approved')
          .length;

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showReportSelectionDialog(BuildContext context) {
    if (_monthlyReports.isEmpty) {
      // Show message to create a report first
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
                child: const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text('No Reports Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You need to create a monthly report before you can log hours.',
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
                        'Tap "Create New Report" to get started',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.go('/student-report/new');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create New Report'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
              child: const Icon(
                Icons.access_time,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Log Hours'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a report to log your hours to:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ..._monthlyReports.map((report) {
                  final status = report['status'] ?? 'draft';
                  final statusColor = status == 'approved'
                      ? Colors.green
                      : status == 'submitted'
                      ? Colors.orange
                      : status == 'paid'
                      ? Colors.blue
                      : Colors.grey;

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.calendar_month,
                      color: Colors.orange.shade600,
                    ),
                    title: Text(
                      report['monthDisplay'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${report['timesheetCount'] ?? 0} timesheets • ${(report['totalHours'] ?? 0.0).toStringAsFixed(1)} hrs',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      context.push(
                        '/student-monthly-report-detail',
                        extra: {
                          'reportId': report['id'],
                          'month': report['month'],
                          'monthDisplay': report['monthDisplay'],
                        },
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'timesheets') {
                context.go('/student-report');
              } else if (value == 'settings') {
                context.go('/settings');
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'timesheets',
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 20),
                    SizedBox(width: 12),
                    Text('My Timesheets'),
                  ],
                ),
              ),
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
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ResponsiveContainer(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildMonthlyReports(),
                      const SizedBox(height: 24),
                      _buildRecentTimesheets(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.currentUser?.name ?? 'Student';

    return Container(
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
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
                  '฿${_profile?.hourlyRate.toStringAsFixed(2) ?? '0.00'}/hr',
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
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatData(
        title: 'Total Hours',
        value: _totalHours.toStringAsFixed(1),
        icon: Icons.access_time,
        gradient: [Colors.blue.shade400, Colors.blue.shade600],
        lightColor: Colors.blue.shade50,
      ),
      _StatData(
        title: 'Total Earnings',
        value: '฿${_totalEarnings.toStringAsFixed(2)}',
        icon: Icons.attach_money,
        gradient: [Colors.green.shade400, Colors.green.shade600],
        lightColor: Colors.green.shade50,
      ),
      _StatData(
        title: 'Pending Reports',
        value: _pendingReports.toString(),
        icon: Icons.pending,
        gradient: [Colors.orange.shade400, Colors.orange.shade600],
        lightColor: Colors.orange.shade50,
      ),
      _StatData(
        title: 'Approved Reports',
        value: _approvedReports.toString(),
        icon: Icons.check_circle,
        gradient: [Colors.teal.shade400, Colors.teal.shade600],
        lightColor: Colors.teal.shade50,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          itemBuilder: (context, index) => _buildModernStatCard(stats[index]),
        );
      },
    );
  }

  Widget _buildModernStatCard(_StatData stat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: stat.gradient.map((c) => c.withOpacity(0.1)).toList(),
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: stat.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(stat.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stat.value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: stat.gradient[1],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernActionButton(
                'Log Hours',
                Icons.add_circle,
                [Colors.orange.shade400, Colors.orange.shade600],
                () => _showReportSelectionDialog(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernActionButton(
                'Create Report',
                Icons.description,
                [Colors.blue.shade400, Colors.blue.shade600],
                () => context.push('/student-report/new'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernActionButton(
    String label,
    IconData icon,
    List<Color> gradient,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient[1].withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Monthly Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.go('/student-report'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_monthlyReports.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No monthly reports yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submit your timesheets to create a report',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ..._monthlyReports.take(5).map((report) {
            final month = report['month'] ?? '';
            final status = report['status'] ?? 'draft';
            final totalHours = (report['totalHours'] ?? 0.0).toDouble();
            final totalAmount = (report['totalAmount'] ?? 0.0).toDouble();

            // Format month display
            String monthDisplay = month;
            try {
              final parts = month.split('-');
              if (parts.length == 2) {
                final monthDate = DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );
                monthDisplay = DateFormat('MMMM yyyy').format(monthDate);
              }
            } catch (e) {
              // Keep original if parsing fails
            }

            Color statusColor;
            IconData statusIcon;
            switch (status) {
              case 'approved':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'submitted':
                statusColor = Colors.orange;
                statusIcon = Icons.pending;
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                break;
              default:
                statusColor = Colors.grey;
                statusIcon = Icons.edit_document;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  // Navigate to report detail
                  context.push(
                    '/student-monthly-report-detail',
                    extra: {
                      'reportId': report['id'],
                      'month': month,
                      'monthDisplay': monthDisplay,
                    },
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.article,
                        color: Colors.orange.shade600,
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
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${totalHours.toStringAsFixed(1)}h • ฿${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editMonthlyReport(report);
                        } else if (value == 'delete') {
                          _deleteMonthlyReport(report['id'], monthDisplay);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecentTimesheets() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Time Logs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/student-report'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(height: 32),
            if (_recentTimesheets.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No time logs yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log your first hours to get started',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTimesheets.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final timesheet = _recentTimesheets[index];
                  return _buildTimeLogItem(timesheet);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeLogItem(StudentTimesheet timesheet) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    Color statusColor;
    IconData statusIcon;
    switch (timesheet.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'submitted':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
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
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timesheet.date != null
                        ? dateFormat.format(timesheet.date)
                        : 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${timeFormat.format(timesheet.startTime)} - ${timeFormat.format(timesheet.endTime)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (timesheet.notes != null &&
                      timesheet.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timesheet.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${timesheet.totalHours.toStringAsFixed(2)} h',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '฿${timesheet.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            timesheet.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editTimesheet(timesheet);
                        } else if (value == 'delete') {
                          _deleteTimesheet(
                            timesheet.id,
                            dateFormat.format(timesheet.date),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
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
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMonthlyReport(
    String reportId,
    String monthDisplay,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete the report for $monthDisplay?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('student_monthly_reports')
            .doc(reportId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully')),
          );
          _loadDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting report: $e')));
        }
      }
    }
  }

  void _editMonthlyReport(Map<String, dynamic> report) {
    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => _EditMonthlyReportDialog(
        report: report,
        onSaved: () {
          _loadDashboardData();
        },
      ),
    );
  }

  Future<void> _deleteTimesheet(String timesheetId, String date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Time Entry'),
        content: Text(
          'Are you sure you want to delete the time entry for $date?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('student_timesheets')
            .doc(timesheetId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Time entry deleted successfully')),
          );
          _loadDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting time entry: $e')),
          );
        }
      }
    }
  }

  void _editTimesheet(StudentTimesheet timesheet) {
    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => _EditTimesheetDialog(
        timesheet: timesheet,
        onSaved: () {
          _loadDashboardData();
        },
      ),
    );
  }

  void _handleLogout() async {
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
}

class _EditTimesheetDialog extends StatefulWidget {
  final StudentTimesheet timesheet;
  final VoidCallback onSaved;

  const _EditTimesheetDialog({required this.timesheet, required this.onSaved});

  @override
  State<_EditTimesheetDialog> createState() => _EditTimesheetDialogState();
}

class _EditTimesheetDialogState extends State<_EditTimesheetDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.timesheet.date;
    _startTime = TimeOfDay.fromDateTime(widget.timesheet.startTime);
    _endTime = TimeOfDay.fromDateTime(widget.timesheet.endTime);
    _notesController = TextEditingController(
      text: widget.timesheet.notes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      // Combine date with time
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Calculate hours
      final duration = endDateTime.difference(startDateTime);
      final hours = duration.inMinutes / 60.0;

      if (hours <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End time must be after start time')),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      // Get hourly rate
      final profileDoc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(widget.timesheet.studentId)
          .get();

      final hourlyRate = profileDoc.exists
          ? (profileDoc.data()?['hourlyRate'] ?? 0.0).toDouble()
          : 0.0;

      final totalAmount = hours * hourlyRate;

      // Update timesheet
      await FirebaseFirestore.instance
          .collection('student_timesheets')
          .doc(widget.timesheet.id)
          .update({
            'date': Timestamp.fromDate(_selectedDate),
            'startTime': Timestamp.fromDate(startDateTime),
            'endTime': Timestamp.fromDate(endDateTime),
            'totalHours': hours,
            'totalAmount': totalAmount,
            'notes': _notesController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time entry updated successfully')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating time entry: $e')),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Time Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              onTap: _selectDate,
            ),
            const SizedBox(height: 8),

            // Start time picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Start Time'),
              subtitle: Text(_startTime.format(context)),
              onTap: () => _selectTime(true),
            ),
            const SizedBox(height: 8),

            // End time picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('End Time'),
              subtitle: Text(_endTime.format(context)),
              onTap: () => _selectTime(false),
            ),
            const SizedBox(height: 16),

            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveChanges,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _EditMonthlyReportDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onSaved;

  const _EditMonthlyReportDialog({required this.report, required this.onSaved});

  @override
  State<_EditMonthlyReportDialog> createState() =>
      _EditMonthlyReportDialogState();
}

class _EditMonthlyReportDialogState extends State<_EditMonthlyReportDialog> {
  late TextEditingController _monthController;
  late TextEditingController _statusController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _monthController = TextEditingController(
      text: widget.report['month'] ?? '',
    );
    _statusController = TextEditingController(
      text: widget.report['status'] ?? 'draft',
    );
  }

  @override
  void dispose() {
    _monthController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final month = _monthController.text.trim();
      final status = _statusController.text.trim();

      if (month.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Month cannot be empty')),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      // Validate month format (YYYY-MM)
      final monthRegex = RegExp(r'^\d{4}-\d{2}$');
      if (!monthRegex.hasMatch(month)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Month must be in format YYYY-MM (e.g., 2024-01)'),
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      // Update monthly report
      await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .doc(widget.report['id'])
          .update({
            'month': month,
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly report updated successfully')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating monthly report: $e')),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Monthly Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month field
            TextField(
              controller: _monthController,
              decoration: const InputDecoration(
                labelText: 'Month (YYYY-MM)',
                hintText: '2024-01',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Status dropdown
            DropdownButtonFormField<String>(
              value: _statusController.text,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _statusController.text = value;
                }
              },
            ),
            const SizedBox(height: 16),

            // Info text
            Text(
              'Note: Changing the month will not update the associated time entries. Total hours and amount are calculated from time entries.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveChanges,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
