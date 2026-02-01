import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class HrDataSubmissionScreen extends StatefulWidget {
  const HrDataSubmissionScreen({super.key});

  @override
  State<HrDataSubmissionScreen> createState() => _HrDataSubmissionScreenState();
}

class _HrDataSubmissionScreenState extends State<HrDataSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _salaryController = TextEditingController();
  final _notesController = TextEditingController();

  // Education controllers
  final _highestDegreeController = TextEditingController();
  final _institutionController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  final _graduationYearController = TextEditingController();
  final _certificationsController = TextEditingController();

  DateTime? _dateOfBirth;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _selectedGender;
  String? _selectedEmploymentType;
  String? _selectedEmploymentStatus;
  String? _selectedEducationLevel;
  File? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  final List<File> _attachedDocuments = [];

  @override
  void initState() {
    super.initState();
    _prefillFromCurrentUser();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _fullNameController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    _taxIdController.dispose();
    _salaryController.dispose();
    _notesController.dispose();
    // Education
    _highestDegreeController.dispose();
    _institutionController.dispose();
    _fieldOfStudyController.dispose();
    _graduationYearController.dispose();
    _certificationsController.dispose();
    super.dispose();
  }

  Future<void> _prefillFromCurrentUser() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      if (user == null) return;

      _setIfEmpty(_fullNameController, user.name);
      _setIfEmpty(_emailController, user.email);
      if (_departmentController.text.trim().isEmpty) {
        _departmentController.text = user.department;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        _setIfEmpty(_fullNameController, data['name'] as String?);
        _setIfEmpty(_emailController, data['email'] as String?);
        _setIfEmpty(_phoneController, data['phoneNumber'] as String?);
        _setIfEmpty(_departmentController, data['department'] as String?);
        _setIfEmpty(_positionController, data['position'] as String?);
      }

      final staffSnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('userId', isEqualTo: user.id)
          .limit(1)
          .get();
      if (staffSnapshot.docs.isEmpty) {
        final byEmail = await FirebaseFirestore.instance
            .collection('staff')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          _applyStaffPrefill(byEmail.docs.first.data());
        }
      } else {
        _applyStaffPrefill(staffSnapshot.docs.first.data());
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('HR Data prefill error: $e');
    }
  }

  void _applyStaffPrefill(Map<String, dynamic> staffData) {
    _setIfEmpty(_employeeIdController, staffData['employeeId'] as String?);
    _setIfEmpty(_fullNameController, staffData['fullName'] as String?);
    _setIfEmpty(_emailController, staffData['email'] as String?);
    _setIfEmpty(_phoneController, staffData['phoneNumber'] as String?);
    _setIfEmpty(_emergencyContactNameController, staffData['emergencyContactName'] as String?);
    _setIfEmpty(_emergencyContactPhoneController, staffData['emergencyContactPhone'] as String?);
    _setIfEmpty(_departmentController, staffData['department'] as String?);
    _setIfEmpty(_positionController, staffData['position'] as String?);
    _setIfEmpty(_bankAccountController, staffData['bankAccountNumber'] as String?);
    _setIfEmpty(_bankNameController, staffData['bankName'] as String?);
    _setIfEmpty(_taxIdController, staffData['taxId'] as String?);
    _setIfEmpty(_salaryController, staffData['monthlySalary']?.toString());
    _setIfEmpty(_notesController, staffData['notes'] as String?);

    if (_dateOfBirth == null && staffData['dateOfBirth'] is Timestamp) {
      _dateOfBirth = (staffData['dateOfBirth'] as Timestamp).toDate();
    }
  }

  void _setIfEmpty(TextEditingController controller, String? value) {
    if (value == null || value.trim().isEmpty) return;
    if (controller.text.trim().isEmpty) {
      controller.text = value;
    }
  }


  Future<void> _selectProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_selectedPhoto != null || _selectedPhotoBytes != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedPhoto = null;
                    _selectedPhotoBytes = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (file != null) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          setState(() {
            _selectedPhotoBytes = bytes;
            _selectedPhoto = null;
          });
        } else {
          setState(() {
            _selectedPhoto = File(file.path);
            _selectedPhotoBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting photo: $e')),
        );
      }
    }
  }

  Future<void> _attachDocument() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );

      if (file != null) {
        setState(() {
          _attachedDocuments.add(File(file.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error attaching document: $e')),
        );
      }
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _attachedDocuments.removeAt(index);
    });
  }

  Future<void> _submitHrData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      // Show loading indicator
    });

    try {
      print('Starting HR data submission...'); // Debug message

      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      if (user == null) {
        throw 'User not authenticated';
      }

      print('User authenticated: ${user.id}, ${user.name}'); // Debug message

      // Generate employee ID if not provided
      String employeeId = _employeeIdController.text.trim();
      print('Original employee ID: "$employeeId"'); // Debug message

      if (employeeId.isEmpty) {
        // Generate custom employee ID: HC-[current year]-[last 2 digits of birth year if available]
        String currentYear = DateTime.now().year.toString();
        String birthYearSuffix = '00'; // Default if no birth date
        if (_dateOfBirth != null) {
          String fullBirthYear = _dateOfBirth!.year.toString();
          if (fullBirthYear.length >= 2) {
            birthYearSuffix = fullBirthYear.substring(fullBirthYear.length - 2);
          }
        }
        employeeId = 'HC-$currentYear-$birthYearSuffix';
        print('Auto-generated employee ID: $employeeId'); // Debug message
      } else {
        print('Using provided employee ID: $employeeId'); // Debug message
      }

      // Create HR data submission
      final hrDataSubmission = {
        'employeeId': employeeId,
        'fullName': _fullNameController.text.trim(),
        'department': _departmentController.text.trim(),
        'position': _positionController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'emergencyContactName': _emergencyContactNameController.text.trim(),
        'emergencyContactPhone': _emergencyContactPhoneController.text.trim(),
        'bankAccount': _bankAccountController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'salary': double.tryParse(_salaryController.text.trim()),
        'dateOfBirth': _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'gender': _selectedGender,
        'employmentType': _selectedEmploymentType,
        'employmentStatus': _selectedEmploymentStatus,
        // Education Information
        'educationLevel': _selectedEducationLevel,
        'highestDegree': _highestDegreeController.text.trim(),
        'institution': _institutionController.text.trim(),
        'fieldOfStudy': _fieldOfStudyController.text.trim(),
        'graduationYear': _graduationYearController.text.trim(),
        'certifications': _certificationsController.text.trim(),
        // Salary & Benefits - Set by Admin (initialize with defaults)
        'baseSalary': double.tryParse(_salaryController.text.trim()) ?? 0.0,
        'wageFactor': 0.0,
        'salaryPercentage': 100.0,
        'calculatedSalary': double.tryParse(_salaryController.text.trim()) ?? 0.0,
        'phoneAllowance': 0.0,
        'educationAllowance': 0.0,
        'houseAllowance': 0.0,
        'equipmentAllowance': 0.0,
        'totalAllowances': 0.0,
        // Metadata
        'notes': _notesController.text.trim(),
        'submittedBy': user.id,
        'submittedByName': user.name,
        'submittedByEmail': user.email,
        'submittedAt': Timestamp.now(),
        'status': 'pending', // Default status
        'processed': false,
      };

      print('HR Data submission object prepared'); // Debug message
      print('Attempting to save to Firestore...'); // Debug message

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('hr_data_submissions')
          .add(hrDataSubmission);

      print('HR Data submitted successfully to Firestore'); // Debug message

      // Upload photo if selected
      if (_selectedPhoto != null) {
        // In a real app, you would upload to Firebase Storage and save the URL
        // For now, we'll just save the submission and note that a photo was attached
        print('Processing photo upload...'); // Debug message
      }

      // Upload documents if any
      if (_attachedDocuments.isNotEmpty) {
        // In a real app, you would upload each document to Firebase Storage
        print('Processing ${_attachedDocuments.length} document uploads...'); // Debug message
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('HR Data submitted successfully! Admin will review shortly.'),
          ),
        );

        // Clear form after successful submission
        _clearForm();

        // Navigate back to dashboard
        context.go('/dashboard');
      }
    } catch (e) {
      print('Error in HR data submission: $e'); // Debug message
      print('Error type: ${e.runtimeType}'); // Debug message

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting HR data: $e')),
        );
      }
    }
  }

  void _clearForm() {
    _employeeIdController.clear();
    _fullNameController.clear();
    _departmentController.clear();
    _positionController.clear();
    _emailController.clear();
    _phoneController.clear();
    _emergencyContactNameController.clear();
    _emergencyContactPhoneController.clear();
    _bankAccountController.clear();
    _bankNameController.clear();
    _taxIdController.clear();
    _salaryController.clear();
    _notesController.clear();
    // Education
    _highestDegreeController.clear();
    _institutionController.clear();
    _fieldOfStudyController.clear();
    _graduationYearController.clear();
    _certificationsController.clear();
    setState(() {
      _dateOfBirth = null;
      _startDate = DateTime.now();
      _endDate = null;
      _selectedGender = null;
      _selectedEmploymentType = null;
      _selectedEmploymentStatus = null;
      _selectedEducationLevel = null;
      _selectedPhoto = null;
      _selectedPhotoBytes = null;
      _attachedDocuments.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: ResponsiveHelper.isDesktop(context) ? 1 : 0,
        title: const Text('HR Data Submission'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Padding(
            padding: ResponsiveHelper.getScreenPadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(context),
                  const SizedBox(height: 24),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 24),
                  _buildContactInfoSection(),
                  const SizedBox(height: 24),
                  _buildEducationInfoSection(),
                  const SizedBox(height: 24),
                  _buildEmploymentInfoSection(),
                  const SizedBox(height: 24),
                  _buildFinancialInfoSection(),
                  const SizedBox(height: 24),
                  _buildDocumentsSection(),
                  const SizedBox(height: 24),
                  _buildNotesSection(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Information Form',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'HR Data Submission',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please fill in all required fields marked with *',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add, size: 48, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withValues(alpha: 0.1), Colors.transparent],
        ),
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
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
    );
  }

  Widget _buildPersonalInfoSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Personal Information',
              icon: Icons.person,
              color: Colors.blue,
            ),
            // Profile Photo Upload
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _selectProfilePhoto,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade100,
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
                                  color: Colors.grey.shade400,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to upload profile photo',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _employeeIdController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    // Make employee ID optional - will be auto-generated if empty
                    validator: (value) {
                      // Don't require employee ID since it will be auto-generated
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
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
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      child: Text(
                        _dateOfBirth != null
                            ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                            : 'Select date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                      DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
                    ],
                    onChanged: (value) => setState(() => _selectedGender = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // 10 years in future
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      child: Text(
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // 10 years in future
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event_busy),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _endDate != null
                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                : 'N/A',
                          ),
                          if (_endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _endDate = null),
                            ),
                        ],
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
  }

  Widget _buildContactInfoSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Contact Information',
              icon: Icons.contact_phone,
              color: Colors.green,
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
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
            const SizedBox(height: 16),
            const Text(
              'Emergency Contact',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emergencyContactNameController,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.contact_emergency),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emergencyContactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_in_talk),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentInfoSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Employment Information',
              icon: Icons.work,
              color: Colors.purple,
            ),
            TextFormField(
              controller: _departmentController,
              decoration: const InputDecoration(
                labelText: 'Department *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Department is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: 'Position/Job Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Position is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEmploymentType,
                    decoration: const InputDecoration(
                      labelText: 'Employment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'full_time', child: Text('Full Time')),
                      DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                      DropdownMenuItem(value: 'contract', child: Text('Contract')),
                      DropdownMenuItem(value: 'intern', child: Text('Intern')),
                      DropdownMenuItem(value: 'consultant', child: Text('Consultant')),
                    ],
                    onChanged: (value) => setState(() => _selectedEmploymentType = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEmploymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Employment Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
                      DropdownMenuItem(value: 'resigned', child: Text('Resigned')),
                      DropdownMenuItem(value: 'terminated', child: Text('Terminated')),
                      DropdownMenuItem(value: 'retired', child: Text('Retired')),
                    ],
                    onChanged: (value) => setState(() => _selectedEmploymentStatus = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationInfoSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Education Information',
              icon: Icons.school,
              color: Colors.indigo,
            ),
            DropdownButtonFormField<String>(
              value: _selectedEducationLevel,
              decoration: const InputDecoration(
                labelText: 'Highest Education Level',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              items: const [
                DropdownMenuItem(value: 'high_school', child: Text('High School')),
                DropdownMenuItem(value: 'vocational', child: Text('Vocational Certificate')),
                DropdownMenuItem(value: 'diploma', child: Text('Diploma')),
                DropdownMenuItem(value: 'bachelor', child: Text('Bachelor\'s Degree')),
                DropdownMenuItem(value: 'master', child: Text('Master\'s Degree')),
                DropdownMenuItem(value: 'doctorate', child: Text('Doctorate (PhD)')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _selectedEducationLevel = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _highestDegreeController,
                    decoration: const InputDecoration(
                      labelText: 'Degree / Certificate Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.card_membership),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _fieldOfStudyController,
                    decoration: const InputDecoration(
                      labelText: 'Field of Study / Major',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.subject),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _institutionController,
                    decoration: const InputDecoration(
                      labelText: 'Institution / University',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _graduationYearController,
                    decoration: const InputDecoration(
                      labelText: 'Graduation Year',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _certificationsController,
              decoration: InputDecoration(
                labelText: 'Professional Certifications',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.verified),
                hintText: 'e.g., CPA, PMP, AWS Certified',
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialInfoSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Bank Information',
              icon: Icons.account_balance,
              color: Colors.teal,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bankAccountController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Account Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Tax ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _salaryController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Salary (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSectionHeader(
                    title: 'Supporting Documents',
                    icon: Icons.folder,
                    color: Colors.indigo,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _attachDocument,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_file, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Attach File',
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
              ],
            ),
            const SizedBox(height: 16),
            if (_attachedDocuments.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No documents attached',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Attach File" to add supporting documents',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attachedDocuments.length,
                itemBuilder: (context, index) {
                  final fileName = _attachedDocuments[index].path.split('/').last;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.insert_drive_file, color: Colors.indigo.shade600),
                      ),
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeDocument(index),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Additional Notes',
              icon: Icons.note_alt,
              color: Colors.amber.shade700,
            ),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Any additional information for HR',
                prefixIcon: const Icon(Icons.note),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitHrData,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Submit HR Data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
