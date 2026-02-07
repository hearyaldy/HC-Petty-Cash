import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/staff.dart';
import '../../models/salary_benefits.dart';
import '../../services/staff_service.dart';
import '../../services/salary_benefits_service.dart';
import '../../utils/responsive_helper.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _photoUrl;
  File? _pickedFile;
  Uint8List? _pickedBytes;
  Staff? _staffRecord;
  SalaryBenefits? _salaryBenefits;
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();
  final StaffService _staffService = StaffService();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      if (user != null) {
        // Load user profile data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;

          setState(() {
            _nameController.text = userData['name'] ?? user.name ?? '';
            _emailController.text = userData['email'] ?? user.email ?? '';
            _phoneController.text = userData['phoneNumber'] ?? '';
            _departmentController.text = userData['department'] ?? '';
            _positionController.text = userData['position'] ?? '';
            _photoUrl =
                userData['photoUrl'] ??
                userData['photo_url']; // Handle both naming conventions
          });
        } else {
          // Fallback to auth user data if no profile exists
          setState(() {
            _nameController.text = user.name;
            _emailController.text = user.email;
          });
        }

        // Load staff record by email
        await _loadStaffAndSalaryData(user.email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStaffAndSalaryData(String email) async {
    try {
      // Find staff record by email
      final staffList = await _staffService.getAllStaff().first;
      final staff = staffList.firstWhere(
        (s) => s.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('Staff not found'),
      );

      _staffRecord = staff;

      // Load salary benefits for this staff
      if (_staffRecord != null) {
        final salaryBenefits = await _salaryBenefitsService
            .getCurrentSalaryBenefitsForStaff(_staffRecord!.id)
            .first;
        _salaryBenefits = salaryBenefits;
      }
    } catch (e) {
      print('Debug: Could not load staff/salary data: $e');
      // This is not critical - user may not have a staff record
    }
  }

  Future<void> _pickImage() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Image Source'),
          content: const Text('Select where to get your profile picture from'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (source != null) {
        final pickedFile = await ImagePicker().pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          if (kIsWeb) {
            final bytes = await pickedFile.readAsBytes();
            setState(() {
              _pickedBytes = bytes;
              _pickedFile = null;
            });
          } else {
            setState(() {
              _pickedFile = File(pickedFile.path);
              _pickedBytes = null;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      if (user == null) {
        throw 'User not authenticated';
      }

      // Prepare user data
      final userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'department': _departmentController.text.trim().isNotEmpty
            ? _departmentController.text.trim()
            : null,
        'position': _positionController.text.trim().isNotEmpty
            ? _positionController.text.trim()
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update user profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set(userData, SetOptions(merge: true));

      // Upload photo if selected
      if (_pickedFile != null || _pickedBytes != null) {
        if (_staffRecord == null) {
          throw 'Staff record not found for this user';
        }
        final staffService = StaffService();
        final photoUrl = await staffService.uploadStaffPhoto(
          _staffRecord!.id,
          imageFile: _pickedFile,
          bytes: _pickedBytes,
        );
        await FirebaseFirestore.instance.collection('users').doc(user.id).set({
          'photoUrl': photoUrl,
        }, SetOptions(merge: true));
        _photoUrl = photoUrl;
      }

      // Update local auth provider by reloading user data
      await authProvider.initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() {
          _pickedFile = null;
          _pickedBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: ResponsiveHelper.getScreenPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 24),
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 24),
                    _buildContactInfoSection(),
                    const SizedBox(height: 24),
                    _buildWorkInfoSection(),
                    const SizedBox(height: 24),
                    if (_salaryBenefits != null) _buildSalaryBenefitsSection(),
                    const SizedBox(height: 32),
                  ],
                ),
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
          colors: [Colors.purple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    icon: Icons.save,
                    tooltip: 'Save Profile',
                    onPressed: _isSaving ? () {} : _saveProfile,
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
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your personal information',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withOpacity(0.9),
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  backgroundImage: _pickedBytes != null
                      ? MemoryImage(_pickedBytes!)
                      : _pickedFile != null
                      ? FileImage(_pickedFile!)
                      : (_photoUrl != null ? NetworkImage(_photoUrl!) : null)
                            as ImageProvider?,
                  child:
                      _pickedFile == null &&
                          _photoUrl == null &&
                          _pickedBytes == null
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                ),
                FloatingActionButton(
                  onPressed: _pickImage,
                  mini: true,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.edit,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _nameController.text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _emailController.text,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              readOnly: true, // Email should not be editable by user
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Invalid email format';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Work Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _departmentController,
              decoration: const InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: 'Position',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryBenefitsSection() {
    final salary = _salaryBenefits!;
    final currencyFormat = NumberFormat('#,##0.00');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Salary & Benefits',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: salary.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    salary.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Basic Salary Info
            _buildSalaryInfoCard('Basic Salary Information', Colors.blue, [
              _buildSalaryRow(
                'Wage Factor',
                '${salary.currency ?? "THB"} ${currencyFormat.format(salary.wageFactor ?? 0)}',
              ),
              _buildSalaryRow(
                'Salary Scale',
                '${salary.salaryPercentage ?? 0}%',
              ),
              _buildSalaryRow(
                'Gross Salary',
                '${salary.currency ?? "THB"} ${currencyFormat.format(salary.grossSalary)}',
                isBold: true,
              ),
              _buildSalaryRow(
                'Effective Date',
                DateFormat('dd/MM/yyyy').format(salary.effectiveDate),
              ),
            ]),

            const SizedBox(height: 12),

            // Health Benefits
            _buildSalaryInfoCard('Health Benefits', Colors.green, [
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
              _buildSalaryRow(
                'Housing Allowance',
                '${salary.currency ?? "THB"} ${currencyFormat.format(salary.housingAllowance ?? 0)}',
              ),
            ]),

            const SizedBox(height: 12),

            // Deductions
            _buildSalaryInfoCard('Deductions', Colors.orange, [
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

            // Net Salary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Net Salary:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${salary.currency ?? "THB"} ${currencyFormat.format(salary.netSalary)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
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

  Widget _buildSalaryInfoCard(
    String title,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
