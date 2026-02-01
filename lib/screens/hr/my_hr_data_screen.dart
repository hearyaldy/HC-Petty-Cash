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

class MyHrDataScreen extends StatelessWidget {
  const MyHrDataScreen({super.key});

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
          print('MyHrDataScreen: Connection state = ${snapshot.connectionState}'); // Debug
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
            print('MyHrDataScreen: Query tried to find documents where submittedBy = ${user.id}'); // Debug
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 80,
                color: Colors.orange.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No HR Data Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You haven\'t submitted your HR information yet.\nPlease submit your data to view it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/hr/data-submission'),
              icon: const Icon(Icons.add),
              label: const Text('Submit HR Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataView(BuildContext context, Map<String, dynamic> data, String docId) {
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

            // Personal Information
            _buildInfoSection(
              context,
              title: 'Personal Information',
              icon: Icons.person,
              color: Colors.blue,
              children: [
                _buildInfoRow('Employee ID', data['employeeId'] ?? 'N/A'),
                _buildInfoRow('Full Name', data['fullName'] ?? 'N/A'),
                _buildInfoRow('Gender', _formatGender(data['gender'])),
                _buildInfoRow(
                  'Date of Birth',
                  data['dateOfBirth'] != null
                      ? dateFormat.format((data['dateOfBirth'] as Timestamp).toDate())
                      : 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contact Information
            _buildInfoSection(
              context,
              title: 'Contact Information',
              icon: Icons.contact_phone,
              color: Colors.green,
              children: [
                _buildInfoRow('Email', data['email'] ?? 'N/A'),
                _buildInfoRow('Phone', data['phone'] ?? 'N/A'),
                _buildInfoRow('Emergency Contact', data['emergencyContactName'] ?? 'N/A'),
                _buildInfoRow('Emergency Phone', data['emergencyContactPhone'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),

            // Education Information
            _buildInfoSection(
              context,
              title: 'Education Information',
              icon: Icons.school,
              color: Colors.indigo,
              children: [
                _buildInfoRow('Education Level', _formatEducationLevel(data['educationLevel'])),
                _buildInfoRow('Degree', data['highestDegree'] ?? 'N/A'),
                _buildInfoRow('Field of Study', data['fieldOfStudy'] ?? 'N/A'),
                _buildInfoRow('Institution', data['institution'] ?? 'N/A'),
                _buildInfoRow('Graduation Year', data['graduationYear'] ?? 'N/A'),
                _buildInfoRow('Certifications', data['certifications'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),

            // Employment Information
            _buildInfoSection(
              context,
              title: 'Employment Information',
              icon: Icons.work,
              color: Colors.purple,
              children: [
                _buildInfoRow('Department', data['department'] ?? 'N/A'),
                _buildInfoRow('Position', data['position'] ?? 'N/A'),
                _buildInfoRow('Employment Type', _formatEmploymentType(data['employmentType'])),
                _buildInfoRow('Status', _formatEmploymentStatus(data['employmentStatus'])),
                _buildInfoRow(
                  'Start Date',
                  data['startDate'] != null
                      ? dateFormat.format((data['startDate'] as Timestamp).toDate())
                      : 'N/A',
                ),
                if (data['endDate'] != null)
                  _buildInfoRow(
                    'End Date',
                    dateFormat.format((data['endDate'] as Timestamp).toDate()),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Salary & Benefits
            _buildInfoSection(
              context,
              title: 'Salary & Benefits',
              icon: Icons.monetization_on,
              color: Colors.green.shade700,
              children: [
                _buildInfoRow(
                  'Base Salary',
                  '฿ ${currencyFormat.format(data['baseSalary'] ?? 0)}',
                ),
                _buildInfoRow(
                  'Wage Factor',
                  (data['wageFactor'] ?? 1.0).toString(),
                ),
                _buildInfoRow(
                  'Salary Percentage',
                  '${data['salaryPercentage'] ?? 100}%',
                ),
                _buildInfoRow(
                  'Calculated Salary',
                  '฿ ${currencyFormat.format(data['calculatedSalary'] ?? 0)}',
                  isHighlighted: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Allowances
            _buildInfoSection(
              context,
              title: 'Benefits & Allowances',
              icon: Icons.card_giftcard,
              color: Colors.pink,
              children: [
                _buildInfoRow(
                  'Phone Allowance',
                  '฿ ${currencyFormat.format(data['phoneAllowance'] ?? 0)}',
                ),
                _buildInfoRow(
                  'Education Allowance',
                  '฿ ${currencyFormat.format(data['educationAllowance'] ?? 0)}',
                ),
                _buildInfoRow(
                  'House Allowance',
                  '฿ ${currencyFormat.format(data['houseAllowance'] ?? 0)}',
                ),
                _buildInfoRow(
                  'Equipment Allowance',
                  '฿ ${currencyFormat.format(data['equipmentAllowance'] ?? 0)}',
                ),
                _buildInfoRow(
                  'Total Allowances',
                  '฿ ${currencyFormat.format(data['totalAllowances'] ?? 0)}',
                  isHighlighted: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bank Information
            _buildInfoSection(
              context,
              title: 'Bank Information',
              icon: Icons.account_balance,
              color: Colors.teal,
              children: [
                _buildInfoRow('Bank Name', data['bankName'] ?? 'N/A'),
                _buildInfoRow('Account Number', _maskAccountNumber(data['bankAccount'])),
                _buildInfoRow('Tax ID', data['taxId'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              _buildInfoSection(
                context,
                title: 'Additional Notes',
                icon: Icons.note,
                color: Colors.amber.shade700,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      data['notes'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data, String docId) {
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
            ),
            child: Center(
              child: Text(
                (data['fullName'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
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
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
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
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.1), Colors.transparent],
              ),
              border: Border(left: BorderSide(color: color, width: 4)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: isHighlighted ? Colors.green.shade700 : Colors.grey.shade800,
              ),
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

  Future<void> _printHrData(BuildContext context, Map<String, dynamic> data) async {
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
                  ? dateFormat.format((data['dateOfBirth'] as Timestamp).toDate())
                  : 'N/A',
            ),
          ]),

          // Contact Information
          _buildPdfSection('Contact Information', [
            _buildPdfRow('Email', data['email'] ?? 'N/A'),
            _buildPdfRow('Phone', data['phone'] ?? 'N/A'),
            _buildPdfRow('Emergency Contact', data['emergencyContactName'] ?? 'N/A'),
            _buildPdfRow('Emergency Phone', data['emergencyContactPhone'] ?? 'N/A'),
          ]),

          // Education Information
          _buildPdfSection('Education Information', [
            _buildPdfRow('Education Level', _formatEducationLevel(data['educationLevel'])),
            _buildPdfRow('Degree', data['highestDegree'] ?? 'N/A'),
            _buildPdfRow('Field of Study', data['fieldOfStudy'] ?? 'N/A'),
            _buildPdfRow('Institution', data['institution'] ?? 'N/A'),
            _buildPdfRow('Graduation Year', data['graduationYear'] ?? 'N/A'),
          ]),

          // Employment Information
          _buildPdfSection('Employment Information', [
            _buildPdfRow('Department', data['department'] ?? 'N/A'),
            _buildPdfRow('Position', data['position'] ?? 'N/A'),
            _buildPdfRow('Employment Type', _formatEmploymentType(data['employmentType'])),
            _buildPdfRow('Employment Status', _formatEmploymentStatus(data['employmentStatus'])),
            _buildPdfRow(
              'Start Date',
              data['startDate'] != null
                  ? dateFormat.format((data['startDate'] as Timestamp).toDate())
                  : 'N/A',
            ),
          ]),

          // Salary & Benefits
          _buildPdfSection('Salary & Benefits', [
            _buildPdfRow('Base Salary', '฿ ${currencyFormat.format(data['baseSalary'] ?? 0)}'),
            _buildPdfRow('Wage Factor', (data['wageFactor'] ?? 1.0).toString()),
            _buildPdfRow('Salary Percentage', '${data['salaryPercentage'] ?? 100}%'),
            _buildPdfRow('Calculated Salary', '฿ ${currencyFormat.format(data['calculatedSalary'] ?? 0)}'),
          ]),

          // Allowances
          _buildPdfSection('Benefits & Allowances', [
            _buildPdfRow('Phone Allowance', '฿ ${currencyFormat.format(data['phoneAllowance'] ?? 0)}'),
            _buildPdfRow('Education Allowance', '฿ ${currencyFormat.format(data['educationAllowance'] ?? 0)}'),
            _buildPdfRow('House Allowance', '฿ ${currencyFormat.format(data['houseAllowance'] ?? 0)}'),
            _buildPdfRow('Equipment Allowance', '฿ ${currencyFormat.format(data['equipmentAllowance'] ?? 0)}'),
            _buildPdfRow('Total Allowances', '฿ ${currencyFormat.format(data['totalAllowances'] ?? 0)}'),
          ]),

          // Bank Information
          _buildPdfSection('Bank Information', [
            _buildPdfRow('Bank Name', data['bankName'] ?? 'N/A'),
            _buildPdfRow('Account Number', _maskAccountNumber(data['bankAccount'])),
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
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
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
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
