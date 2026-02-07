import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../models/enums.dart';
import '../../services/staff_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class EmployeeOnboardingScreen extends StatefulWidget {
  const EmployeeOnboardingScreen({super.key});

  @override
  State<EmployeeOnboardingScreen> createState() =>
      _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends State<EmployeeOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final StaffService _staffService = StaffService();
  final ImagePicker _imagePicker = ImagePicker();

  int _currentStep = 0;
  File? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  bool _isLoading = false;

  // Form controllers
  final _employeeIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _salaryController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dateOfBirth;
  Gender? _gender;
  UserRole _role = UserRole.requester;
  EmploymentType _employmentType = EmploymentType.fullTime;
  EmploymentStatus _employmentStatus = EmploymentStatus.active;
  DateTime _dateOfJoining = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateEmployeeId();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    _taxIdController.dispose();
    _salaryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generateEmployeeId() async {
    final nextId = await _staffService.generateNextEmployeeId();
    _employeeIdController.text = nextId;
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedPhotoBytes = bytes;
            _selectedPhoto = null;
          });
        } else {
          setState(() {
            _selectedPhoto = File(image.path);
            _selectedPhotoBytes = null;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking photo: $e')));
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.id;

      // Create Staff object
      final staff = Staff(
        id: '', // Will be auto-generated
        employeeId: _employeeIdController.text.trim(),
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        emergencyContactName:
            _emergencyContactNameController.text.trim().isNotEmpty
            ? _emergencyContactNameController.text.trim()
            : null,
        emergencyContactPhone:
            _emergencyContactPhoneController.text.trim().isNotEmpty
            ? _emergencyContactPhoneController.text.trim()
            : null,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        department: _departmentController.text.trim(),
        position: _positionController.text.trim(),
        role: _role,
        employmentType: _employmentType,
        employmentStatus: _employmentStatus,
        dateOfJoining: _dateOfJoining,
        dateOfLeaving: null, // New employee, no leaving date
        bankAccountNumber: _bankAccountController.text.trim().isNotEmpty
            ? _bankAccountController.text.trim()
            : null,
        bankName: _bankNameController.text.trim().isNotEmpty
            ? _bankNameController.text.trim()
            : null,
        taxId: _taxIdController.text.trim().isNotEmpty
            ? _taxIdController.text.trim()
            : null,
        monthlySalary: double.tryParse(_salaryController.text.trim()),
        approvalLimit: null, // New employee, no approval limit initially
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        photoUrl: null, // Will be set after upload
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create the staff record
      final staffId = await _staffService.createStaff(staff);

      // Upload photo if selected
      if (_selectedPhoto != null || _selectedPhotoBytes != null) {
        await _staffService.uploadStaffPhoto(
          staffId,
          imageFile: _selectedPhoto,
          bytes: _selectedPhotoBytes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Welcome aboard! Your profile has been created successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to dashboard or staff details
        context.go('/admin-hub');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing onboarding: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    IconData? icon,
    String? helperText,
    String? hintText,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
      filled: true,
      fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      margin: const EdgeInsets.only(bottom: 16),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
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

  Widget _buildStepIndicator() {
    final steps = [
      {'icon': Icons.person, 'label': 'Personal'},
      {'icon': Icons.contact_phone, 'label': 'Contact'},
      {'icon': Icons.work, 'label': 'Employment'},
      {'icon': Icons.account_balance, 'label': 'Financial'},
      {'icon': Icons.check_circle, 'label': 'Review'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          final step = steps[index];

          return GestureDetector(
            onTap: () {
              if (index <= _currentStep) {
                setState(() => _currentStep = index);
              }
            },
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: isActive || isCompleted
                        ? LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          )
                        : null,
                    color: isActive || isCompleted
                        ? null
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : step['icon'] as IconData,
                    color: isActive || isCompleted
                        ? Colors.white
                        : Colors.grey.shade500,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive || isCompleted
                        ? Colors.blue.shade700
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(),
                    const SizedBox(height: 16),

                    // Step Indicator
                    Container(
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
                      child: _buildStepIndicator(),
                    ),

                    const SizedBox(height: 24),

                    // Step Content
                    _buildStepContent(),

                    const SizedBox(height: 24),

                    // Navigation Buttons
                    _buildNavigationButtons(),

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
          colors: [Colors.blue.shade600, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add,
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
                      'Employee Onboarding',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to the team! Please fill in your details.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildContactInfoStep();
      case 2:
        return _buildEmploymentDetailsStep();
      case 3:
        return _buildFinancialInfoStep();
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep -= 1),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          const SizedBox(),
        if (_currentStep < 4)
          ElevatedButton.icon(
            onPressed: () => setState(() => _currentStep += 1),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _completeOnboarding,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_circle),
            label: Text(_isLoading ? 'Processing...' : 'Complete Onboarding'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return _buildSectionCard(
      title: 'Personal Information',
      icon: Icons.person,
      iconGradient: [Colors.blue.shade400, Colors.blue.shade600],
      children: [
        // Photo Upload
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade100, Colors.blue.shade50],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade200, width: 3),
                    image: _selectedPhotoBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_selectedPhotoBytes!),
                            fit: BoxFit.cover,
                          )
                        : _selectedPhoto != null
                        ? DecorationImage(
                            image: FileImage(_selectedPhoto!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedPhoto == null && _selectedPhotoBytes == null
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.blue.shade300,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_camera),
            label: Text(_selectedPhoto != null ? 'Change Photo' : 'Add Photo'),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _employeeIdController,
          decoration: _buildInputDecoration(
            label: 'Employee ID *',
            icon: Icons.badge,
            helperText: 'Auto-generated unique identifier',
            enabled: false,
          ),
          enabled: false,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fullNameController,
          decoration: _buildInputDecoration(
            label: 'Full Name *',
            icon: Icons.person,
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Full name is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dateOfBirth ?? DateTime(1990),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _dateOfBirth = date);
                  }
                },
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Date of Birth',
                    icon: Icons.cake,
                  ),
                  child: Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                        : 'Select date',
                    style: TextStyle(
                      color: _dateOfBirth != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<Gender>(
                value: _gender,
                decoration: _buildInputDecoration(
                  label: 'Gender',
                  icon: Icons.wc,
                ),
                items: Gender.values.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender.displayName),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _gender = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactInfoStep() {
    return _buildSectionCard(
      title: 'Contact Information',
      icon: Icons.contact_phone,
      iconGradient: [Colors.green.shade400, Colors.green.shade600],
      children: [
        TextFormField(
          controller: _emailController,
          decoration: _buildInputDecoration(
            label: 'Email *',
            icon: Icons.email,
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Email is required';
            if (!value!.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: _buildInputDecoration(
            label: 'Phone Number',
            icon: Icons.phone,
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: _buildInputDecoration(label: 'Address', icon: Icons.home),
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Emergency Contact',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyContactNameController,
                decoration: _buildInputDecoration(
                  label: 'Contact Name',
                  icon: Icons.contact_emergency,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyContactPhoneController,
                decoration: _buildInputDecoration(
                  label: 'Contact Phone',
                  icon: Icons.phone_in_talk,
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmploymentDetailsStep() {
    return _buildSectionCard(
      title: 'Employment Details',
      icon: Icons.work,
      iconGradient: [Colors.indigo.shade400, Colors.indigo.shade600],
      children: [
        TextFormField(
          controller: _departmentController,
          decoration: _buildInputDecoration(
            label: 'Department *',
            icon: Icons.business,
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Department is required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _positionController,
          decoration: _buildInputDecoration(
            label: 'Position/Job Title *',
            icon: Icons.work,
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Position is required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<UserRole>(
          value: _role,
          decoration: _buildInputDecoration(
            label: 'System Role *',
            icon: Icons.security,
          ),
          items: UserRole.values.map((role) {
            return DropdownMenuItem(value: role, child: Text(role.displayName));
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _role = value);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<EmploymentType>(
                value: _employmentType,
                decoration: _buildInputDecoration(label: 'Employment Type'),
                items: EmploymentType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _employmentType = value);
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<EmploymentStatus>(
                value: _employmentStatus,
                decoration: _buildInputDecoration(label: 'Status'),
                items: EmploymentStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _employmentStatus = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _dateOfJoining,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _dateOfJoining = date);
            }
          },
          child: InputDecorator(
            decoration: _buildInputDecoration(
              label: 'Date of Joining *',
              icon: Icons.event,
            ),
            child: Text(
              '${_dateOfJoining.day}/${_dateOfJoining.month}/${_dateOfJoining.year}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialInfoStep() {
    return _buildSectionCard(
      title: 'Financial Information',
      icon: Icons.account_balance,
      iconGradient: [Colors.teal.shade400, Colors.teal.shade600],
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bankAccountController,
                decoration: _buildInputDecoration(
                  label: 'Bank Account Number',
                  icon: Icons.account_balance,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _bankNameController,
                decoration: _buildInputDecoration(label: 'Bank Name'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _taxIdController,
                decoration: _buildInputDecoration(
                  label: 'Tax ID',
                  icon: Icons.numbers,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _salaryController,
                decoration: _buildInputDecoration(
                  label: 'Monthly Salary (optional)',
                  icon: Icons.attach_money,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: _buildInputDecoration(
            label: 'Additional Notes',
            icon: Icons.note,
            hintText: 'Any additional information about your employment',
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        // Personal Info Review
        _buildSectionCard(
          title: 'Personal Information',
          icon: Icons.person,
          iconGradient: [Colors.blue.shade400, Colors.blue.shade600],
          children: [
            _buildReviewRow('Full Name', _fullNameController.text),
            _buildReviewRow(
              'Date of Birth',
              _dateOfBirth != null
                  ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                  : 'Not provided',
            ),
            _buildReviewRow('Gender', _gender?.displayName ?? 'Not provided'),
          ],
        ),

        // Contact Info Review
        _buildSectionCard(
          title: 'Contact Information',
          icon: Icons.contact_phone,
          iconGradient: [Colors.green.shade400, Colors.green.shade600],
          children: [
            _buildReviewRow('Email', _emailController.text),
            _buildReviewRow(
              'Phone',
              _phoneController.text.isEmpty
                  ? 'Not provided'
                  : _phoneController.text,
            ),
            _buildReviewRow(
              'Address',
              _addressController.text.isEmpty
                  ? 'Not provided'
                  : _addressController.text,
            ),
          ],
        ),

        // Employment Info Review
        _buildSectionCard(
          title: 'Employment Details',
          icon: Icons.work,
          iconGradient: [Colors.indigo.shade400, Colors.indigo.shade600],
          children: [
            _buildReviewRow('Department', _departmentController.text),
            _buildReviewRow('Position', _positionController.text),
            _buildReviewRow('Role', _role.displayName),
            _buildReviewRow('Employment Type', _employmentType.displayName),
            _buildReviewRow('Status', _employmentStatus.displayName),
            _buildReviewRow(
              'Date of Joining',
              '${_dateOfJoining.day}/${_dateOfJoining.month}/${_dateOfJoining.year}',
            ),
          ],
        ),

        // Financial Info Review
        _buildSectionCard(
          title: 'Financial Information',
          icon: Icons.account_balance,
          iconGradient: [Colors.teal.shade400, Colors.teal.shade600],
          children: [
            _buildReviewRow(
              'Bank Account',
              _bankAccountController.text.isEmpty
                  ? 'Not provided'
                  : _bankAccountController.text,
            ),
            _buildReviewRow(
              'Bank Name',
              _bankNameController.text.isEmpty
                  ? 'Not provided'
                  : _bankNameController.text,
            ),
            _buildReviewRow(
              'Tax ID',
              _taxIdController.text.isEmpty
                  ? 'Not provided'
                  : _taxIdController.text,
            ),
            _buildReviewRow(
              'Monthly Salary',
              _salaryController.text.isEmpty
                  ? 'Not provided'
                  : '฿${_salaryController.text}',
            ),
          ],
        ),

        // Disclaimer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'By clicking "Complete Onboarding", you agree that the information provided is accurate and complete.',
                  style: TextStyle(fontSize: 14, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
