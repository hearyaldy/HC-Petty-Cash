import 'package:flutter/material.dart';
import '../services/settings_service.dart';

enum PaidToType { staff, studentWorker, vendor, other }

extension PaidToTypeExtension on PaidToType {
  String get displayName {
    switch (this) {
      case PaidToType.staff:
        return 'Staff';
      case PaidToType.studentWorker:
        return 'Student Worker';
      case PaidToType.vendor:
        return 'Vendor';
      case PaidToType.other:
        return 'Other';
    }
  }
}

class PaidToFieldDialog extends StatefulWidget {
  final String? initialValue;

  const PaidToFieldDialog({super.key, this.initialValue});

  @override
  State<PaidToFieldDialog> createState() => _PaidToFieldDialogState();
}

class _PaidToFieldDialogState extends State<PaidToFieldDialog> {
  PaidToType _selectedType = PaidToType.other;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  String _selectedVendor = 'Lazada';
  String _selectedStaff = '';
  String _selectedStudentWorker = '';
  List<String> _customVendors = [];
  List<String> _customStaff = [];
  List<String> _customStudentWorkers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllCustomData();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _parseInitialValue(widget.initialValue!);
    }
  }

  Future<void> _loadAllCustomData() async {
    try {
      final settingsService = SettingsService();
      final settings = await settingsService.getSettings();
      setState(() {
        _customVendors = [...settings.customVendors, 'Other'];
        _customStaff = settings.customStaff;
        _customStudentWorkers = settings.customStudentWorkers;
        _isLoading = false;
      });
    } catch (e) {
      // If loading fails, use default vendors and empty lists for staff/student workers
      setState(() {
        _customVendors = [
          'Lazada',
          'Shopee',
          'Amazon',
          '7-Eleven',
          'Family Mart',
          'Big C',
          'Tesco Lotus',
          'Makro',
          'Office Mate',
          'Other',
        ];
        _customStaff = [];
        _customStudentWorkers = [];
        _isLoading = false;
      });
    }
  }

  void _parseInitialValue(String value) {
    if (value.startsWith('Staff: ')) {
      _selectedType = PaidToType.staff;
      final staffName = value.substring(7);
      if (_customStaff.contains(staffName)) {
        _selectedStaff = staffName;
        _nameController.clear();
      } else {
        _selectedStaff = '';
        _nameController.text = staffName;
      }
    } else if (value.startsWith('Student Worker: ')) {
      _selectedType = PaidToType.studentWorker;
      final studentWorkerName = value.substring(16);
      if (_customStudentWorkers.contains(studentWorkerName)) {
        _selectedStudentWorker = studentWorkerName;
        _nameController.clear();
      } else {
        _selectedStudentWorker = '';
        _nameController.text = studentWorkerName;
      }
    } else if (value.startsWith('Vendor: ')) {
      _selectedType = PaidToType.vendor;
      final vendorName = value.substring(8);
      if (_customVendors.contains(vendorName)) {
        _selectedVendor = vendorName;
      } else {
        _selectedVendor = 'Other';
        _vendorController.text = vendorName;
      }
    } else {
      _selectedType = PaidToType.other;
      _nameController.text = value;
    }
  }

  String _buildPaidToValue() {
    switch (_selectedType) {
      case PaidToType.staff:
        if (_selectedStaff.isNotEmpty) {
          return 'Staff: $_selectedStaff';
        } else {
          return 'Staff: ${_nameController.text.trim()}';
        }
      case PaidToType.studentWorker:
        if (_selectedStudentWorker.isNotEmpty) {
          return 'Student Worker: $_selectedStudentWorker';
        } else {
          return 'Student Worker: ${_nameController.text.trim()}';
        }
      case PaidToType.vendor:
        if (_selectedVendor == 'Other') {
          return 'Vendor: ${_vendorController.text.trim()}';
        }
        return 'Vendor: $_selectedVendor';
      case PaidToType.other:
        return _nameController.text.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        title: Text('Paid To'),
        content: SizedBox(
          width: 400,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Paid To'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaidToType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: PaidToType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedType == PaidToType.staff) ...[
                const Text(
                  'Staff Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_customStaff.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedStaff.isNotEmpty ? _selectedStaff : null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Enter custom name'),
                      ),
                      ..._customStaff.map((staff) {
                        return DropdownMenuItem(
                          value: staff,
                          child: Text(staff),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStaff = value ?? '';
                        if (_selectedStaff.isNotEmpty) {
                          _nameController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _nameController,
                  enabled: _selectedStaff.isEmpty,
                  decoration: InputDecoration(
                    hintText: 'Enter staff name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
              ],
              if (_selectedType == PaidToType.studentWorker) ...[
                const Text(
                  'Student Worker Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_customStudentWorkers.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedStudentWorker.isNotEmpty
                        ? _selectedStudentWorker
                        : null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Enter custom name'),
                      ),
                      ..._customStudentWorkers.map((studentWorker) {
                        return DropdownMenuItem(
                          value: studentWorker,
                          child: Text(studentWorker),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStudentWorker = value ?? '';
                        if (_selectedStudentWorker.isNotEmpty) {
                          _nameController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _nameController,
                  enabled: _selectedStudentWorker.isEmpty,
                  decoration: InputDecoration(
                    hintText: 'Enter student worker name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
              ],
              if (_selectedType == PaidToType.vendor) ...[
                const Text(
                  'Vendor',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedVendor,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _customVendors.map((vendor) {
                    return DropdownMenuItem(value: vendor, child: Text(vendor));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVendor = value!;
                    });
                  },
                ),
                if (_selectedVendor == 'Other') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vendorController,
                    decoration: const InputDecoration(
                      hintText: 'Enter vendor name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store),
                    ),
                  ),
                ],
              ],
              if (_selectedType == PaidToType.other) ...[
                const Text(
                  'Name / Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter name or description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _buildPaidToValue();
            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a value')),
              );
            }
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
