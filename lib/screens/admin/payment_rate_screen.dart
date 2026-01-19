import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/student_timesheet.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/student_rate_config.dart';

class PaymentRateScreen extends StatefulWidget {
  const PaymentRateScreen({super.key});

  @override
  State<PaymentRateScreen> createState() => _PaymentRateScreenState();
}

class _PaymentRateScreenState extends State<PaymentRateScreen> {
  List<StudentProfile> _studentProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentProfiles();
  }

  Future<void> _loadStudentProfiles() async {
    setState(() => _isLoading = true);
    try {
      // Get all student worker users from users collection
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'studentWorker')
          .get();

      final validUserIds = usersSnapshot.docs.map((doc) => doc.id).toSet();

      // Get student profiles and filter only those with valid user records
      final profilesSnapshot = await FirebaseFirestore.instance
          .collection('student_profiles')
          .get();

      _studentProfiles = profilesSnapshot.docs
          .map((doc) => StudentProfile.fromFirestore(doc))
          .where((profile) => validUserIds.contains(profile.userId))
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading students: $e')));
      }
    }
  }

  void _showUpdateRateDialog(StudentProfile profile) async {
    final formKey = GlobalKey<FormState>();

    // Get student name from users collection
    String studentName = 'Student';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        studentName = userData['name'] ?? 'Student';
      }
    } catch (e) {
      // Continue with default name
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _UpdateRateDialog(
        profile: profile,
        studentName: studentName,
        formKey: formKey,
        onUpdate: (grade, rate) async {
          Navigator.pop(context);
          await _updateHourlyRate(profile.userId, rate, grade);
        },
      ),
    );
  }

  Future<void> _updateHourlyRate(String userId, double rate, String? grade) async {
    try {
      // Update student profile with rate and grade
      final updateData = <String, dynamic>{'hourlyRate': rate};
      if (grade != null) {
        updateData['grade'] = grade;
      }
      await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(userId)
          .update(updateData);

      // Update ALL monthly reports for this student (regardless of status)
      final allReportsQuery = await FirebaseFirestore.instance
          .collection('student_monthly_reports')
          .where('studentId', isEqualTo: userId)
          .get();

      // Use batch to update all reports
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in allReportsQuery.docs) {
        final reportData = doc.data();
        final totalHours = reportData['totalHours'] ?? 0.0;
        final newTotalAmount = totalHours * rate;

        batch.update(doc.reference, {
          'hourlyRate': rate,
          'totalAmount': newTotalAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Update ALL timesheets for this student (regardless of status)
      final allTimesheetsQuery = await FirebaseFirestore.instance
          .collection('student_timesheets')
          .where('studentId', isEqualTo: userId)
          .get();

      // Use batch to update all timesheets
      final timesheetBatch = FirebaseFirestore.instance.batch();
      for (final doc in allTimesheetsQuery.docs) {
        final timesheetData = doc.data();
        final totalHours = timesheetData['totalHours'] ?? 0.0;
        final newTotalAmount = totalHours * rate;

        timesheetBatch.update(doc.reference, {
          'hourlyRate': rate,
          'totalAmount': newTotalAmount,
        });
      }
      await timesheetBatch.commit();

      await _loadStudentProfiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hourly rate updated successfully\n'
              '${allReportsQuery.docs.length} reports and '
              '${allTimesheetsQuery.docs.length} timesheets updated',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating rate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Payment Rates'),
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
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              child: _studentProfiles.isEmpty
                  ? _buildEmptyState()
                  : _buildStudentList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(48),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orange.shade100, Colors.orange.shade200],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school,
                size: 64,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No student workers yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Students will appear here after they complete onboarding',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return ListView.builder(
      itemCount: _studentProfiles.length,
      itemBuilder: (context, index) {
        final profile = _studentProfiles[index];
        return _buildStudentCard(profile);
      },
    );
  }

  Widget _buildStudentCard(StudentProfile profile) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(profile.userId)
          .get(),
      builder: (context, snapshot) {
        String studentName = 'Loading...';
        String studentEmail = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          studentName = userData['name'] ?? 'Student';
          studentEmail = userData['email'] ?? '';
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
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          studentName.isNotEmpty
                              ? studentName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
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
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (studentEmail.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    studentEmail,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
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
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.badge,
                        'Student #',
                        profile.studentNumber,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.phone,
                        'Phone',
                        profile.phoneNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.book,
                        'Course',
                        profile.course,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.school_outlined,
                        'Year',
                        profile.yearLevel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hourly Rate',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(profile.hourlyRate),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        if (profile.grade != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(profile.grade!),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Grade ${profile.grade}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showUpdateRateDialog(profile),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Update Rate',
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return Colors.green.shade600;
      case 'B':
        return Colors.blue.shade600;
      case 'C':
        return Colors.orange.shade600;
      case 'D':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

class _UpdateRateDialog extends StatefulWidget {
  final StudentProfile profile;
  final String studentName;
  final GlobalKey<FormState> formKey;
  final Function(String?, double) onUpdate;

  const _UpdateRateDialog({
    required this.profile,
    required this.studentName,
    required this.formKey,
    required this.onUpdate,
  });

  @override
  State<_UpdateRateDialog> createState() => _UpdateRateDialogState();
}

class _UpdateRateDialogState extends State<_UpdateRateDialog> {
  late String? _selectedGrade;
  late TextEditingController _rateController;
  bool _overrideRate = false;
  double _calculatedRate = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedGrade = widget.profile.grade;
    // Use role or 'Other' as fallback for rate calculation
    final rateRole = widget.profile.role ?? 'Other';
    _calculatedRate = StudentRateConfig.getRate(rateRole, _selectedGrade);
    _rateController = TextEditingController(
      text: widget.profile.hourlyRate > 0
          ? widget.profile.hourlyRate.toString()
          : (_calculatedRate > 0 ? _calculatedRate.toString() : ''),
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  void _onGradeChanged(String? grade) {
    setState(() {
      _selectedGrade = grade;
      // Use role or 'Other' as fallback for rate calculation
      final rateRole = widget.profile.role ?? 'Other';
      _calculatedRate = StudentRateConfig.getRate(rateRole, grade);
      if (!_overrideRate && _calculatedRate > 0) {
        _rateController.text = _calculatedRate.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'THB ', decimalDigits: 2);

    return AlertDialog(
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
            child: const Icon(Icons.grade, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Set Student Grade & Rate',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: widget.formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Student #: ${widget.profile.studentNumber}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'Role: ${widget.profile.role ?? "Not set"}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Grade dropdown
              Text(
                'Grade',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                hint: const Text('Select Grade'),
                items: StudentRateConfig.grades.map((grade) {
                  // Use role or 'Other' as fallback for rate display
                  final rateRole = widget.profile.role ?? 'Other';
                  final rate = StudentRateConfig.getRate(rateRole, grade);
                  return DropdownMenuItem(
                    value: grade,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Grade $grade',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'THB ${rate.toStringAsFixed(0)}/hr',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onGradeChanged,
              ),
              const SizedBox(height: 16),

              // Calculated rate display
              if (_selectedGrade != null && _calculatedRate > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calculated Rate',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            currencyFormat.format(_calculatedRate),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Override checkbox
              CheckboxListTile(
                value: _overrideRate,
                onChanged: (value) {
                  setState(() {
                    _overrideRate = value ?? false;
                    if (!_overrideRate && _calculatedRate > 0) {
                      _rateController.text = _calculatedRate.toString();
                    }
                  });
                },
                title: const Text('Override rate manually'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              // Rate input field
              TextFormField(
                controller: _rateController,
                enabled: _overrideRate || _selectedGrade == null,
                decoration: InputDecoration(
                  labelText: 'Hourly Rate',
                  prefixText: 'THB ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                  filled: !_overrideRate && _selectedGrade != null,
                  fillColor: Colors.grey.shade100,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an hourly rate';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) < 0) {
                    return 'Rate must be positive';
                  }
                  return null;
                },
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
              onTap: () {
                if (widget.formKey.currentState!.validate()) {
                  widget.onUpdate(
                    _selectedGrade,
                    double.parse(_rateController.text),
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Update',
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
    );
  }
}
