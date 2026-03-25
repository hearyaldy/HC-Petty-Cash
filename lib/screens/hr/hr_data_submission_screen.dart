import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../models/staff.dart';
import '../../models/enums.dart';
import '../../services/staff_service.dart';

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
  final _addressController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passportController = TextEditingController();
  final _countryController = TextEditingController();
  final _provinceStateController = TextEditingController();
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
  String? _existingPhotoUrl; // Existing photo URL from staff record
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
    _addressController.dispose();
    _nationalIdController.dispose();
    _passportController.dispose();
    _countryController.dispose();
    _provinceStateController.dispose();
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

      // First, try to load from existing HR submission (has all fields)
      final existingHrSubmission = await FirebaseFirestore.instance
          .collection('hr_data_submissions')
          .where('submittedBy', isEqualTo: user.id)
          .limit(1)
          .get();

      if (existingHrSubmission.docs.isNotEmpty) {
        // Prefill from existing HR submission - this has all fields
        _applyHrSubmissionPrefill(existingHrSubmission.docs.first.data());
      } else {
        // Fall back to user document and staff record
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
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('HR Data prefill error: $e');
    }
  }

  /// Prefill form from existing HR submission data (has all fields including education)
  void _applyHrSubmissionPrefill(Map<String, dynamic> data) {
    // Basic info
    _setIfEmpty(_employeeIdController, data['employeeId'] as String?);
    _setIfEmpty(_fullNameController, data['fullName'] as String?);
    _setIfEmpty(_emailController, data['email'] as String?);
    _setIfEmpty(_phoneController, data['phone'] as String?);

    // Contact info
    _setIfEmpty(
      _emergencyContactNameController,
      data['emergencyContactName'] as String?,
    );
    _setIfEmpty(
      _emergencyContactPhoneController,
      data['emergencyContactPhone'] as String?,
    );
    _setIfEmpty(_addressController, data['address'] as String?);

    // ID & Location
    _setIfEmpty(_nationalIdController, data['nationalIdNumber'] as String?);
    _setIfEmpty(_passportController, data['passportNumber'] as String?);
    _setIfEmpty(_countryController, data['country'] as String?);
    _setIfEmpty(_provinceStateController, data['provinceState'] as String?);

    // Employment
    _setIfEmpty(_departmentController, data['department'] as String?);
    _setIfEmpty(_positionController, data['position'] as String?);

    // Banking
    _setIfEmpty(_bankAccountController, data['bankAccount'] as String?);
    _setIfEmpty(_bankNameController, data['bankName'] as String?);
    _setIfEmpty(_taxIdController, data['taxId'] as String?);

    // Salary - format as integer if it's a whole number
    final salary = data['baseSalary'] ?? data['salary'];
    if (salary != null) {
      final salaryNum = (salary as num).toDouble();
      if (salaryNum == salaryNum.truncate()) {
        _setIfEmpty(_salaryController, salaryNum.toInt().toString());
      } else {
        _setIfEmpty(_salaryController, salaryNum.toStringAsFixed(2));
      }
    }

    _setIfEmpty(_notesController, data['notes'] as String?);

    // Education fields
    _setIfEmpty(_highestDegreeController, data['highestDegree'] as String?);
    _setIfEmpty(_institutionController, data['institution'] as String?);
    _setIfEmpty(_fieldOfStudyController, data['fieldOfStudy'] as String?);
    _setIfEmpty(_graduationYearController, data['graduationYear'] as String?);
    _setIfEmpty(_certificationsController, data['certifications'] as String?);

    // Dropdown fields - use _convertEnumToDropdownValue to handle both enum and plain formats
    if (_selectedGender == null && data['gender'] != null) {
      _selectedGender = _convertEnumToDropdownValue(data['gender']);
    }
    if (_selectedEmploymentType == null && data['employmentType'] != null) {
      _selectedEmploymentType = _convertEnumToDropdownValue(
        data['employmentType'],
      );
    }
    if (_selectedEmploymentStatus == null && data['employmentStatus'] != null) {
      _selectedEmploymentStatus = _convertEnumToDropdownValue(
        data['employmentStatus'],
      );
    }
    if (_selectedEducationLevel == null && data['educationLevel'] != null) {
      _selectedEducationLevel = _convertEnumToDropdownValue(
        data['educationLevel'],
      );
    }

    // Dates
    if (_dateOfBirth == null && data['dateOfBirth'] is Timestamp) {
      _dateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
    }
    if (data['startDate'] is Timestamp) {
      _startDate = (data['startDate'] as Timestamp).toDate();
    }
    if (data['endDate'] is Timestamp) {
      _endDate = (data['endDate'] as Timestamp).toDate();
    }

    // Photo
    if (_existingPhotoUrl == null && data['photoUrl'] != null) {
      _existingPhotoUrl = data['photoUrl'] as String?;
    }
  }

  void _applyStaffPrefill(Map<String, dynamic> staffData) {
    _setIfEmpty(_employeeIdController, staffData['employeeId'] as String?);
    _setIfEmpty(_fullNameController, staffData['fullName'] as String?);
    _setIfEmpty(_emailController, staffData['email'] as String?);
    _setIfEmpty(_phoneController, staffData['phoneNumber'] as String?);
    _setIfEmpty(
      _emergencyContactNameController,
      staffData['emergencyContactName'] as String?,
    );
    _setIfEmpty(
      _emergencyContactPhoneController,
      staffData['emergencyContactPhone'] as String?,
    );
    _setIfEmpty(_addressController, staffData['address'] as String?);
    _setIfEmpty(
      _nationalIdController,
      staffData['nationalIdNumber'] as String?,
    );
    _setIfEmpty(_passportController, staffData['passportNumber'] as String?);
    _setIfEmpty(_countryController, staffData['country'] as String?);
    _setIfEmpty(
      _provinceStateController,
      staffData['provinceState'] as String?,
    );
    _setIfEmpty(_departmentController, staffData['department'] as String?);
    _setIfEmpty(_positionController, staffData['position'] as String?);
    _setIfEmpty(
      _bankAccountController,
      staffData['bankAccountNumber'] as String?,
    );
    _setIfEmpty(_bankNameController, staffData['bankName'] as String?);
    _setIfEmpty(_taxIdController, staffData['taxId'] as String?);

    // Salary - format as integer if it's a whole number
    final salary = staffData['monthlySalary'];
    if (salary != null) {
      final salaryNum = (salary as num).toDouble();
      if (salaryNum == salaryNum.truncate()) {
        _setIfEmpty(_salaryController, salaryNum.toInt().toString());
      } else {
        _setIfEmpty(_salaryController, salaryNum.toStringAsFixed(2));
      }
    }

    _setIfEmpty(_notesController, staffData['notes'] as String?);

    // Dropdown fields - staff record stores enum values as strings
    if (_selectedGender == null && staffData['gender'] != null) {
      _selectedGender = _convertEnumToDropdownValue(staffData['gender']);
    }
    if (_selectedEmploymentType == null &&
        staffData['employmentType'] != null) {
      _selectedEmploymentType = _convertEnumToDropdownValue(
        staffData['employmentType'],
      );
    }
    if (_selectedEmploymentStatus == null &&
        staffData['employmentStatus'] != null) {
      _selectedEmploymentStatus = _convertEnumToDropdownValue(
        staffData['employmentStatus'],
      );
    }

    if (_dateOfBirth == null && staffData['dateOfBirth'] is Timestamp) {
      _dateOfBirth = (staffData['dateOfBirth'] as Timestamp).toDate();
    }
    if (staffData['dateOfJoining'] is Timestamp) {
      _startDate = (staffData['dateOfJoining'] as Timestamp).toDate();
    }
    if (staffData['dateOfLeaving'] is Timestamp) {
      _endDate = (staffData['dateOfLeaving'] as Timestamp).toDate();
    }

    // Load existing photo URL
    if (_existingPhotoUrl == null && staffData['photoUrl'] != null) {
      _existingPhotoUrl = staffData['photoUrl'] as String?;
    }
  }

  /// Convert enum string (e.g., "Gender.male") to dropdown value (e.g., "male")
  String? _convertEnumToDropdownValue(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.contains('.')) {
      // Handle enum format like "Gender.male" -> "male"
      final parts = str.split('.');
      final enumValue = parts.last;
      // Convert camelCase to snake_case (e.g., "fullTime" -> "full_time")
      return enumValue
          .replaceAllMapped(
            RegExp(r'([A-Z])'),
            (match) => '_${match.group(1)!.toLowerCase()}',
          )
          .replaceFirst(RegExp(r'^_'), '');
    }
    return str;
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
            if (_selectedPhoto != null ||
                _selectedPhotoBytes != null ||
                (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedPhoto = null;
                    _selectedPhotoBytes = null;
                    _existingPhotoUrl = null;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting photo: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error attaching document: $e')));
      }
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _attachedDocuments.removeAt(index);
    });
  }

  /// Upload photo to Firebase Storage and return the download URL
  Future<String?> _uploadPhotoToStorage(String userId) async {
    if (_selectedPhoto == null && _selectedPhotoBytes == null) {
      return null;
    }

    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = storage.ref().child('staff_photos/$userId/$timestamp.jpg');

      UploadTask uploadTask;
      if (kIsWeb && _selectedPhotoBytes != null) {
        uploadTask = ref.putData(
          _selectedPhotoBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (_selectedPhoto != null) {
        uploadTask = ref.putFile(
          _selectedPhoto!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Photo uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  Future<void> _submitHrData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      // Show loading indicator
    });

    try {
      debugPrint('Starting HR data submission...'); // Debug message

      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      if (user == null) {
        throw 'User not authenticated';
      }

      debugPrint('User authenticated: ${user.id}, ${user.name}'); // Debug message

      // Generate employee ID if not provided
      String employeeId = _employeeIdController.text.trim();
      debugPrint('Original employee ID: "$employeeId"'); // Debug message

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
        debugPrint('Auto-generated employee ID: $employeeId'); // Debug message
      } else {
        debugPrint('Using provided employee ID: $employeeId'); // Debug message
      }

      // Upload photo if selected, or use existing photo URL
      String? photoUrl;
      if (_selectedPhoto != null || _selectedPhotoBytes != null) {
        debugPrint('Uploading profile photo...'); // Debug message
        photoUrl = await _uploadPhotoToStorage(user.id);
      } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
        // Keep existing photo URL if no new photo selected
        photoUrl = _existingPhotoUrl;
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
        'address': _addressController.text.trim(),
        'nationalIdNumber': _nationalIdController.text.trim(),
        'passportNumber': _passportController.text.trim(),
        'country': _countryController.text.trim(),
        'provinceState': _provinceStateController.text.trim(),
        'bankAccount': _bankAccountController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'salary': double.tryParse(_salaryController.text.trim()),
        'dateOfBirth': _dateOfBirth != null
            ? Timestamp.fromDate(_dateOfBirth!)
            : null,
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
        'calculatedSalary':
            double.tryParse(_salaryController.text.trim()) ?? 0.0,
        'phoneAllowance': 0.0,
        'educationAllowance': 0.0,
        'houseAllowance': 0.0,
        'equipmentAllowance': 0.0,
        'totalAllowances': 0.0,
        'annualAllowances': 0.0,
        // Photo
        'photoUrl': photoUrl,
        // Metadata
        'notes': _notesController.text.trim(),
        'submittedBy': user.id,
        'submittedByName': user.name,
        'submittedByEmail': user.email,
        'submittedAt': Timestamp.now(),
        'status': 'pending', // Default status
        'processed': false,
      };

      debugPrint('HR Data submission object prepared'); // Debug message
      debugPrint('Attempting to save to Firestore...'); // Debug message

      // Check if user already has an HR submission - UPDATE instead of CREATE
      final existingSubmission = await FirebaseFirestore.instance
          .collection('hr_data_submissions')
          .where('submittedBy', isEqualTo: user.id)
          .limit(1)
          .get();

      String hrDocId;
      if (existingSubmission.docs.isNotEmpty) {
        // UPDATE existing submission
        hrDocId = existingSubmission.docs.first.id;
        hrDataSubmission['updatedAt'] = Timestamp.now();
        // Preserve original submission timestamp
        hrDataSubmission['submittedAt'] = existingSubmission.docs.first
            .data()['submittedAt'];

        await FirebaseFirestore.instance
            .collection('hr_data_submissions')
            .doc(hrDocId)
            .update(hrDataSubmission);

        debugPrint(
          'HR Data updated successfully (existing submission)',
        ); // Debug message
      } else {
        // CREATE new submission
        final hrDocRef = await FirebaseFirestore.instance
            .collection('hr_data_submissions')
            .add(hrDataSubmission);
        hrDocId = hrDocRef.id;

        debugPrint(
          'HR Data submitted successfully (new submission)',
        ); // Debug message
      }

      // AUTO-CREATE/UPDATE STAFF RECORD
      // This eliminates the need for admin to manually convert HR data to staff
      await _autoSyncToStaffRecord(user, hrDataSubmission, hrDocId, employeeId);

      // Upload documents if any
      if (_attachedDocuments.isNotEmpty) {
        // In a real app, you would upload each document to Firebase Storage
        debugPrint(
          'Processing ${_attachedDocuments.length} document uploads...',
        ); // Debug message
      }

      if (mounted) {
        final isUpdate = existingSubmission.docs.isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate
                  ? 'HR Data updated successfully! Your staff record has been synced.'
                  : 'HR Data submitted successfully! Your staff record has been created.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form after successful submission
        _clearForm();

        // Navigate to My HR Data to see the changes
        context.go('/hr/my-data');
      }
    } catch (e) {
      debugPrint('Error in HR data submission: $e'); // Debug message
      debugPrint('Error type: ${e.runtimeType}'); // Debug message

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting HR data: $e')));
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
    _addressController.clear();
    _nationalIdController.clear();
    _passportController.clear();
    _countryController.clear();
    _provinceStateController.clear();
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
      _existingPhotoUrl = null;
      _attachedDocuments.clear();
    });
  }

  /// Auto-create or update staff record when HR data is submitted
  /// This eliminates the need for admin to manually convert HR data to staff
  Future<void> _autoSyncToStaffRecord(
    dynamic user,
    Map<String, dynamic> hrData,
    String hrSubmissionId,
    String employeeId,
  ) async {
    try {
      final staffService = StaffService();
      final firestore = FirebaseFirestore.instance;

      // Check if staff record already exists for this user (by userId or email)
      final existingStaffByUserId = await firestore
          .collection('staff')
          .where('userId', isEqualTo: user.id)
          .limit(1)
          .get();

      if (existingStaffByUserId.docs.isNotEmpty) {
        // UPDATE existing staff record
        final staffDoc = existingStaffByUserId.docs.first;
        await _updateExistingStaffRecord(staffDoc.id, hrData, hrSubmissionId);

        // Update HR submission with staff link
        await firestore
            .collection('hr_data_submissions')
            .doc(hrSubmissionId)
            .update({
              'convertedToStaffId': staffDoc.id,
              'status': 'processed',
              'processedAt': Timestamp.now(),
              'autoProcessed': true,
            });

        debugPrint('Updated existing staff record: ${staffDoc.id}');
        return;
      }

      // Check by email as fallback
      final existingStaffByEmail = await firestore
          .collection('staff')
          .where('email', isEqualTo: hrData['email'])
          .limit(1)
          .get();

      if (existingStaffByEmail.docs.isNotEmpty) {
        // UPDATE existing staff record and link userId
        final staffDoc = existingStaffByEmail.docs.first;
        await _updateExistingStaffRecord(
          staffDoc.id,
          hrData,
          hrSubmissionId,
          linkUserId: user.id,
        );

        // Update HR submission with staff link
        await firestore
            .collection('hr_data_submissions')
            .doc(hrSubmissionId)
            .update({
              'convertedToStaffId': staffDoc.id,
              'status': 'processed',
              'processedAt': Timestamp.now(),
              'autoProcessed': true,
            });

        debugPrint(
          'Updated existing staff record (found by email): ${staffDoc.id}',
        );
        return;
      }

      // CREATE new staff record
      final newStaff = Staff.create(
        userId: user.id, // Link to Firebase Auth UID
        employeeId: employeeId,
        fullName: hrData['fullName'] ?? '',
        email: hrData['email'] ?? '',
        phoneNumber: hrData['phone'],
        address: hrData['address'],
        emergencyContactName: hrData['emergencyContactName'],
        emergencyContactPhone: hrData['emergencyContactPhone'],
        nationalIdNumber: hrData['nationalIdNumber'],
        passportNumber: hrData['passportNumber'],
        country: hrData['country'],
        provinceState: hrData['provinceState'],
        dateOfBirth: hrData['dateOfBirth'] != null
            ? (hrData['dateOfBirth'] as Timestamp).toDate()
            : null,
        gender: _parseGender(hrData['gender']),
        department: hrData['department'] ?? '',
        position: hrData['position'] ?? '',
        role: UserRole.requester, // Default role
        employmentType: _parseEmploymentType(hrData['employmentType']),
        employmentStatus: _parseEmploymentStatus(hrData['employmentStatus']),
        dateOfJoining: hrData['startDate'] != null
            ? (hrData['startDate'] as Timestamp).toDate()
            : DateTime.now(),
        dateOfLeaving: hrData['endDate'] != null
            ? (hrData['endDate'] as Timestamp).toDate()
            : null,
        bankAccountNumber: hrData['bankAccount'],
        bankName: hrData['bankName'],
        taxId: hrData['taxId'],
        monthlySalary: (hrData['baseSalary'] as num?)?.toDouble(),
        hrSubmissionId: hrSubmissionId, // Link back to HR submission
        photoUrl: hrData['photoUrl'] as String?, // Profile photo
        createdAt: DateTime.now(),
        notes: hrData['notes'],
      );

      final staffId = await staffService.createStaff(newStaff);

      // Update HR submission with staff link
      await firestore
          .collection('hr_data_submissions')
          .doc(hrSubmissionId)
          .update({
            'convertedToStaffId': staffId,
            'status': 'processed',
            'processedAt': Timestamp.now(),
            'autoProcessed': true,
          });

      debugPrint('Created new staff record: $staffId');
    } catch (e) {
      debugPrint('Error auto-syncing to staff record: $e');
      // Don't throw - HR submission was already saved, staff sync is secondary
    }
  }

  Future<void> _updateExistingStaffRecord(
    String staffId,
    Map<String, dynamic> hrData,
    String hrSubmissionId, {
    String? linkUserId,
  }) async {
    final updateData = <String, dynamic>{
      'fullName': hrData['fullName'],
      'email': hrData['email'],
      'phoneNumber': hrData['phone'],
      'emergencyContactName': hrData['emergencyContactName'],
      'emergencyContactPhone': hrData['emergencyContactPhone'],
      'address': hrData['address'],
      'nationalIdNumber': hrData['nationalIdNumber'],
      'passportNumber': hrData['passportNumber'],
      'country': hrData['country'],
      'provinceState': hrData['provinceState'],
      'department': hrData['department'],
      'position': hrData['position'],
      'bankAccountNumber': hrData['bankAccount'],
      'bankName': hrData['bankName'],
      'taxId': hrData['taxId'],
      'hrSubmissionId': hrSubmissionId,
      'updatedAt': Timestamp.now(),
    };

    if (linkUserId != null) {
      updateData['userId'] = linkUserId;
    }

    // Update photo if provided
    if (hrData['photoUrl'] != null &&
        (hrData['photoUrl'] as String).isNotEmpty) {
      updateData['photoUrl'] = hrData['photoUrl'];
    }

    if (hrData['dateOfBirth'] != null) {
      updateData['dateOfBirth'] = hrData['dateOfBirth'];
    }
    if (hrData['gender'] != null) {
      updateData['gender'] = hrData['gender'];
    }
    if (hrData['employmentType'] != null) {
      updateData['employmentType'] = hrData['employmentType'];
    }
    if (hrData['employmentStatus'] != null) {
      updateData['employmentStatus'] = hrData['employmentStatus'];
    }
    if (hrData['startDate'] != null) {
      updateData['dateOfJoining'] = hrData['startDate'];
    }
    if (hrData['endDate'] != null) {
      updateData['dateOfLeaving'] = hrData['endDate'];
    }
    if (hrData['notes'] != null && (hrData['notes'] as String).isNotEmpty) {
      updateData['notes'] = hrData['notes'];
    }

    await FirebaseFirestore.instance
        .collection('staff')
        .doc(staffId)
        .update(updateData);
  }

  Gender _parseGender(String? gender) {
    switch (gender) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        return Gender.preferNotToSay;
    }
  }

  EmploymentType _parseEmploymentType(String? type) {
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

  EmploymentStatus _parseEmploymentStatus(String? status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: ResponsiveContainer(
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

  Widget _buildHeaderSection(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
      child: Column(
        children: [
          // Top action bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
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
          // Existing content
          Row(
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
                child: const Icon(
                  Icons.person_add,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ],
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
                                : _existingPhotoUrl != null &&
                                      _existingPhotoUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_existingPhotoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              _selectedPhoto == null &&
                                  _selectedPhotoBytes == null &&
                                  (_existingPhotoUrl == null ||
                                      _existingPhotoUrl!.isEmpty)
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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                      DropdownMenuItem(
                        value: 'prefer_not_to_say',
                        child: Text('Prefer not to say'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedGender = value),
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
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 10),
                        ), // 10 years in future
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
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 10),
                        ), // 10 years in future
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
            const SizedBox(height: 24),
            const Text(
              'Address & Location',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.public),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _provinceStateController,
                    decoration: const InputDecoration(
                      labelText: 'Province/State',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Identification Documents',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nationalIdController,
                    decoration: const InputDecoration(
                      labelText: 'National ID Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _passportController,
                    decoration: const InputDecoration(
                      labelText: 'Passport Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.card_travel),
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
                    initialValue: _selectedEmploymentType,
                    decoration: const InputDecoration(
                      labelText: 'Employment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'full_time',
                        child: Text('Full Time'),
                      ),
                      DropdownMenuItem(
                        value: 'part_time',
                        child: Text('Part Time'),
                      ),
                      DropdownMenuItem(
                        value: 'contract',
                        child: Text('Contract'),
                      ),
                      DropdownMenuItem(value: 'intern', child: Text('Intern')),
                      DropdownMenuItem(
                        value: 'consultant',
                        child: Text('Consultant'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedEmploymentType = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedEmploymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Employment Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'on_leave',
                        child: Text('On Leave'),
                      ),
                      DropdownMenuItem(
                        value: 'resigned',
                        child: Text('Resigned'),
                      ),
                      DropdownMenuItem(
                        value: 'terminated',
                        child: Text('Terminated'),
                      ),
                      DropdownMenuItem(
                        value: 'retired',
                        child: Text('Retired'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedEmploymentStatus = value),
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
              initialValue: _selectedEducationLevel,
              decoration: const InputDecoration(
                labelText: 'Highest Education Level',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'high_school',
                  child: Text('High School'),
                ),
                DropdownMenuItem(
                  value: 'vocational',
                  child: Text('Vocational Certificate'),
                ),
                DropdownMenuItem(value: 'diploma', child: Text('Diploma')),
                DropdownMenuItem(
                  value: 'bachelor',
                  child: Text('Bachelor\'s Degree'),
                ),
                DropdownMenuItem(
                  value: 'master',
                  child: Text('Master\'s Degree'),
                ),
                DropdownMenuItem(
                  value: 'doctorate',
                  child: Text('Doctorate (PhD)'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) =>
                  setState(() => _selectedEducationLevel = value),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              color: Colors.white,
                              size: 18,
                            ),
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
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
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
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
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
                  final fileName = _attachedDocuments[index].path
                      .split('/')
                      .last;
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
                        child: Icon(
                          Icons.insert_drive_file,
                          color: Colors.indigo.shade600,
                        ),
                      ),
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
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
