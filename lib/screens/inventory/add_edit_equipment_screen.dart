import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/equipment.dart';
import '../../models/user.dart';
import '../../services/equipment_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class AddEditEquipmentScreen extends StatefulWidget {
  final String? equipmentId;

  const AddEditEquipmentScreen({super.key, this.equipmentId});

  @override
  State<AddEditEquipmentScreen> createState() => _AddEditEquipmentScreenState();
}

class _AddEditEquipmentScreenState extends State<AddEditEquipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final EquipmentService _equipmentService = EquipmentService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers - Basic Info
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();

  // Form controllers - Identification
  final _serialNumberController = TextEditingController();
  final _assetTagController = TextEditingController();
  final _assetCodeController = TextEditingController();
  final _accountingPeriodController = TextEditingController();

  // Form controllers - Location & Assignment
  final _locationController = TextEditingController();
  final _currentHolderNameController = TextEditingController();

  // Form controllers - Purchase & Depreciation
  final _purchasePriceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();
  final _depreciationPercentageController = TextEditingController();
  final _monthsDepreciatedController = TextEditingController();

  // Form controllers - Notes
  final _notesController = TextEditingController();

  String _selectedCategory = 'Camera';
  EquipmentCondition _selectedCondition = EquipmentCondition.good;
  EquipmentStatus _selectedStatus = EquipmentStatus.available;
  DateTime? _purchaseDate;
  int? _purchaseYear;
  DateTime? _warrantyExpiry;

  // Assignment
  String? _assignedToId;
  String? _assignedToName;
  List<User> _availableUsers = [];

  // Image handling
  String? _photoUrl;
  XFile? _selectedImage;
  bool _isUploadingImage = false;

  bool _isLoading = false;
  bool _isEditing = false;
  Equipment? _existingEquipment;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    if (widget.equipmentId != null) {
      _isEditing = true;
      _loadEquipment();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _assetTagController.dispose();
    _assetCodeController.dispose();
    _accountingPeriodController.dispose();
    _locationController.dispose();
    _purchasePriceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _currentHolderNameController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _depreciationPercentageController.dispose();
    _monthsDepreciatedController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _firestoreService.getAllUsers();
      if (mounted) {
        setState(() {
          _availableUsers = users;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _loadEquipment() async {
    setState(() => _isLoading = true);
    try {
      final equipment = await _equipmentService.getEquipmentById(
        widget.equipmentId!,
      );
      if (equipment != null && mounted) {
        setState(() {
          _existingEquipment = equipment;
          // Basic Info
          _nameController.text = equipment.name;
          _descriptionController.text = equipment.description ?? '';
          _brandController.text = equipment.brand ?? '';
          _modelController.text = equipment.model ?? '';
          // Identification
          _serialNumberController.text = equipment.serialNumber ?? '';
          _assetTagController.text = equipment.assetTag ?? '';
          _assetCodeController.text = equipment.assetCode ?? '';
          _accountingPeriodController.text = equipment.accountingPeriod ?? '';
          // Location & Assignment
          _locationController.text = equipment.location ?? '';
          _currentHolderNameController.text = equipment.currentHolderName ?? '';
          _assignedToId = equipment.assignedToId;
          _assignedToName = equipment.assignedToName;
          // Purchase & Depreciation
          _purchasePriceController.text =
              equipment.purchasePrice?.toStringAsFixed(0) ?? '';
          _supplierController.text = equipment.supplier ?? '';
          _quantityController.text = equipment.quantity.toString();
          _unitCostController.text =
              equipment.unitCost?.toStringAsFixed(2) ?? '';
          _depreciationPercentageController.text =
              equipment.depreciationPercentage?.toString() ?? '';
          _monthsDepreciatedController.text =
              equipment.monthsDepreciated?.toString() ?? '';
          // Dates
          _purchaseDate = equipment.purchaseDate;
          _purchaseYear = equipment.purchaseYear;
          _warrantyExpiry = equipment.warrantyExpiry;
          // Notes
          _notesController.text = equipment.notes ?? '';
          // Photo
          _photoUrl = equipment.photoUrl;
          // Status
          _selectedCategory = equipment.category;
          _selectedCondition = equipment.condition;
          _selectedStatus = equipment.status;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading equipment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;

      // Upload image if selected
      String? finalPhotoUrl = _photoUrl;
      if (_selectedImage != null) {
        finalPhotoUrl = await _uploadImage();
      }

      // Parse numeric values
      final purchasePrice = _purchasePriceController.text.trim().isEmpty
          ? null
          : double.tryParse(_purchasePriceController.text.trim());
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
      final unitCost = _unitCostController.text.trim().isEmpty
          ? null
          : double.tryParse(_unitCostController.text.trim());
      final depreciationPct =
          _depreciationPercentageController.text.trim().isEmpty
              ? null
              : double.tryParse(_depreciationPercentageController.text.trim());
      final monthsDepreciated =
          _monthsDepreciatedController.text.trim().isEmpty
              ? null
              : int.tryParse(_monthsDepreciatedController.text.trim());

      final equipment = Equipment(
        id: _existingEquipment?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        serialNumber: _serialNumberController.text.trim().isEmpty
            ? null
            : _serialNumberController.text.trim(),
        assetTag: _assetTagController.text.trim().isEmpty
            ? null
            : _assetTagController.text.trim(),
        assetCode: _assetCodeController.text.trim().isEmpty
            ? null
            : _assetCodeController.text.trim(),
        accountingPeriod: _accountingPeriodController.text.trim().isEmpty
            ? null
            : _accountingPeriodController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        status: _selectedStatus,
        condition: _selectedCondition,
        purchasePrice: purchasePrice,
        purchaseDate: _purchaseDate,
        purchaseYear: _purchaseYear ?? _purchaseDate?.year,
        supplier: _supplierController.text.trim().isEmpty
            ? null
            : _supplierController.text.trim(),
        warrantyExpiry: _warrantyExpiry,
        photoUrl: finalPhotoUrl,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        assignedToId: _assignedToId,
        assignedToName: _assignedToName,
        currentCheckoutId: _existingEquipment?.currentCheckoutId,
        currentHolderId: _existingEquipment?.currentHolderId,
        currentHolderName: _currentHolderNameController.text.trim().isEmpty
            ? null
            : _currentHolderNameController.text.trim(),
        quantity: quantity,
        unitCost: unitCost,
        depreciationPercentage: depreciationPct,
        monthsDepreciated: monthsDepreciated,
        createdAt: _existingEquipment?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: _existingEquipment?.createdBy ?? user?.id,
      );

      if (_isEditing) {
        await _equipmentService.updateEquipment(equipment);
      } else {
        await _equipmentService.createEquipment(equipment);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Equipment updated successfully'
                  : 'Equipment added successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving equipment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'equipment_$timestamp.jpg';
      final ref = FirebaseStorage.instance.ref().child('equipment/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await _selectedImage!.readAsBytes();
        uploadTask = ref.putData(bytes);
      } else {
        uploadTask = ref.putFile(File(_selectedImage!.path));
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.blue.shade700),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to capture image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library, color: Colors.green.shade700),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select from photo library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_selectedImage != null || _photoUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete, color: Colors.red.shade700),
                  ),
                  title: const Text('Remove Image'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _photoUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isPurchaseDate) async {
    final initialDate = isPurchaseDate
        ? (_purchaseDate ?? DateTime.now())
        : (_warrantyExpiry ?? DateTime.now().add(const Duration(days: 365)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = picked;
        } else {
          _warrantyExpiry = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final hasPermission = _isEditing
        ? authProvider.canEditInventory()
        : authProvider.canAddInventory();

    // Check permissions
    if (!hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Equipment' : 'Add Equipment'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Permission Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isEditing
                      ? 'You do not have permission to edit equipment.'
                      : 'You do not have permission to add equipment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Equipment' : 'Add Equipment'),
        elevation: ResponsiveHelper.isDesktop(context) ? 1 : 0,
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _saveEquipment,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: _isLoading && _isEditing && _existingEquipment == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: ResponsiveHelper.getScreenPadding(context),
              child: Form(
                key: _formKey,
                child: ResponsiveHelper.isDesktop(context)
                    ? _buildDesktopLayout()
                    : _buildMobileLayout(),
              ),
            ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            // Photo section at top
            _buildPhotoSection(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildBasicInfoSection(),
                      const SizedBox(height: 16),
                      _buildIdentificationSection(),
                      const SizedBox(height: 16),
                      _buildLocationAssignmentSection(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildPurchaseInfoSection(),
                      const SizedBox(height: 16),
                      _buildDepreciationSection(),
                      const SizedBox(height: 16),
                      _buildStatusSection(),
                      const SizedBox(height: 16),
                      _buildNotesSection(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSaveButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildPhotoSection(),
        const SizedBox(height: 16),
        _buildBasicInfoSection(),
        const SizedBox(height: 16),
        _buildIdentificationSection(),
        const SizedBox(height: 16),
        _buildLocationAssignmentSection(),
        const SizedBox(height: 16),
        _buildPurchaseInfoSection(),
        const SizedBox(height: 16),
        _buildDepreciationSection(),
        const SizedBox(height: 16),
        _buildStatusSection(),
        const SizedBox(height: 16),
        _buildNotesSection(),
        const SizedBox(height: 24),
        _buildSaveButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveEquipment,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isEditing ? 'Update Equipment' : 'Add Equipment'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'Basic Information',
      icon: Icons.info_outline,
      color: Colors.blue,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Equipment Name *',
            hintText: 'e.g., Sony A7S III',
            prefixIcon: Icon(Icons.inventory_2),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter equipment name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Category *',
            prefixIcon: Icon(Icons.category),
            border: OutlineInputBorder(),
          ),
          items: EquipmentCategories.categories.map((category) {
            return DropdownMenuItem(value: category, child: Text(category));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Optional description',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'e.g., Sony',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'e.g., A7S III',
                  prefixIcon: Icon(Icons.model_training),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdentificationSection() {
    return _buildSectionCard(
      title: 'Identification',
      icon: Icons.qr_code,
      color: Colors.purple,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _accountingPeriodController,
                decoration: const InputDecoration(
                  labelText: 'Accounting Period',
                  hintText: 'e.g., 2024/001',
                  prefixIcon: Icon(Icons.calendar_month),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _assetCodeController,
                decoration: const InputDecoration(
                  labelText: 'Asset Code',
                  hintText: 'e.g., ASSET-001',
                  prefixIcon: Icon(Icons.code),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _serialNumberController,
          decoration: const InputDecoration(
            labelText: 'Serial Number / Asset Details',
            hintText: 'Manufacturer serial number',
            prefixIcon: Icon(Icons.numbers),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _assetTagController,
          decoration: const InputDecoration(
            labelText: 'Asset Tag (Legacy)',
            hintText: 'Internal asset ID',
            prefixIcon: Icon(Icons.qr_code_2),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationAssignmentSection() {
    return _buildSectionCard(
      title: 'Location & Assignment',
      icon: Icons.location_on,
      color: Colors.teal,
      children: [
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Storage Location',
            hintText: 'Where is this stored?',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _assignedToId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Assign to Who',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          selectedItemBuilder: (context) {
            final items = [
              const Text('Not Assigned'),
              ..._availableUsers.map((user) {
                return Text(
                  '${user.name} (${user.department})',
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ];
            return items;
          },
          items: [
            const DropdownMenuItem(value: null, child: Text('Not Assigned')),
            ..._availableUsers.map((user) {
              return DropdownMenuItem(
                value: user.id,
                child: Text(
                  '${user.name} (${user.department})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _assignedToId = value;
              _assignedToName =
                  _availableUsers.where((u) => u.id == value).firstOrNull?.name;
            });
          },
        ),
        if (_assignedToName != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  'Assigned to: $_assignedToName',
                  style: TextStyle(color: Colors.teal.shade700),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoSection() {
    return _buildSectionCard(
      title: 'Equipment Photo',
      icon: Icons.camera_alt,
      color: Colors.pink,
      children: [
        InkWell(
          onTap: _showImagePickerDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildPhotoPreview(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    if (_isUploadingImage) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Uploading...'),
          ],
        ),
      );
    }

    if (_selectedImage != null) {
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: _selectedImage!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_selectedImage!.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      }
    }

    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _photoUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
            );
          },
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(
          'Tap to add photo',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildDepreciationSection() {
    // Calculate values for display
    final purchasePrice =
        double.tryParse(_purchasePriceController.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final depPct =
        double.tryParse(_depreciationPercentageController.text.trim());
    final calculatedUnitCost = quantity > 0 ? purchasePrice / quantity : 0.0;
    final monthlyDep = depPct != null ? (purchasePrice * depPct / 100) / 12 : 0;

    return _buildSectionCard(
      title: 'Quantity & Depreciation',
      icon: Icons.trending_down,
      color: Colors.amber.shade700,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: '1',
                  prefixIcon: Icon(Icons.inventory),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _unitCostController,
                decoration: InputDecoration(
                  labelText: 'Unit Cost (THB)',
                  hintText: calculatedUnitCost.toStringAsFixed(0),
                  prefixIcon: const Icon(Icons.price_check),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _depreciationPercentageController,
                decoration: const InputDecoration(
                  labelText: 'Depreciation %',
                  hintText: 'e.g., 20',
                  prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder(),
                  suffixText: '%/year',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _monthsDepreciatedController,
                decoration: const InputDecoration(
                  labelText: 'Months Spent',
                  hintText: '0',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                  suffixText: 'months',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        if (depPct != null && purchasePrice > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Depreciation Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly Depreciation:'),
                    Text(
                      'THB ${NumberFormat('#,###').format(monthlyDep.round())}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Annual Depreciation:'),
                    Text(
                      'THB ${NumberFormat('#,###').format((monthlyDep * 12).round())}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPurchaseInfoSection() {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (i) => currentYear - i);

    return _buildSectionCard(
      title: 'Purchase Information',
      icon: Icons.shopping_cart,
      color: Colors.green,
      children: [
        TextFormField(
          controller: _purchasePriceController,
          decoration: const InputDecoration(
            labelText: 'Purchase Price (THB)',
            hintText: '0',
            prefixIcon: Icon(Icons.attach_money),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Purchase Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _purchaseDate != null
                        ? dateFormat.format(_purchaseDate!)
                        : 'Select date',
                    style: TextStyle(
                      color:
                          _purchaseDate != null ? null : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _purchaseYear ?? _purchaseDate?.year,
                decoration: const InputDecoration(
                  labelText: 'Purchase Year',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
                ),
                items: years.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _purchaseYear = value;
                  });
                },
              ),
            ),
          ],
        ),
        // Asset Age display
        if (_purchaseYear != null || _purchaseDate != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.timelapse, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Asset Age: ${_calculateAssetAge()} years',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _supplierController,
          decoration: const InputDecoration(
            labelText: 'Supplier/Vendor',
            hintText: 'Where was this purchased?',
            prefixIcon: Icon(Icons.store),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectDate(context, false),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Warranty Expiry',
              prefixIcon: Icon(Icons.verified_user),
              border: OutlineInputBorder(),
            ),
            child: Text(
              _warrantyExpiry != null
                  ? dateFormat.format(_warrantyExpiry!)
                  : 'Select date',
              style: TextStyle(
                color: _warrantyExpiry != null ? null : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _calculateAssetAge() {
    if (_purchaseDate != null) {
      return DateTime.now().difference(_purchaseDate!).inDays ~/ 365;
    }
    if (_purchaseYear != null) {
      return DateTime.now().year - _purchaseYear!;
    }
    return 0;
  }

  Widget _buildStatusSection() {
    return _buildSectionCard(
      title: 'Status & Condition',
      icon: Icons.check_circle_outline,
      color: Colors.orange,
      children: [
        DropdownButtonFormField<EquipmentStatus>(
          value: _selectedStatus,
          decoration: const InputDecoration(
            labelText: 'Status *',
            prefixIcon: Icon(Icons.info),
            border: OutlineInputBorder(),
          ),
          items: EquipmentStatus.values.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(status.displayName),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedStatus = value);
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<EquipmentCondition>(
          value: _selectedCondition,
          decoration: const InputDecoration(
            labelText: 'Condition *',
            prefixIcon: Icon(Icons.star_rate),
            border: OutlineInputBorder(),
          ),
          items: EquipmentCondition.values.map((condition) {
            return DropdownMenuItem(
              value: condition,
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: _getConditionColor(condition),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(condition.displayName),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCondition = value);
            }
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _currentHolderNameController,
          decoration: const InputDecoration(
            labelText: 'Current Holder',
            hintText: 'Person currently holding this item',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return _buildSectionCard(
      title: 'Additional Notes',
      icon: Icons.note,
      color: Colors.teal,
      children: [
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Any additional information...',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Color _getStatusColor(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.available:
        return Colors.green;
      case EquipmentStatus.checkedOut:
        return Colors.orange;
      case EquipmentStatus.maintenance:
        return Colors.red;
      case EquipmentStatus.retired:
        return Colors.grey;
    }
  }

  Color _getConditionColor(EquipmentCondition condition) {
    switch (condition) {
      case EquipmentCondition.excellent:
        return Colors.green;
      case EquipmentCondition.good:
        return Colors.blue;
      case EquipmentCondition.fair:
        return Colors.orange;
      case EquipmentCondition.poor:
        return Colors.red;
    }
  }
}
