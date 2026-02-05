import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/equipment.dart';
import '../../services/equipment_service.dart';
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

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _assetTagController = TextEditingController();
  final _locationController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _currentHolderNameController = TextEditingController();

  String _selectedCategory = 'Camera';
  EquipmentCondition _selectedCondition = EquipmentCondition.good;
  EquipmentStatus _selectedStatus = EquipmentStatus.available;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiry;

  bool _isLoading = false;
  bool _isEditing = false;
  Equipment? _existingEquipment;

  @override
  void initState() {
    super.initState();
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
    _locationController.dispose();
    _purchasePriceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _currentHolderNameController.dispose();
    super.dispose();
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
          _nameController.text = equipment.name;
          _descriptionController.text = equipment.description ?? '';
          _brandController.text = equipment.brand ?? '';
          _modelController.text = equipment.model ?? '';
          _serialNumberController.text = equipment.serialNumber ?? '';
          _assetTagController.text = equipment.assetTag ?? '';
          _locationController.text = equipment.location ?? '';
          _purchasePriceController.text =
              equipment.purchasePrice?.toStringAsFixed(0) ?? '';
          _supplierController.text = equipment.supplier ?? '';
          _notesController.text = equipment.notes ?? '';
          _currentHolderNameController.text = equipment.currentHolderName ?? '';
          _selectedCategory = equipment.category;
          _selectedCondition = equipment.condition;
          _selectedStatus = equipment.status;
          _purchaseDate = equipment.purchaseDate;
          _warrantyExpiry = equipment.warrantyExpiry;
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
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        status: _selectedStatus,
        condition: _selectedCondition,
        purchasePrice: _purchasePriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_purchasePriceController.text.trim()),
        purchaseDate: _purchaseDate,
        supplier: _supplierController.text.trim().isEmpty
            ? null
            : _supplierController.text.trim(),
        warrantyExpiry: _warrantyExpiry,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        currentCheckoutId: _existingEquipment?.currentCheckoutId,
        currentHolderId: _existingEquipment?.currentHolderId,
        currentHolderName: _currentHolderNameController.text.trim().isEmpty
            ? null
            : _currentHolderNameController.text.trim(),
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
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildBasicInfoSection(),
                  const SizedBox(height: 16),
                  _buildIdentificationSection(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildPurchaseInfoSection(),
                  const SizedBox(height: 16),
                  _buildStatusSection(),
                  const SizedBox(height: 16),
                  _buildNotesSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildBasicInfoSection(),
        const SizedBox(height: 16),
        _buildIdentificationSection(),
        const SizedBox(height: 16),
        _buildPurchaseInfoSection(),
        const SizedBox(height: 16),
        _buildStatusSection(),
        const SizedBox(height: 16),
        _buildNotesSection(),
        const SizedBox(height: 24),
        SizedBox(
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
        ),
        const SizedBox(height: 32),
      ],
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
        TextFormField(
          controller: _serialNumberController,
          decoration: const InputDecoration(
            labelText: 'Serial Number',
            hintText: 'Manufacturer serial number',
            prefixIcon: Icon(Icons.numbers),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _assetTagController,
          decoration: const InputDecoration(
            labelText: 'Asset Tag',
            hintText: 'Internal asset ID',
            prefixIcon: Icon(Icons.qr_code_2),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Storage Location',
            hintText: 'Where is this stored?',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseInfoSection() {
    final dateFormat = DateFormat('dd MMM yyyy');

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
        ),
        const SizedBox(height: 16),
        InkWell(
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
                color: _purchaseDate != null ? null : Colors.grey.shade600,
              ),
            ),
          ),
        ),
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
