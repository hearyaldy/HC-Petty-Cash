import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';
import '../../models/staff.dart';
import '../../models/salary_benefits.dart';
import '../../models/staff_document.dart';
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
                            'THB ${currencyFormat.format(data['phoneAllowance'] ?? 0)}/month',
                            Icons.phone_android,
                          ),
                          _buildCompactInfoRow(
                            'Housing',
                            'THB ${currencyFormat.format(data['houseAllowance'] ?? 0)}/month',
                            Icons.home,
                          ),
                          _buildCompactInfoRow(
                            'Monthly Allowances',
                            'THB ${currencyFormat.format(data['totalAllowances'] ?? 0)}',
                            Icons.attach_money,
                            isHighlighted: true,
                          ),
                          const SizedBox(height: 8),
                          _buildSectionSubtitle('Annual Allowances'),
                          const SizedBox(height: 8),
                          _buildCompactInfoRow(
                            'Education',
                            'THB ${currencyFormat.format(data['educationAllowance'] ?? 0)}/year',
                            Icons.school,
                          ),
                          _buildCompactInfoRow(
                            'Equipment',
                            'THB ${currencyFormat.format(data['equipmentAllowance'] ?? 0)}/year',
                            Icons.computer,
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
                const SizedBox(height: 12),
                // Note about official salary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'See "Official Salary & Benefits" section below for your confirmed net salary.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
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

            // My Documents Section
            _buildMyDocumentsSection(),
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

  // My Documents Section - Shows documents uploaded by admin for this staff
  Widget _buildMyDocumentsSection() {
    if (_staffRecord == null) {
      return const SizedBox.shrink(); // Don't show if no staff record linked
    }

    return _buildSectionCard(
      title: 'My Documents',
      icon: Icons.folder,
      iconGradient: [Colors.blue.shade400, Colors.cyan.shade500],
      trailing: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add, color: Colors.blue.shade700, size: 20),
        ),
        onPressed: _pickAndUploadDocument,
        tooltip: 'Upload Document',
      ),
      children: [
        StreamBuilder<List<StaffDocument>>(
          stream: _staffService.getStaffDocuments(_staffRecord!.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading documents',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              );
            }

            final documents = snapshot.data ?? [];

            if (documents.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.file_present,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No documents uploaded yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap + to upload your documents',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: documents
                  .map((doc) => _buildDocumentCard(doc))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickAndUploadDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final bytes = file.bytes;
        final fileName = file.name;

        if (bytes != null) {
          _showDocumentTypeDialog(bytes, fileName);
        } else if (file.path != null) {
          final fileObj = File(file.path!);
          final fileBytes = await fileObj.readAsBytes();
          _showDocumentTypeDialog(fileBytes, fileName);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read file data')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking document: $e')));
      }
    }
  }

  void _showDocumentTypeDialog(Uint8List bytes, String fileName) {
    DocumentType selectedType = DocumentType.other;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.upload_file, color: Colors.blue.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Upload Document'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'File: $fileName',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DocumentType>(
              value: selectedType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Document Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: DocumentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Text(type.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          type.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) selectedType = value;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadDocument(
                bytes,
                fileName,
                selectedType,
                descriptionController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadDocument(
    Uint8List bytes,
    String fileName,
    DocumentType documentType,
    String? description,
  ) async {
    if (_staffRecord == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading document...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.id;

      await _staffService.uploadStaffDocumentBytes(
        staffId: _staffRecord!.id,
        bytes: bytes,
        fileName: fileName,
        documentType: documentType,
        description: description?.isNotEmpty == true ? description : null,
        uploadedBy: currentUserId,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDocumentCard(StaffDocument doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getDocumentColor(doc.type).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(doc.type.icon, style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Text(
          doc.fileName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getDocumentColor(doc.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                doc.type.displayName,
                style: TextStyle(
                  fontSize: 10,
                  color: _getDocumentColor(doc.type),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${doc.formattedFileSize} • ${DateFormat('MMM d, y').format(doc.uploadedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, color: Colors.blue.shade600, size: 22),
              onPressed: () => _openDocument(doc.fileUrl),
              tooltip: 'Download',
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red.shade400,
                size: 22,
              ),
              onPressed: () => _confirmDeleteDocument(doc),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Color _getDocumentColor(DocumentType type) {
    switch (type) {
      case DocumentType.idCard:
        return Colors.blue;
      case DocumentType.passport:
        return Colors.indigo;
      case DocumentType.drivingLicense:
        return Colors.green;
      case DocumentType.certificate:
        return Colors.amber.shade700;
      case DocumentType.contract:
        return Colors.purple;
      case DocumentType.resume:
        return Colors.teal;
      case DocumentType.other:
        return Colors.grey;
    }
  }

  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening document: $e')));
      }
    }
  }

  Future<void> _confirmDeleteDocument(StaffDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Delete Document'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this document?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(doc.type.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          doc.type.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteDocument(doc);
    }
  }

  Future<void> _deleteDocument(StaffDocument doc) async {
    if (_staffRecord == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting document...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _staffService.deleteStaffDocument(doc.id, _staffRecord!.id);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                onPressed: () => _printHrData(context, data, _salaryBenefits),
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
    SalaryBenefits? salary,
  ) async {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    // Use salary data if available, otherwise fall back to HR submission data
    final baseSalary = salary?.baseSalary ?? (data['baseSalary'] ?? 0);
    final grossSalary = salary?.grossSalary ?? (data['calculatedSalary'] ?? 0);
    final wageFactor = salary?.wageFactor ?? (data['wageFactor'] ?? 1.0);
    final salaryPercentage =
        salary?.salaryPercentage ?? (data['salaryPercentage'] ?? 100);
    final phoneAllowance =
        salary?.phoneAllowance ?? (data['phoneAllowance'] ?? 0);
    final housingAllowance =
        salary?.housingAllowance ?? (data['houseAllowance'] ?? 0);
    final totalAllowances = phoneAllowance + housingAllowance;
    final tithePercentage =
        salary?.tithePercentage ?? (data['tithePercentage'] ?? 10);
    final titheAmount = salary?.titheAmount ?? (data['titheAmount'] ?? 0);
    final socialSecurityAmount =
        salary?.socialSecurityAmount ?? (data['socialSecurityAmount'] ?? 0);
    final providentFundPercentage =
        salary?.providentFundPercentage ??
        (data['providentFundPercentage'] ?? 0);
    final providentFundAmount =
        salary?.providentFundAmount ?? (data['providentFundAmount'] ?? 0);
    final houseRentalPercentage =
        salary?.houseRentalPercentage ?? (data['houseRentalPercentage'] ?? 10);
    final houseRentalAmount =
        salary?.houseRentalAmount ?? (data['houseRentalAmount'] ?? 0);
    final netSalary =
        salary?.netSalary ??
        ((grossSalary + phoneAllowance + housingAllowance) -
            (titheAmount +
                socialSecurityAmount +
                providentFundAmount +
                houseRentalAmount));
    final totalDeductions =
        titheAmount +
        socialSecurityAmount +
        providentFundAmount +
        houseRentalAmount;
    final currency = salary?.currency ?? 'THB';

    // Load Google Font for Unicode support
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document();

    // Try to load photo if available
    pw.ImageProvider? photoImage;
    final photoUrl = data['photoUrl'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        photoImage = await networkImage(photoUrl);
      } catch (e) {
        debugPrint('Could not load photo for PDF: $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) => [
          // Header with Photo
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                // Photo or initials
                if (photoImage != null)
                  pw.Container(
                    width: 70,
                    height: 70,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: PdfColors.blue300, width: 2),
                    ),
                    child: pw.ClipOval(
                      child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(
                    width: 70,
                    height: 70,
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
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data['fullName'] ?? 'Unknown',
                        style: pw.TextStyle(
                          fontSize: 20,
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
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Section 1: Personal Information
          _buildPdfSectionHeader('Personal Information'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Full Name',
                  data['fullName'] ?? 'N/A',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Gender',
                  _formatGender(data['gender']),
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Date of Birth',
                  data['dateOfBirth'] != null
                      ? dateFormat.format(
                          (data['dateOfBirth'] as Timestamp).toDate(),
                        )
                      : 'N/A',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section 2: Contact Information
          _buildPdfSectionHeader('Contact Information'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact('Email', data['email'] ?? 'N/A'),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact('Phone', data['phone'] ?? 'N/A'),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Emergency Contact',
                  data['emergencyContactName'] ?? 'N/A',
                ),
              ),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Emergency Phone',
                  data['emergencyContactPhone'] ?? 'N/A',
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section 3: Education
          _buildPdfSectionHeader('Education'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Education Level',
                  _formatEducationLevel(data['educationLevel']),
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Highest Degree',
                  data['highestDegree'] ?? 'N/A',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Field of Study',
                  data['fieldOfStudy'] ?? 'N/A',
                ),
              ),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Institution',
                  data['institution'] ?? 'N/A',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Graduation Year',
                  data['graduationYear'] ?? 'N/A',
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section 4: Employment Information
          _buildPdfSectionHeader('Employment Information'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Department',
                  data['department'] ?? 'N/A',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Position',
                  data['position'] ?? 'N/A',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Employment Type',
                  _formatEmploymentType(data['employmentType']),
                ),
              ),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Employment Status',
                  _formatEmploymentStatus(data['employmentStatus']),
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Start Date',
                  data['startDate'] != null
                      ? dateFormat.format(
                          (data['startDate'] as Timestamp).toDate(),
                        )
                      : 'N/A',
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section 5: Salary & Benefits
          _buildPdfSectionHeader('Salary & Benefits'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Base Salary',
                  '$currency ${currencyFormat.format(baseSalary)}',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Wage Factor',
                  wageFactor.toString(),
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Salary Percentage',
                  '${salaryPercentage.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Gross Salary',
                  '$currency ${currencyFormat.format(grossSalary)}',
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section 6: Allowances
          _buildPdfSectionHeader('Allowances'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Phone Allowance',
                  '$currency ${currencyFormat.format(phoneAllowance)}/month',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Housing Allowance',
                  '$currency ${currencyFormat.format(housingAllowance)}/month',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Total Monthly Allowances',
                  '$currency ${currencyFormat.format(totalAllowances)}',
                ),
              ),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Education Allowance',
                  'THB ${currencyFormat.format(data['educationAllowance'] ?? 0)}/year',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Equipment Allowance',
                  'THB ${currencyFormat.format(data['equipmentAllowance'] ?? 0)}/year',
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section 7: Bank Information
          _buildPdfSectionHeader('Bank Information'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Bank Name',
                  data['bankName'] ?? 'N/A',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Account Number',
                  _maskAccountNumber(data['bankAccount']),
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact('Tax ID', data['taxId'] ?? 'N/A'),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Section 8: Deductions
          _buildPdfSectionHeader('Deductions'),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Tithe (${tithePercentage.toStringAsFixed(0)}%)',
                  '$currency ${currencyFormat.format(titheAmount)}',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Social Security',
                  '$currency ${currencyFormat.format(socialSecurityAmount)}',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Provident Fund (${providentFundPercentage.toStringAsFixed(0)}%)',
                  '$currency ${currencyFormat.format(providentFundAmount)}',
                ),
              ),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'House Rental (${houseRentalPercentage.toStringAsFixed(0)}%)',
                  '$currency ${currencyFormat.format(houseRentalAmount)}',
                ),
              ),
              pw.Expanded(
                child: _buildPdfRowCompact(
                  'Total Deductions',
                  '$currency ${currencyFormat.format(totalDeductions)}',
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 16),

          // Compensation Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Total Compensation Summary',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPdfRowCompact(
                        'Gross Salary',
                        '$currency ${currencyFormat.format(grossSalary)}',
                      ),
                    ),
                    pw.Expanded(
                      child: _buildPdfRowCompact(
                        'Total Deductions',
                        '$currency ${currencyFormat.format(totalDeductions)}',
                      ),
                    ),
                    pw.Expanded(
                      child: _buildPdfRowCompact(
                        'Monthly Allowances',
                        '$currency ${currencyFormat.format(totalAllowances)}',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green200,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Net Salary (After Deductions)',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.Text(
                        '$currency ${currencyFormat.format(netSalary)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'HR_Data_${data['fullName'] ?? 'Employee'}.pdf',
    );
  }

  pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _buildPdfRowCompact(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
        ],
      ),
    );
  }
}
