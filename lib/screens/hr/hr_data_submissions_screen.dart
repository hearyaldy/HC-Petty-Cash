import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/staff.dart';
import '../../models/enums.dart';
import '../../services/staff_service.dart';
import '../../utils/responsive_helper.dart';

class HrDataSubmissionsScreen extends StatefulWidget {
  const HrDataSubmissionsScreen({super.key});

  @override
  State<HrDataSubmissionsScreen> createState() =>
      _HrDataSubmissionsScreenState();
}

class _HrDataSubmissionsScreenState extends State<HrDataSubmissionsScreen> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _submissions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('hr_data_submissions')
          .orderBy('submittedAt', descending: true)
          .get(const GetOptions(source: Source.server));

      if (mounted) {
        setState(() {
          _submissions = snapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading HR submissions: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            child: Padding(
              padding: ResponsiveHelper.getScreenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  const SizedBox(height: 16),
                  _buildSubmissionsList(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top action bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Dashboard',
                onPressed: () => context.go('/admin-hub'),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: _loadSubmissions,
                  ),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/admin-hub'),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          // Content row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HR Data Submissions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review and manage submitted HR data',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
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

  Widget _buildSubmissionsList(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState(_error!);
    }

    if (_submissions.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate stats
    final pendingCount = _submissions.where((doc) {
      final data = doc.data();
      return data['status'] == 'pending' || data['status'] == null;
    }).length;
    final processedCount = _submissions.where((doc) {
      final data = doc.data();
      return data['status'] == 'processed';
    }).length;

    return Column(
      children: [
        // Stats Row
        _buildStatsRow(_submissions.length, pendingCount, processedCount),
        const SizedBox(height: 24),
        // Submissions List
        ..._submissions.map((submission) {
          final data = submission.data();
          return _buildSubmissionCard(context, data, submission.id);
        }),
      ],
    );
  }

  Widget _buildStatsRow(int total, int pending, int processed) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Submissions',
            total.toString(),
            Icons.folder,
            [Colors.blue.shade400, Colors.blue.shade600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            pending.toString(),
            Icons.pending_actions,
            [Colors.orange.shade400, Colors.orange.shade600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Processed',
            processed.toString(),
            Icons.check_circle,
            [Colors.green.shade400, Colors.green.shade600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    List<Color> gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading submissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 48,
              color: Colors.indigo.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No HR data submissions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submitted HR data will appear here',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(
    BuildContext context,
    Map<String, dynamic> data,
    String submissionId,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade300, Colors.indigo.shade500],
                  ),
                ),
                child: Center(
                  child: Text(
                    (data['fullName'] ?? 'Unknown')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                      data['fullName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            data['employeeId'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['position'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
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
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Submitted: ${_formatDate(data['submittedAt'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                _buildStatusChip(data['status'] ?? 'pending'),
              ],
            ),
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information
                  _buildSectionCard(
                    context,
                    title: 'Personal Information',
                    icon: Icons.person,
                    gradient: [Colors.blue.shade400, Colors.blue.shade600],
                    children: [
                      _buildInfoRow('Full Name', data['fullName']),
                      _buildInfoRow('Employee ID', data['employeeId']),
                      _buildInfoRow('Gender', _formatGender(data['gender'])),
                      _buildInfoRow(
                        'Date of Birth',
                        data['dateOfBirth'] != null
                            ? _formatDate(data['dateOfBirth'])
                            : 'N/A',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contact Information
                  _buildSectionCard(
                    context,
                    title: 'Contact Information',
                    icon: Icons.contact_phone,
                    gradient: [Colors.green.shade400, Colors.green.shade600],
                    children: [
                      _buildInfoRow('Email', data['email']),
                      _buildInfoRow('Phone', data['phone']),
                      _buildInfoRow(
                        'Emergency Contact',
                        data['emergencyContactName'],
                      ),
                      _buildInfoRow(
                        'Emergency Phone',
                        data['emergencyContactPhone'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Employment Information
                  _buildSectionCard(
                    context,
                    title: 'Employment Information',
                    icon: Icons.work,
                    gradient: [Colors.purple.shade400, Colors.purple.shade600],
                    children: [
                      _buildInfoRow('Department', data['department']),
                      _buildInfoRow('Position', data['position']),
                      _buildInfoRow(
                        'Employment Type',
                        _formatEmploymentType(data['employmentType']),
                      ),
                      _buildInfoRow(
                        'Employment Status',
                        _formatEmploymentStatus(data['employmentStatus']),
                      ),
                      _buildInfoRow(
                        'Start Date',
                        data['startDate'] != null
                            ? _formatDate(data['startDate'])
                            : 'N/A',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bank Information
                  _buildSectionCard(
                    context,
                    title: 'Bank Information',
                    icon: Icons.account_balance,
                    gradient: [Colors.teal.shade400, Colors.teal.shade600],
                    children: [
                      _buildInfoRow('Bank Name', data['bankName']),
                      _buildInfoRow('Account Number', data['bankAccount']),
                      _buildInfoRow('Tax ID', data['taxId']),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Monthly Allowances
                  _buildSectionCard(
                    context,
                    title: 'Monthly Allowances',
                    icon: Icons.account_balance_wallet,
                    gradient: [Colors.orange.shade400, Colors.orange.shade600],
                    children: [
                      _buildInfoRow(
                        'Phone',
                        _formatCurrency(data['phoneAllowance']),
                      ),
                      _buildInfoRow(
                        'Education',
                        _formatCurrency(data['educationAllowance']),
                      ),
                      _buildInfoRow(
                        'Housing',
                        _formatCurrency(data['houseAllowance']),
                      ),
                      _buildInfoRow(
                        'Equipment',
                        _formatCurrency(data['equipmentAllowance']),
                      ),
                      _buildInfoRow(
                        'Monthly Allowances',
                        _formatCurrency(data['totalAllowances']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {},
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.visibility,
                                      color: Colors.grey.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'View Details',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _convertToStaffRecord(
                                context,
                                data,
                                submissionId,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add as Staff',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradient[0].withValues(alpha: 0.1), Colors.transparent],
              ),
              border: Border(left: BorderSide(color: gradient[0], width: 3)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: gradient[0],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Rejected';
        break;
      case 'processed':
        color = Colors.blue;
        icon = Icons.verified;
        label = 'Processed';
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  String _formatGender(String? gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return 'N/A';
    }
  }

  String _formatEmploymentType(String? type) {
    switch (type) {
      case 'full_time':
        return 'Full Time';
      case 'part_time':
        return 'Part Time';
      case 'contract':
        return 'Contract';
      case 'intern':
        return 'Intern';
      case 'consultant':
        return 'Consultant';
      default:
        return 'N/A';
    }
  }

  String _formatEmploymentStatus(String? status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'on_leave':
        return 'On Leave';
      case 'resigned':
        return 'Resigned';
      case 'terminated':
        return 'Terminated';
      case 'retired':
        return 'Retired';
      default:
        return 'N/A';
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'THB 0.00';
    final value = (amount is num) ? amount.toDouble() : 0.0;
    return 'THB ${NumberFormat('#,##0.00', 'en_US').format(value)}';
  }

  Future<void> _convertToStaffRecord(
    BuildContext context,
    Map<String, dynamic> data,
    String submissionId,
  ) async {
    try {
      // Create a staff record from the HR submission data
      // IMPORTANT: Pass the userId (Firebase Auth UID) to link staff record to the user
      final staff = Staff.create(
        userId: data['submittedBy'] as String?, // Link to Firebase Auth UID
        employeeId:
            data['employeeId'] ??
            'EMP-${DateTime.now().millisecondsSinceEpoch}',
        fullName: data['fullName'] ?? '',
        email: data['email'] ?? '',
        phoneNumber: data['phone'] ?? '',
        emergencyContactName: data['emergencyContactName'] ?? '',
        emergencyContactPhone: data['emergencyContactPhone'] ?? '',
        dateOfBirth: data['dateOfBirth'] != null
            ? (data['dateOfBirth'] as Timestamp).toDate()
            : null,
        gender: _getGenderFromString(data['gender']) ?? Gender.preferNotToSay,
        department: data['department'] ?? '',
        position: data['position'] ?? '',
        role: UserRole.requester, // Default role, can be updated later
        employmentType:
            _getEmploymentTypeFromString(data['employmentType']) ??
            EmploymentType.fullTime,
        employmentStatus:
            _getEmploymentStatusFromString(data['employmentStatus']) ??
            EmploymentStatus.active,
        dateOfJoining:
            (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        dateOfLeaving: data['endDate'] != null
            ? (data['endDate'] as Timestamp).toDate()
            : null,
        bankAccountNumber: data['bankAccount'] ?? '',
        bankName: data['bankName'] ?? '',
        taxId: data['taxId'] ?? '',
        monthlySalary: (data['baseSalary'] ?? data['salary'] ?? 0.0) as double?,
        allowances: (data['totalAllowances'] ?? 0.0) as double?,
        titheAmount: (data['titheAmount'] ?? 0.0) as double?,
        socialSecurityAmount: (data['socialSecurityAmount'] ?? 0.0) as double?,
        providentFundAmount: (data['providentFundAmount'] ?? 0.0) as double?,
        approvalLimit: (data['approvalLimit'] ?? 0.0) as double?,
        hrSubmissionId: submissionId, // Link back to original HR submission
        createdAt: DateTime.now(),
        notes: data['notes'] ?? '',
      );

      // Save to staff collection
      final staffService = StaffService();
      final staffId = await staffService.createStaff(staff);

      // Update the submission status to indicate it's been processed
      await FirebaseFirestore.instance
          .collection('hr_data_submissions')
          .doc(submissionId)
          .update({
            'status': 'processed',
            'processedAt': Timestamp.now(),
            'convertedToStaffId': staffId,
          });

      // Reload submissions to reflect changes
      await _loadSubmissions();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Staff record created successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error creating staff record: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Gender? _getGenderFromString(String? gender) {
    if (gender == null) return null;
    switch (gender) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      case 'prefer_not_to_say':
        return Gender.preferNotToSay;
      default:
        return null;
    }
  }

  EmploymentType _getEmploymentTypeFromString(String? type) {
    if (type == null) return EmploymentType.fullTime;
    switch (type) {
      case 'full_time':
        return EmploymentType.fullTime;
      case 'part_time':
        return EmploymentType.partTime;
      case 'contract':
        return EmploymentType.contract;
      case 'intern':
        return EmploymentType.intern;
      case 'consultant':
        return EmploymentType.consultant;
      default:
        return EmploymentType.fullTime;
    }
  }

  EmploymentStatus _getEmploymentStatusFromString(String? status) {
    if (status == null) return EmploymentStatus.active;
    switch (status) {
      case 'active':
        return EmploymentStatus.active;
      case 'on_leave':
        return EmploymentStatus.onLeave;
      case 'resigned':
        return EmploymentStatus.resigned;
      case 'terminated':
        return EmploymentStatus.terminated;
      case 'retired':
        return EmploymentStatus.retired;
      default:
        return EmploymentStatus.active;
    }
  }
}
