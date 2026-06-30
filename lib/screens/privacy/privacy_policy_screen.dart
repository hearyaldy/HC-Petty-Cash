import 'package:flutter/material.dart';
import '../../utils/responsive_helper.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: const [
          _PolicyHeader(),
          SizedBox(height: 24),
          _PolicySection(
            title: '1. Who We Are',
            body:
                'Hope Channel Southeast Asia (HCSEA) operates this internal staff management and financial reporting system ("the App"). '
                'The App is accessible to authorized staff, managers, and administrators of HCSEA only.',
          ),
          _PolicySection(
            title: '2. Data We Collect',
            body:
                'To operate the App, we collect and store the following categories of personal data:\n\n'
                '• Identity: full name, employee ID, email address, phone number, home address, date of birth, gender\n'
                '• Government IDs: national ID number, passport number\n'
                '• Financial: bank account number, bank name, tax ID, salary and allowance details, provident fund information\n'
                '• Health: medical bill reimbursement amounts, claim categories, family member information\n'
                '• Employment: job title, department, role, leave records, timesheet data, joining/leaving dates\n'
                '• Documents: photos and files uploaded to support expense claims or HR records\n'
                '• Account: email address and hashed password managed by Firebase Authentication',
          ),
          _PolicySection(
            title: '3. How We Use Your Data',
            body:
                'Your data is used exclusively for:\n\n'
                '• Processing expense reports, purchase requisitions, and payment vouchers\n'
                '• Managing payroll, salary benefits, and medical reimbursements\n'
                '• HR administration including leave requests and employment records\n'
                '• Generating financial reports for internal governance\n'
                '• Authenticating and authorizing access to the system',
          ),
          _PolicySection(
            title: '4. Third-Party Services',
            body:
                'The App relies on the following third-party services:\n\n'
                '• Google Firebase (Firebase Auth, Cloud Firestore, Firebase Storage): Your data is stored in Google\'s cloud infrastructure. '
                'Firebase is governed by Google\'s Privacy Policy and Data Processing Terms.\n\n'
                '• Google Gemini AI: When you use AI-powered features (text enhancement, spell check, resolution generation, survey analysis, or exchange rate lookup), '
                'the text you enter is transmitted to Google\'s Gemini AI service for processing. '
                'This data is subject to Google\'s AI/ML usage policies. '
                'Do not include highly sensitive personal information (national IDs, bank details, medical specifics) in AI-assisted text fields.',
          ),
          _PolicySection(
            title: '5. Data Retention',
            body:
                'We retain personal data for as long as an employment relationship exists or as required by applicable law. '
                'When a staff member\'s record is marked as Resigned or Terminated:\n\n'
                '• Personal and financial records are retained for a minimum of 7 years for audit and legal compliance purposes\n'
                '• Access credentials are deactivated immediately upon termination\n'
                '• Records may be anonymized or deleted upon written request, subject to legal retention requirements\n\n'
                'Uploaded documents in Firebase Storage are retained for the same period.',
          ),
          _PolicySection(
            title: '6. Data Security',
            body:
                'We implement the following security measures:\n\n'
                '• All data is transmitted over HTTPS/TLS\n'
                '• Firebase Security Rules enforce role-based access control — only authorized roles can read or write specific collections\n'
                '• Passwords are managed by Firebase Authentication and never stored in plaintext\n'
                '• Access to sensitive financial and HR data is restricted to admin and manager roles',
          ),
          _PolicySection(
            title: '7. Your Rights',
            body:
                'Under the Thailand Personal Data Protection Act B.E. 2562 (PDPA) and applicable data protection laws, you have the right to:\n\n'
                '• Access the personal data we hold about you\n'
                '• Request correction of inaccurate data\n'
                '• Request deletion of your data (subject to legal retention requirements)\n'
                '• Withdraw consent where processing is based on consent\n'
                '• Lodge a complaint with the relevant data protection authority\n\n'
                'To exercise any of these rights, contact your system administrator or HR manager.',
          ),
          _PolicySection(
            title: '8. Changes to This Policy',
            body:
                'We may update this policy periodically. Changes will be reflected in the App with an updated effective date. '
                'Continued use of the App after changes constitutes acceptance of the updated policy.',
          ),
          _PolicySection(
            title: '9. Contact',
            body:
                'For questions about this policy or how your data is handled, contact:\n\n'
                'Hope Channel Southeast Asia\n'
                'System Administrator / HR Manager\n'
                'Email: admin@hopetv.asia',
          ),
          SizedBox(height: 32),
          _EffectiveDate(),
          SizedBox(height: 24),
        ],
          ),
        ),
      ),
    );
  }
}

class _PolicyHeader extends StatelessWidget {
  const _PolicyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Privacy Policy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hope Channel Southeast Asia — Internal Staff System',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade200),
        ],
      ),
    );
  }
}

class _EffectiveDate extends StatelessWidget {
  const _EffectiveDate();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Text(
            'Effective Date: June 5, 2026',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
