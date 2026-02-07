import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../models/staff_document.dart';
import '../../models/enums.dart';
import '../../models/salary_benefits.dart';
import '../../services/staff_service.dart';
import '../../services/salary_benefits_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class AddEditStaffScreen extends StatefulWidget {
  final String? staffId; // null for add, not null for edit

  const AddEditStaffScreen({super.key, this.staffId});

  @override
  State<AddEditStaffScreen> createState() => _AddEditStaffScreenState();
}

class _AddEditStaffScreenState extends State<AddEditStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final StaffService _staffService = StaffService();
  final SalaryBenefitsService _salaryBenefitsService = SalaryBenefitsService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isEditing = false;
  Staff? _existingStaff;
  File? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  String? _photoUrl;
  final List<PendingDocument> _pendingDocuments = [];

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
  final _allowancesController = TextEditingController();
  final _tithePercentageController = TextEditingController();
  final _titheAmountController = TextEditingController();
  final _socialSecurityAmountController = TextEditingController();
  final _providentFundPercentageController = TextEditingController();
  final _providentFundAmountController = TextEditingController();
  final _approvalLimitController = TextEditingController();
  final _notesController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passportController = TextEditingController();
  final _countryController = TextEditingController();
  final _provinceStateController = TextEditingController();

  DateTime? _dateOfBirth;
  Gender? _gender;
  UserRole _role = UserRole.requester;
  EmploymentType _employmentType = EmploymentType.fullTime;
  EmploymentStatus _employmentStatus = EmploymentStatus.active;
  DateTime _dateOfJoining = DateTime.now();
  DateTime? _dateOfLeaving;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.staffId != null;
    if (_isEditing) {
      _loadStaff();
    } else {
      _generateEmployeeId();
    }
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
    _allowancesController.dispose();
    _tithePercentageController.dispose();
    _titheAmountController.dispose();
    _socialSecurityAmountController.dispose();
    _providentFundPercentageController.dispose();
    _providentFundAmountController.dispose();
    _approvalLimitController.dispose();
    _notesController.dispose();
    _nationalIdController.dispose();
    _passportController.dispose();
    _countryController.dispose();
    _provinceStateController.dispose();
    super.dispose();
  }

  Future<void> _generateEmployeeId() async {
    final nextId = await _staffService.generateNextEmployeeId();
    _employeeIdController.text = nextId;
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final staff = await _staffService.getStaffById(widget.staffId!);
      if (staff != null) {
        setState(() {
          _existingStaff = staff;
          _employeeIdController.text = staff.employeeId;
          _fullNameController.text = staff.fullName;
          _emailController.text = staff.email;
          _phoneController.text = staff.phoneNumber ?? '';
          _addressController.text = staff.address ?? '';
          _emergencyContactNameController.text =
              staff.emergencyContactName ?? '';
          _emergencyContactPhoneController.text =
              staff.emergencyContactPhone ?? '';
          _departmentController.text = staff.department;
          _positionController.text = staff.position;
          _bankAccountController.text = staff.bankAccountNumber ?? '';
          _bankNameController.text = staff.bankName ?? '';
          _taxIdController.text = staff.taxId ?? '';
          _salaryController.text = staff.monthlySalary?.toString() ?? '';
          _allowancesController.text = staff.allowances?.toString() ?? '';
          _tithePercentageController.text =
              staff.tithePercentage?.toString() ?? '';
          _titheAmountController.text = staff.titheAmount?.toString() ?? '';
          _socialSecurityAmountController.text =
              staff.socialSecurityAmount?.toString() ?? '';
          _providentFundPercentageController.text =
              staff.providentFundPercentage?.toString() ?? '';
          _providentFundAmountController.text =
              staff.providentFundAmount?.toString() ?? '';
          _approvalLimitController.text = staff.approvalLimit?.toString() ?? '';
          _notesController.text = staff.notes ?? '';
          _nationalIdController.text = staff.nationalIdNumber ?? '';
          _passportController.text = staff.passportNumber ?? '';
          _countryController.text = staff.country ?? '';
          _provinceStateController.text = staff.provinceState ?? '';
          _photoUrl = staff.photoUrl;
          _dateOfBirth = staff.dateOfBirth;
          _gender = staff.gender;
          _role = staff.role;
          _employmentType = staff.employmentType;
          _employmentStatus = staff.employmentStatus;
          _dateOfJoining = staff.dateOfJoining;
          _dateOfLeaving = staff.dateOfLeaving;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading staff: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
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

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
        withData: true, // Required for web support
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final bytes = file.bytes;
        final fileName = file.name;

        if (bytes != null) {
          _showDocumentTypeDialog(bytes, fileName);
        } else if (file.path != null) {
          // Fallback for mobile when bytes is null
          final fileObj = File(file.path!);
          final fileBytes = await fileObj.readAsBytes();
          _showDocumentTypeDialog(fileBytes, fileName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking document: $e')));
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
            const Text('Add Document'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              setState(() {
                _pendingDocuments.add(
                  PendingDocument(
                    bytes: bytes,
                    fileName: fileName,
                    type: selectedType,
                    description: descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
                  ),
                );
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removePendingDocument(int index) {
    setState(() {
      _pendingDocuments.removeAt(index);
    });
  }

  Future<void> _navigateToSalaryBenefits() async {
    // Load existing salary benefits for this staff member
    SalaryBenefits? existingSalaryBenefits;
    try {
      existingSalaryBenefits = await _salaryBenefitsService
          .getCurrentSalaryBenefitsOnce(widget.staffId!);
    } catch (e) {
      debugPrint('Error loading salary benefits: $e');
    }

    if (!mounted) return;

    // Navigate to the salary benefits management screen for this staff member
    context.push(
      '/admin/salary-benefits/edit',
      extra: {
        'staff': Staff(
          id: widget.staffId!,
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
          nationalIdNumber: _nationalIdController.text.trim().isNotEmpty
              ? _nationalIdController.text.trim()
              : null,
          passportNumber: _passportController.text.trim().isNotEmpty
              ? _passportController.text.trim()
              : null,
          country: _countryController.text.trim().isNotEmpty
              ? _countryController.text.trim()
              : null,
          provinceState: _provinceStateController.text.trim().isNotEmpty
              ? _provinceStateController.text.trim()
              : null,
          department: _departmentController.text.trim(),
          position: _positionController.text.trim(),
          role: _role,
          employmentType: _employmentType,
          employmentStatus: _employmentStatus,
          dateOfJoining: _dateOfJoining,
          dateOfLeaving: _dateOfLeaving,
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
          allowances: double.tryParse(_allowancesController.text.trim()),
          tithePercentage: double.tryParse(
            _tithePercentageController.text.trim(),
          ),
          titheAmount: double.tryParse(_titheAmountController.text.trim()),
          socialSecurityAmount: double.tryParse(
            _socialSecurityAmountController.text.trim(),
          ),
          providentFundPercentage: double.tryParse(
            _providentFundPercentageController.text.trim(),
          ),
          providentFundAmount: double.tryParse(
            _providentFundAmountController.text.trim(),
          ),
          approvalLimit: double.tryParse(_approvalLimitController.text.trim()),
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          photoUrl: _photoUrl,
          createdAt: _isEditing ? _existingStaff!.createdAt : DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        'salaryBenefits': existingSalaryBenefits,
      },
    );
  }

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUser?.id;

      // Create Staff object
      final staff = _isEditing
          ? Staff(
              id: widget.staffId!,
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
              nationalIdNumber: _nationalIdController.text.trim().isNotEmpty
                  ? _nationalIdController.text.trim()
                  : null,
              passportNumber: _passportController.text.trim().isNotEmpty
                  ? _passportController.text.trim()
                  : null,
              country: _countryController.text.trim().isNotEmpty
                  ? _countryController.text.trim()
                  : null,
              provinceState: _provinceStateController.text.trim().isNotEmpty
                  ? _provinceStateController.text.trim()
                  : null,
              department: _departmentController.text.trim(),
              position: _positionController.text.trim(),
              role: _role,
              employmentType: _employmentType,
              employmentStatus: _employmentStatus,
              dateOfJoining: _dateOfJoining,
              dateOfLeaving: _dateOfLeaving,
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
              allowances: double.tryParse(_allowancesController.text.trim()),
              tithePercentage: double.tryParse(
                _tithePercentageController.text.trim(),
              ),
              titheAmount: double.tryParse(_titheAmountController.text.trim()),
              socialSecurityAmount: double.tryParse(
                _socialSecurityAmountController.text.trim(),
              ),
              providentFundPercentage: double.tryParse(
                _providentFundPercentageController.text.trim(),
              ),
              providentFundAmount: double.tryParse(
                _providentFundAmountController.text.trim(),
              ),
              approvalLimit: double.tryParse(
                _approvalLimitController.text.trim(),
              ),
              notes: _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
              photoUrl: _photoUrl,
              photoScale: _existingStaff?.photoScale,
              photoOffsetX: _existingStaff?.photoOffsetX,
              photoOffsetY: _existingStaff?.photoOffsetY,
              createdAt: _existingStaff!.createdAt,
              updatedAt: DateTime.now(),
            )
          : Staff.create(
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
              nationalIdNumber: _nationalIdController.text.trim().isNotEmpty
                  ? _nationalIdController.text.trim()
                  : null,
              passportNumber: _passportController.text.trim().isNotEmpty
                  ? _passportController.text.trim()
                  : null,
              country: _countryController.text.trim().isNotEmpty
                  ? _countryController.text.trim()
                  : null,
              provinceState: _provinceStateController.text.trim().isNotEmpty
                  ? _provinceStateController.text.trim()
                  : null,
              department: _departmentController.text.trim(),
              position: _positionController.text.trim(),
              role: _role,
              employmentType: _employmentType,
              employmentStatus: _employmentStatus,
              dateOfJoining: _dateOfJoining,
              dateOfLeaving: _dateOfLeaving,
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
              allowances: double.tryParse(_allowancesController.text.trim()),
              tithePercentage: double.tryParse(
                _tithePercentageController.text.trim(),
              ),
              titheAmount: double.tryParse(_titheAmountController.text.trim()),
              socialSecurityAmount: double.tryParse(
                _socialSecurityAmountController.text.trim(),
              ),
              providentFundPercentage: double.tryParse(
                _providentFundPercentageController.text.trim(),
              ),
              providentFundAmount: double.tryParse(
                _providentFundAmountController.text.trim(),
              ),
              approvalLimit: double.tryParse(
                _approvalLimitController.text.trim(),
              ),
              notes: _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
              photoUrl: _photoUrl,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      String staffId;
      if (_isEditing) {
        await _staffService.updateStaff(staff);
        staffId = widget.staffId!;
      } else {
        staffId = await _staffService.createStaff(staff);
      }

      // Upload photo if selected
      if (_selectedPhoto != null || _selectedPhotoBytes != null) {
        await _staffService.uploadStaffPhoto(
          staffId,
          imageFile: _selectedPhoto,
          bytes: _selectedPhotoBytes,
        );
      }

      // Upload pending documents
      for (final doc in _pendingDocuments) {
        await _staffService.uploadStaffDocumentBytes(
          staffId: staffId,
          bytes: doc.bytes,
          fileName: doc.fileName,
          documentType: doc.type,
          description: doc.description,
          uploadedBy: currentUserId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Staff updated successfully'
                  : 'Staff added successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving staff: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Modern SliverAppBar with gradient
                SliverAppBar(
                  expandedHeight: 180,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.blue.shade600,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade700,
                            Colors.blue.shade500,
                            Colors.indigo.shade400,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _isEditing
                                          ? Icons.edit
                                          : Icons.person_add,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isEditing
                                              ? 'Edit Staff'
                                              : 'Add New Staff',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isEditing
                                              ? 'Update staff information'
                                              : 'Enter staff details below',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    if (!_isLoading)
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: ElevatedButton.icon(
                          onPressed: _saveStaff,
                          icon: const Icon(Icons.save, size: 20),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade700,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Form content
                SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveHelper.getMaxContentWidth(context),
                      ),
                      padding: ResponsiveHelper.getScreenPadding(context),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _buildPhotoSection(),
                            const SizedBox(height: 24),
                            _buildBasicInfoSection(),
                            const SizedBox(height: 24),
                            _buildContactSection(),
                            const SizedBox(height: 24),
                            _buildEmploymentSection(),
                            const SizedBox(height: 24),
                            _buildFinancialSection(),
                            const SizedBox(height: 24),
                            _buildDocumentsSection(),
                            const SizedBox(height: 24),
                            _buildNotesSection(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
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
            color: Colors.black.withOpacity(0.05),
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
                colors: [iconGradient[0].withOpacity(0.1), Colors.transparent],
              ),
              border: Border(
                left: BorderSide(color: iconGradient[0], width: 4),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: iconGradient),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradient[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconGradient[0],
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return _buildSectionCard(
      title: 'Profile Photo',
      icon: Icons.camera_alt,
      iconGradient: [Colors.purple.shade400, Colors.purple.shade600],
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade100,
                            Colors.purple.shade50,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.purple.shade200,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.2),
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
                            : (_photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_photoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                      ),
                      child:
                          _selectedPhoto == null &&
                              _photoUrl == null &&
                              _selectedPhotoBytes == null
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.purple.shade300,
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
                            colors: [
                              Colors.purple.shade400,
                              Colors.purple.shade600,
                            ],
                          ),
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
                _selectedPhoto != null ||
                        _selectedPhotoBytes != null ||
                        _photoUrl != null
                    ? 'Tap to change photo'
                    : 'Tap to add photo',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'Basic Information',
      icon: Icons.person,
      iconGradient: [Colors.blue.shade400, Colors.blue.shade600],
      children: [
        _buildTextField(
          controller: _employeeIdController,
          label: 'Employee ID *',
          icon: Icons.badge,
          enabled: !_isEditing,
          validator: (value) {
            if (_isEditing) {
              return (value?.isEmpty ?? true)
                  ? 'Employee ID is required'
                  : null;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name *',
          icon: Icons.person,
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
        const SizedBox(height: 16),
        // National ID and Passport Row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _nationalIdController,
                label: 'National ID Number',
                icon: Icons.badge,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _passportController,
                label: 'Passport Number',
                icon: Icons.card_travel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Country and Province/State Row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _countryController,
                label: 'Country',
                icon: Icons.public,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _provinceStateController,
                label: 'Province/State',
                icon: Icons.location_city,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return _buildSectionCard(
      title: 'Contact Information',
      icon: Icons.contact_phone,
      iconGradient: [Colors.green.shade400, Colors.green.shade600],
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'Email *',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Email is required';
            if (!value!.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Address',
          icon: Icons.home,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.contact_emergency, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Text(
                'Emergency Contact',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _emergencyContactNameController,
          label: 'Contact Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emergencyContactPhoneController,
          label: 'Contact Phone',
          icon: Icons.phone_in_talk,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildEmploymentSection() {
    return _buildSectionCard(
      title: 'Employment Details',
      icon: Icons.work,
      iconGradient: [Colors.indigo.shade400, Colors.indigo.shade600],
      children: [
        _buildTextField(
          controller: _departmentController,
          label: 'Department *',
          icon: Icons.business,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Department is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _positionController,
          label: 'Position/Job Title *',
          icon: Icons.work,
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
                decoration: _buildInputDecoration(
                  label: 'Employment Type',
                  icon: Icons.schedule,
                ),
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
                decoration: _buildInputDecoration(
                  label: 'Status',
                  icon: Icons.toggle_on,
                ),
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
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dateOfJoining,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dateOfLeaving ?? DateTime.now(),
                    firstDate: _dateOfJoining,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  setState(() => _dateOfLeaving = date);
                },
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Date of Leaving',
                    icon: Icons.event_busy,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dateOfLeaving != null
                            ? '${_dateOfLeaving!.day}/${_dateOfLeaving!.month}/${_dateOfLeaving!.year}'
                            : 'N/A',
                        style: TextStyle(
                          color: _dateOfLeaving != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (_dateOfLeaving != null)
                        GestureDetector(
                          onTap: () => setState(() => _dateOfLeaving = null),
                          child: Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialSection() {
    return _buildSectionCard(
      title: 'Financial Information',
      icon: Icons.account_balance,
      iconGradient: [Colors.teal.shade400, Colors.teal.shade600],
      trailing: _isEditing
          ? TextButton.icon(
              onPressed: () => _navigateToSalaryBenefits(),
              icon: Icon(Icons.monetization_on, color: Colors.green.shade600),
              label: Text(
                'Manage Salary',
                style: TextStyle(color: Colors.green.shade600),
              ),
            )
          : null,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _bankAccountController,
                label: 'Bank Account Number',
                icon: Icons.credit_card,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _bankNameController,
                label: 'Bank Name',
                icon: Icons.account_balance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _taxIdController,
                label: 'Tax ID',
                icon: Icons.numbers,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _salaryController,
                label: 'Monthly Salary',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _allowancesController,
          label: 'Allowances (THB)',
          icon: Icons.money,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _tithePercentageController,
                label: 'Tithe (%)',
                icon: Icons.percent,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _titheAmountController,
                label: 'Tithe Amount',
                icon: Icons.volunteer_activism,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _socialSecurityAmountController,
                label: 'Social Security',
                icon: Icons.security,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _providentFundPercentageController,
                label: 'Provident Fund (%)',
                icon: Icons.savings,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _providentFundAmountController,
          label: 'Provident Fund Amount',
          icon: Icons.account_balance_wallet,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _approvalLimitController,
          label: 'Approval Limit (THB)',
          icon: Icons.verified_user,
          keyboardType: TextInputType.number,
          helperText: 'Maximum amount this staff can approve',
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return _buildSectionCard(
      title: 'Documents',
      icon: Icons.folder,
      iconGradient: [Colors.orange.shade400, Colors.orange.shade600],
      trailing: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickDocument,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Add',
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
      children: [
        if (_pendingDocuments.isEmpty)
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
                  'No documents added yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add" to upload documents',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingDocuments.length,
            itemBuilder: (context, index) {
              final doc = _pendingDocuments[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      doc.type.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  title: Text(
                    doc.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.type.displayName,
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                      if (doc.description != null)
                        Text(
                          doc.description!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removePendingDocument(index),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return _buildSectionCard(
      title: 'Additional Notes',
      icon: Icons.note_alt,
      iconGradient: [Colors.amber.shade600, Colors.amber.shade800],
      children: [
        _buildTextField(
          controller: _notesController,
          label: 'Notes',
          icon: Icons.note,
          maxLines: 4,
          hintText: 'Any additional information about this staff member',
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? helperText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      hintText: hintText,
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
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
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? helperText,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _buildInputDecoration(
        label: label,
        icon: icon,
        helperText: helperText,
        hintText: hintText,
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
    );
  }
}

class PendingDocument {
  final Uint8List bytes;
  final String fileName;
  final DocumentType type;
  final String? description;

  PendingDocument({
    required this.bytes,
    required this.fileName,
    required this.type,
    this.description,
  });
}
