import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../models/staff.dart';
import '../../models/salary_benefits.dart';
import '../../services/staff_service.dart';
import '../../services/salary_benefits_service.dart';

class MyHrDataScreen extends StatefulWidget {
  const MyHrDataScreen({super.key});

  @override
  State<MyHrDataScreen> createState() => _MyHrDataScreenState();
}

class _MyHrDataScreenState extends State<MyHrDataScreen> {
  final StaffService _staffService = StaffService();
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();
  Staff? _staffRecord;
  SalaryBenefits? _salaryBenefits;
  bool _isLoadingSalary = true;

  @override
  void initState() {
    super.initState();
    _loadStaffAndSalaryData();
  }

  Future<void> _loadStaffAndSalaryData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    try {
      // Find staff record by userId first, then by email
      final staffList = await _staffService.getAllStaff().first;

      // Try to find by userId first
      Staff? staff;
      try {
        staff = staffList.firstWhere((s) => s.userId == user.id);
        debugPrint('Debug: Found staff by userId: ${staff.fullName}');
      } catch (_) {
        // Not found by userId, try by email
        try {
          staff = staffList.firstWhere(
            (s) => s.email.toLowerCase() == user.email.toLowerCase(),
          );
          debugPrint('Debug: Found staff by email: ${staff.fullName}');
        } catch (_) {
          // Not found by email either, try to find via HR submission's convertedToStaffId
          debugPrint(
            'Debug: Staff not found by userId or email, checking HR submission...',
          );
          debugPrint('Debug: Available staff records:');
          for (final s in staffList) {
            debugPrint(
              '  - Staff ID: ${s.id}, userId: ${s.userId}, email: ${s.email}, name: ${s.fullName}',
            );
          }

          try {
            final hrSubmission = await FirebaseFirestore.instance
                .collection('hr_data_submissions')
                .where('submittedBy', isEqualTo: user.id)
                .limit(1)
                .get();

            if (hrSubmission.docs.isNotEmpty) {
              final hrData = hrSubmission.docs.first.data();
              final convertedToStaffId =
                  hrData['convertedToStaffId'] as String?;
              debugPrint(
                'Debug: HR submission convertedToStaffId: $convertedToStaffId',
              );

              if (convertedToStaffId != null && convertedToStaffId.isNotEmpty) {
                try {
                  staff = staffList.firstWhere(
                    (s) => s.id == convertedToStaffId,
                  );
                  debugPrint(
                    'Debug: Found staff by convertedToStaffId: ${staff.fullName}',
                  );
                } catch (_) {
                  debugPrint(
                    'Debug: convertedToStaffId ($convertedToStaffId) does not match any staff ID',
                  );
                }
              }
            }
          } catch (e) {
            debugPrint('Debug: Could not find staff via HR submission: $e');
          }

          if (staff == null) {
            debugPrint(
              'Debug: Staff not found by userId (${user.id}), email (${user.email}), or HR submission link',
            );
          }
        }
      }

      _staffRecord = staff;

      // Load salary benefits for this staff (uses stream for real-time updates)
      if (_staffRecord != null) {
        _salaryBenefitsService
            .getCurrentOrLatestSalaryBenefitsForStaff(_staffRecord!.id)
            .listen((salaryBenefits) {
              if (mounted) {
                setState(() {
                  _salaryBenefits = salaryBenefits;
                  _isLoadingSalary = false;
                });
              }
            });
      } else {
        setState(() => _isLoadingSalary = false);
      }
    } catch (e) {
      debugPrint('Debug: Could not load staff/salary data: $e');
      if (mounted) {
        setState(() => _isLoadingSalary = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My HR Data')),
        body: const Center(child: Text('Please login to view your data')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: ResponsiveHelper.isDesktop(context) ? 1 : 0,
        title: const Text('My HR Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoadingSalary = true;
              });
              _loadStaffAndSalaryData();
            },
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hr_data_submissions')
            .where('submittedBy', isEqualTo: user.id)
            .snapshots(),
        builder: (context, snapshot) {
          print(
            'MyHrDataScreen: Connection state = ${snapshot.connectionState}',
          ); // Debug
          if (snapshot.hasError) {
            print('MyHrDataScreen: Error = ${snapshot.error}'); // Debug
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            print('MyHrDataScreen: Loading...'); // Debug
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('MyHrDataScreen: No data found for user ${user.id}'); // Debug
            print(
              'MyHrDataScreen: Query tried to find documents where submittedBy = ${user.id}',
            ); // Debug
            return _buildNoDataView(context);
          }

          // Sort documents by submittedAt in descending order and get the first one
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['submittedAt'] as Timestamp?;
            final bTimestamp = bData['submittedAt'] as Timestamp?;

            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;

            return bTimestamp.compareTo(aTimestamp); // Descending order
          });

          print('MyHrDataScreen: Found ${docs.length} documents'); // Debug
          final doc = docs.first;
          print('MyHrDataScreen: First document ID = ${doc.id}'); // Debug
          final data = doc.data() as Map<String, dynamic>;
          print('MyHrDataScreen: Document data keys = ${data.keys}'); // Debug

          return _buildDataView(context, data, doc.id);
        },
      ),
    );
  }

  Widget _buildNoDataView(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: ResponsiveHelper.getScreenPadding(context),
        child: Column(
          children: [
            // No HR submission notice
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 60,
                      color: Colors.orange.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No HR Submission Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You haven\'t submitted your HR information yet.\nPlease submit your data to complete your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/hr/data-submission'),
                    icon: const Icon(Icons.add),
                    label: const Text('Submit HR Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Admin-managed Salary & Benefits Section (Real-time from salary_benefits collection)
            // This shows even if user hasn't submitted HR data
            _buildAdminManagedSalarySection(currencyFormat),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDataView(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: ResponsiveHelper.getScreenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with actions
            _buildHeader(context, data, docId),
            const SizedBox(height: 24),

            // Status Badge
            _buildStatusBadge(data['status'] ?? 'pending'),
            const SizedBox(height: 24),

            // Personal & Contact Section (Combined like Admin)
            _buildSectionCard(
              title: 'Personal & Contact',
              icon: Icons.person,
              iconGradient: [Colors.indigo.shade400, Colors.indigo.shade600],
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Basic Information'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Employee ID',
                            data['employeeId'] ?? 'N/A',
                            Icons.badge,
                          ),
                          _buildCompactInfoRow(
                            'Full Name',
                            data['fullName'] ?? 'N/A',
                            Icons.person,
                          ),
                          _buildCompactInfoRow(
                            'Email',
                            data['email'] ?? 'N/A',
                            Icons.email,
                          ),
                          if (data['dateOfBirth'] != null)
                            _buildCompactInfoRow(
                              'Date of Birth',
                              dateFormat.format(
                                (data['dateOfBirth'] as Timestamp).toDate(),
                              ),
                              Icons.cake,
                            ),
                          _buildCompactInfoRow(
                            'Gender',
                            _formatGender(data['gender']),
                            Icons.wc,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Contact Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Contact Details'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Phone',
                            data['phone'] ?? 'N/A',
                            Icons.phone,
                          ),
                          if (data['address'] != null &&
                              (data['address'] as String).isNotEmpty)
                            _buildCompactInfoRow(
                              'Address',
                              data['address'],
                              Icons.location_on,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ID & Location Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('ID & Location'),
                          const SizedBox(height: 8),
                          if (data['nationalIdNumber'] != null &&
                              (data['nationalIdNumber'] as String).isNotEmpty)
                            _buildCompactInfoRow(
                              'National ID',
                              data['nationalIdNumber'],
                              Icons.badge,
                            ),
                          if (data['passportNumber'] != null &&
                              (data['passportNumber'] as String).isNotEmpty)
                            _buildCompactInfoRow(
                              'Passport',
                              data['passportNumber'],
                              Icons.card_travel,
                            ),
                          if (data['country'] != null &&
                              (data['country'] as String).isNotEmpty)
                            _buildCompactInfoRow(
                              'Country',
                              data['country'],
                              Icons.public,
                            ),
                          if (data['provinceState'] != null &&
                              (data['provinceState'] as String).isNotEmpty)
                            _buildCompactInfoRow(
                              'Province/State',
                              data['provinceState'],
                              Icons.location_city,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Emergency Contact
                if (data['emergencyContactName'] != null &&
                    (data['emergencyContactName'] as String).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emergency,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Contact',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data['emergencyContactName']}${data['emergencyContactPhone'] != null ? ' - ${data['emergencyContactPhone']}' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Employment Details Section
            _buildSectionCard(
              title: 'Employment Details',
              icon: Icons.work,
              iconGradient: [Colors.purple.shade400, Colors.purple.shade600],
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Position Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Position'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Department',
                            data['department'] ?? 'N/A',
                            Icons.business,
                          ),
                          _buildCompactInfoRow(
                            'Position',
                            data['position'] ?? 'N/A',
                            Icons.work,
                          ),
                          _buildCompactInfoRow(
                            'Employment Type',
                            _formatEmploymentType(data['employmentType']),
                            Icons.badge,
                          ),
                          _buildCompactInfoRow(
                            'Status',
                            _formatEmploymentStatus(data['employmentStatus']),
                            Icons.verified_user,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dates Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Employment Period'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Start Date',
                            data['startDate'] != null
                                ? dateFormat.format(
                                    (data['startDate'] as Timestamp).toDate(),
                                  )
                                : 'N/A',
                            Icons.calendar_today,
                          ),
                          if (data['endDate'] != null)
                            _buildCompactInfoRow(
                              'End Date',
                              dateFormat.format(
                                (data['endDate'] as Timestamp).toDate(),
                              ),
                              Icons.event,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Education Section
            _buildSectionCard(
              title: 'Education',
              icon: Icons.school,
              iconGradient: [Colors.indigo.shade400, Colors.indigo.shade600],
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Academic Background'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Education Level',
                            _formatEducationLevel(data['educationLevel']),
                            Icons.school,
                          ),
                          _buildCompactInfoRow(
                            'Degree',
                            data['highestDegree'] ?? 'N/A',
                            Icons.workspace_premium,
                          ),
                          _buildCompactInfoRow(
                            'Field of Study',
                            data['fieldOfStudy'] ?? 'N/A',
                            Icons.book,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Institution Details'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Institution',
                            data['institution'] ?? 'N/A',
                            Icons.account_balance,
                          ),
                          _buildCompactInfoRow(
                            'Graduation Year',
                            data['graduationYear'] ?? 'N/A',
                            Icons.calendar_month,
                          ),
                          if (data['certifications'] != null &&
                              (data['certifications'] as String).isNotEmpty)
                            _buildCompactInfoRow(
                              'Certifications',
                              data['certifications'],
                              Icons.verified,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Financial Section
            _buildSectionCard(
              title: 'Salary & Compensation',
              icon: Icons.monetization_on,
              iconGradient: [Colors.green.shade400, Colors.green.shade600],
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Salary Structure Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Salary Structure'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Base Salary',
                            'THB ${currencyFormat.format(data['baseSalary'] ?? 0)}',
                            Icons.payments,
                          ),
                          _buildCompactInfoRow(
                            'Wage Factor',
                            (data['wageFactor'] ?? 1.0).toString(),
                            Icons.tune,
                          ),
                          _buildCompactInfoRow(
                            'Salary %',
                            '${data['salaryPercentage'] ?? 100}%',
                            Icons.percent,
                          ),
                          _buildCompactInfoRow(
                            'Gross Salary',
                            'THB ${currencyFormat.format(data['calculatedSalary'] ?? 0)}',
                            Icons.account_balance_wallet,
                            isHighlighted: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Allowances Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Allowances'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Phone',
                            'THB ${currencyFormat.format(data['phoneAllowance'] ?? 0)}',
                            Icons.phone_android,
                          ),
                          _buildCompactInfoRow(
                            'Education',
                            'THB ${currencyFormat.format(data['educationAllowance'] ?? 0)}',
                            Icons.school,
                          ),
                          _buildCompactInfoRow(
                            'Housing',
                            'THB ${currencyFormat.format(data['houseAllowance'] ?? 0)}',
                            Icons.home,
                          ),
                          _buildCompactInfoRow(
                            'Equipment',
                            'THB ${currencyFormat.format(data['equipmentAllowance'] ?? 0)}',
                            Icons.computer,
                          ),
                          _buildCompactInfoRow(
                            'Total Allowances',
                            'THB ${currencyFormat.format(data['totalAllowances'] ?? 0)}',
                            Icons.attach_money,
                            isHighlighted: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Deductions Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionSubtitle('Deductions'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Tithe (${(data['tithePercentage'] ?? 0).toStringAsFixed(0)}%)',
                            'THB ${currencyFormat.format(data['titheAmount'] ?? 0)}',
                            Icons.volunteer_activism,
                          ),
                          _buildCompactInfoRow(
                            'Provident Fund (${(data['providentFundPercentage'] ?? 0).toStringAsFixed(0)}%)',
                            'THB ${currencyFormat.format(data['providentFundAmount'] ?? 0)}',
                            Icons.savings,
                          ),
                          _buildCompactInfoRow(
                            'Social Security',
                            'THB ${currencyFormat.format(data['socialSecurityAmount'] ?? 0)}',
                            Icons.security,
                          ),
                          if ((data['houseRentalPercentage'] ?? 0) > 0)
                            _buildCompactInfoRow(
                              'House Rental (${(data['houseRentalPercentage'] ?? 0).toStringAsFixed(0)}%)',
                              'THB ${currencyFormat.format(data['houseRentalAmount'] ?? 0)}',
                              Icons.house,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Net Salary Highlight
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Net Salary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'THB ${currencyFormat.format(data['netSalary'] ?? (data['calculatedSalary'] ?? 0))}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Banking & Health Benefits Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banking Column
                Expanded(
                  child: _buildSectionCard(
                    title: 'Banking',
                    icon: Icons.account_balance,
                    iconGradient: [Colors.teal.shade400, Colors.teal.shade600],
                    children: [
                      _buildCompactInfoRow(
                        'Bank Name',
                        data['bankName'] ?? 'N/A',
                        Icons.business,
                      ),
                      _buildCompactInfoRow(
                        'Account Number',
                        _maskAccountNumber(data['bankAccount']),
                        Icons.credit_card,
                      ),
                      _buildCompactInfoRow(
                        'Tax ID',
                        data['taxId'] ?? 'N/A',
                        Icons.receipt_long,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Health Benefits Column (from admin-managed data)
                Expanded(
                  child: _buildSectionCard(
                    title: 'Health Benefits',
                    icon: Icons.health_and_safety,
                    iconGradient: [Colors.pink.shade400, Colors.pink.shade600],
                    children: [
                      _buildCompactInfoRow(
                        'Out-Patient',
                        _salaryBenefits != null
                            ? '${_salaryBenefits!.outPatientPercentage ?? 75}%'
                            : 'N/A',
                        Icons.local_hospital,
                      ),
                      _buildCompactInfoRow(
                        'In-Patient',
                        _salaryBenefits != null
                            ? '${_salaryBenefits!.inPatientPercentage ?? 90}%'
                            : 'N/A',
                        Icons.hotel,
                      ),
                      _buildCompactInfoRow(
                        'Annual Leave',
                        _salaryBenefits != null
                            ? '${_salaryBenefits!.annualLeaveDays ?? 0} days'
                            : 'N/A',
                        Icons.beach_access,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              _buildSectionCard(
                title: 'Additional Notes',
                icon: Icons.note,
                iconGradient: [Colors.amber.shade400, Colors.amber.shade600],
                children: [
                  Text(
                    data['notes'],
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              const SizedBox(height: 16),

            // Admin-managed Salary & Benefits Section (Real-time from salary_benefits collection)
            _buildAdminManagedSalarySection(currencyFormat),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Admin-managed salary benefits section with real-time updates
  Widget _buildAdminManagedSalarySection(NumberFormat currencyFormat) {
    if (_isLoadingSalary) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading salary benefits...'),
            ],
          ),
        ),
      );
    }

    if (_salaryBenefits == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No Admin-Managed Salary Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your salary benefits have not been set up by the administrator yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final salary = _salaryBenefits!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official Salary & Benefits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Managed by HR Admin • Auto-updates',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
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
                  color: salary.isActive ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  salary.isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Salary Structure
          _buildSalaryCard('Salary Structure', Colors.blue, [
            _buildSalaryRow(
              'Wage Factor',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.wageFactor ?? 0)}',
            ),
            _buildSalaryRow('Salary Scale', '${salary.salaryPercentage ?? 0}%'),
            _buildSalaryRow(
              'Gross Salary',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.grossSalary)}',
              isBold: true,
            ),
            _buildSalaryRow(
              'Effective From',
              DateFormat('dd/MM/yyyy').format(salary.effectiveDate),
            ),
          ]),
          const SizedBox(height: 12),

          // Allowances
          _buildSalaryCard('Monthly Allowances', Colors.purple, [
            _buildSalaryRow(
              'Phone Allowance',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.phoneAllowance ?? 0)}',
            ),
            _buildSalaryRow(
              'Housing Allowance',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.housingAllowance ?? 0)}',
            ),
          ]),
          const SizedBox(height: 12),

          // Annual Allowances
          _buildSalaryCard('Annual Allowances', Colors.indigo, [
            _buildSalaryRow(
              'Equipment Allowance',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.equipmentAllowance ?? 0)}/year',
            ),
            _buildSalaryRow(
              'Continuing Education',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.continueEducationAllowance ?? 0)}/year',
            ),
          ]),
          const SizedBox(height: 12),

          // Health Benefits
          _buildSalaryCard('Health Benefits', Colors.teal, [
            _buildSalaryRow(
              'Out-Patient Coverage',
              '${salary.outPatientPercentage ?? 75}%',
            ),
            _buildSalaryRow(
              'In-Patient Coverage',
              '${salary.inPatientPercentage ?? 90}%',
            ),
            _buildSalaryRow(
              'Annual Leave',
              '${salary.annualLeaveDays ?? 0} days',
            ),
          ]),
          const SizedBox(height: 12),

          // Deductions
          _buildSalaryCard('Deductions', Colors.orange, [
            _buildSalaryRow(
              'Tithe (${salary.tithePercentage ?? 10}%)',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.titheAmount)}',
            ),
            _buildSalaryRow(
              'Social Security',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.socialSecurityAmount)}',
            ),
            _buildSalaryRow(
              'Provident Fund (${salary.providentFundPercentage ?? 0}%)',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.providentFundAmount)}',
            ),
            _buildSalaryRow(
              'House Rental (${salary.houseRentalPercentage ?? 10}%)',
              '${salary.currency ?? "THB"} ${currencyFormat.format(salary.houseRentalAmount)}',
            ),
          ]),
          const SizedBox(height: 16),

          // Net Salary Highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.payments, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Net Salary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${salary.currency ?? "THB"} ${currencyFormat.format(salary.netSalary)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
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

  Widget _buildSalaryCard(String title, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 15 : 13,
              color: isBold ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white, width: 3),
              image:
                  data['photoUrl'] != null &&
                      (data['photoUrl'] as String).isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(data['photoUrl'] as String),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child:
                data['photoUrl'] == null || (data['photoUrl'] as String).isEmpty
                ? Center(
                    child: Text(
                      (data['fullName'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['fullName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['position'] ?? 'N/A'} • ${data['department'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Employee ID: ${data['employeeId'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons
          Column(
            children: [
              _buildActionButton(
                icon: Icons.print,
                label: 'Print',
                onPressed: () => _printHrData(context, data),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.edit,
                label: 'Edit',
                onPressed: () => context.go('/hr/data-submission'),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onPressed: () => _confirmDeleteHrData(context, docId),
                color: Colors.red.shade300,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final buttonColor = color ?? Colors.white;
    return Material(
      color: buttonColor.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: buttonColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: buttonColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteHrData(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete HR Data'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your HR data submission?\n\n'
          'This will also remove your staff record. This action cannot be undone.',
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteHrData(context, docId);
    }
  }

  Future<void> _deleteHrData(BuildContext context, String docId) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;

      // Delete staff records that belong to this user (by userId)
      // Only delete staff records where userId matches - this ensures we have permission
      final staffByUserId = await firestore
          .collection('staff')
          .where('userId', isEqualTo: user.id)
          .get();

      for (final doc in staffByUserId.docs) {
        await doc.reference.delete();
        debugPrint('Deleted staff record by userId: ${doc.id}');
      }

      // Delete HR submission
      await firestore.collection('hr_data_submissions').doc(docId).delete();
      debugPrint('Deleted HR submission: $docId');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('HR data deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting HR data: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting HR data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusBadge(String status) {
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
        label = 'Pending Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            'Status: $label',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Color> iconGradient,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: iconGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSubtitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildCompactInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isHighlighted
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isHighlighted
                        ? Colors.green.shade700
                        : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  String _formatEducationLevel(String? level) {
    switch (level) {
      case 'high_school':
        return 'High School';
      case 'vocational':
        return 'Vocational Certificate';
      case 'diploma':
        return 'Diploma';
      case 'bachelor':
        return 'Bachelor\'s Degree';
      case 'master':
        return 'Master\'s Degree';
      case 'doctorate':
        return 'Doctorate (PhD)';
      case 'other':
        return 'Other';
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

  String _maskAccountNumber(String? account) {
    if (account == null || account.isEmpty) return 'N/A';
    if (account.length <= 4) return account;
    return '${'*' * (account.length - 4)}${account.substring(account.length - 4)}';
  }

  Future<void> _printHrData(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 60,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: PdfColors.blue,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      (data['fullName'] ?? 'U')[0].toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data['fullName'] ?? 'Unknown',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${data['position'] ?? 'N/A'} • ${data['department'] ?? 'N/A'}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Employee ID: ${data['employeeId'] ?? 'N/A'}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Personal Information
          _buildPdfSection('Personal Information', [
            _buildPdfRow('Full Name', data['fullName'] ?? 'N/A'),
            _buildPdfRow('Gender', _formatGender(data['gender'])),
            _buildPdfRow(
              'Date of Birth',
              data['dateOfBirth'] != null
                  ? dateFormat.format(
                      (data['dateOfBirth'] as Timestamp).toDate(),
                    )
                  : 'N/A',
            ),
          ]),

          // Contact Information
          _buildPdfSection('Contact Information', [
            _buildPdfRow('Email', data['email'] ?? 'N/A'),
            _buildPdfRow('Phone', data['phone'] ?? 'N/A'),
            _buildPdfRow(
              'Emergency Contact',
              data['emergencyContactName'] ?? 'N/A',
            ),
            _buildPdfRow(
              'Emergency Phone',
              data['emergencyContactPhone'] ?? 'N/A',
            ),
          ]),

          // Education Information
          _buildPdfSection('Education Information', [
            _buildPdfRow(
              'Education Level',
              _formatEducationLevel(data['educationLevel']),
            ),
            _buildPdfRow('Degree', data['highestDegree'] ?? 'N/A'),
            _buildPdfRow('Field of Study', data['fieldOfStudy'] ?? 'N/A'),
            _buildPdfRow('Institution', data['institution'] ?? 'N/A'),
            _buildPdfRow('Graduation Year', data['graduationYear'] ?? 'N/A'),
          ]),

          // Employment Information
          _buildPdfSection('Employment Information', [
            _buildPdfRow('Department', data['department'] ?? 'N/A'),
            _buildPdfRow('Position', data['position'] ?? 'N/A'),
            _buildPdfRow(
              'Employment Type',
              _formatEmploymentType(data['employmentType']),
            ),
            _buildPdfRow(
              'Employment Status',
              _formatEmploymentStatus(data['employmentStatus']),
            ),
            _buildPdfRow(
              'Start Date',
              data['startDate'] != null
                  ? dateFormat.format((data['startDate'] as Timestamp).toDate())
                  : 'N/A',
            ),
          ]),

          // Salary & Benefits
          _buildPdfSection('Salary & Benefits', [
            _buildPdfRow(
              'Base Salary',
              'THB ${currencyFormat.format(data['baseSalary'] ?? 0)}',
            ),
            _buildPdfRow('Wage Factor', (data['wageFactor'] ?? 1.0).toString()),
            _buildPdfRow(
              'Salary Percentage',
              '${data['salaryPercentage'] ?? 100}%',
            ),
            _buildPdfRow(
              'Calculated Salary',
              'THB ${currencyFormat.format(data['calculatedSalary'] ?? 0)}',
            ),
          ]),

          // Allowances
          _buildPdfSection('Benefits & Allowances', [
            _buildPdfRow(
              'Phone Allowance',
              'THB ${currencyFormat.format(data['phoneAllowance'] ?? 0)}',
            ),
            _buildPdfRow(
              'Education Allowance',
              'THB ${currencyFormat.format(data['educationAllowance'] ?? 0)}',
            ),
            _buildPdfRow(
              'House Allowance',
              'THB ${currencyFormat.format(data['houseAllowance'] ?? 0)}',
            ),
            _buildPdfRow(
              'Equipment Allowance',
              'THB ${currencyFormat.format(data['equipmentAllowance'] ?? 0)}',
            ),
            _buildPdfRow(
              'Total Allowances',
              'THB ${currencyFormat.format(data['totalAllowances'] ?? 0)}',
            ),
          ]),

          // Bank Information
          _buildPdfSection('Bank Information', [
            _buildPdfRow('Bank Name', data['bankName'] ?? 'N/A'),
            _buildPdfRow(
              'Account Number',
              _maskAccountNumber(data['bankAccount']),
            ),
            _buildPdfRow('Tax ID', data['taxId'] ?? 'N/A'),
          ]),

          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'HR_Data_${data['fullName'] ?? 'Employee'}.pdf',
    );
  }

  pw.Widget _buildPdfSection(String title, List<pw.Widget> rows) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
