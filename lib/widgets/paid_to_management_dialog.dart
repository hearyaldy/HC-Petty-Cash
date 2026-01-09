import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class PaidToManagementDialog extends StatefulWidget {
  const PaidToManagementDialog({super.key});

  @override
  State<PaidToManagementDialog> createState() => _PaidToManagementDialogState();
}

class _PaidToManagementDialogState extends State<PaidToManagementDialog> {
  final TextEditingController _newVendorController = TextEditingController();
  final TextEditingController _newStaffController = TextEditingController();
  final TextEditingController _newStudentWorkerController =
      TextEditingController();

  List<String> _vendors = [];
  List<String> _staff = [];
  List<String> _studentWorkers = [];

  bool _isLoading = true;
  String? _errorMessage;
  int _currentTab = 0; // 0: Vendors, 1: Staff, 2: Student Workers

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final settingsService = SettingsService();
      final settings = await settingsService.getSettings();
      setState(() {
        _vendors = List.from(settings.customVendors);
        _staff = List.from(settings.customStaff);
        _studentWorkers = List.from(settings.customStudentWorkers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAllData() async {
    try {
      final settingsService = SettingsService();
      final settings = await settingsService.getSettings();
      final updatedSettings = settings.copyWith(
        customVendors: _vendors,
        customStaff: _staff,
        customStudentWorkers: _studentWorkers,
      );
      await settingsService.saveSettings(updatedSettings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addVendor() {
    final vendorName = _newVendorController.text.trim();
    if (vendorName.isNotEmpty && !_vendors.contains(vendorName)) {
      setState(() {
        _vendors.add(vendorName);
      });
      _newVendorController.clear();
      _saveAllData(); // Save all data when adding
    } else if (_vendors.contains(vendorName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor already exists'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeVendor(String vendor) {
    setState(() {
      _vendors.remove(vendor);
    });
    _saveAllData(); // Save all data when removing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed "$vendor"'), backgroundColor: Colors.red),
    );
  }

  void _resetToDefaults() {
    final defaultVendors = [
      'Lazada',
      'Shopee',
      'Amazon',
      '7-Eleven',
      'Family Mart',
      'Big C',
      'Tesco Lotus',
      'Makro',
      'Office Mate',
    ];
    setState(() {
      _vendors = List.from(defaultVendors);
    });
    _saveAllData(); // Save the defaults
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset to default vendors'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _addStaff() {
    final staffName = _newStaffController.text.trim();
    if (staffName.isNotEmpty && !_staff.contains(staffName)) {
      setState(() {
        _staff.add(staffName);
      });
      _newStaffController.clear();
      _saveAllData(); // Save all data when adding
    } else if (_staff.contains(staffName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff member already exists'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeStaff(String staff) {
    setState(() {
      _staff.remove(staff);
    });
    _saveAllData(); // Save all data when removing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed "$staff"'), backgroundColor: Colors.red),
    );
  }

  void _addStudentWorker() {
    final studentWorkerName = _newStudentWorkerController.text.trim();
    if (studentWorkerName.isNotEmpty &&
        !_studentWorkers.contains(studentWorkerName)) {
      setState(() {
        _studentWorkers.add(studentWorkerName);
      });
      _newStudentWorkerController.clear();
      _saveAllData(); // Save all data when adding
    } else if (_studentWorkers.contains(studentWorkerName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student worker already exists'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeStudentWorker(String studentWorker) {
    setState(() {
      _studentWorkers.remove(studentWorker);
    });
    _saveAllData(); // Save all data when removing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "$studentWorker"'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildVendorsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Vendor List',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newVendorController,
                decoration: const InputDecoration(
                  labelText: 'Add new vendor',
                  border: OutlineInputBorder(),
                  hintText: 'Enter vendor name',
                ),
                onSubmitted: (_) => _addVendor(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _addVendor, child: const Text('Add')),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Current Vendors',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _vendors.isEmpty
              ? const Center(
                  child: Text(
                    'No vendors added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _vendors.length,
                  itemBuilder: (context, index) {
                    final vendor = _vendors[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Text(vendor),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeVendor(vendor),
                          tooltip: 'Remove vendor',
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetToDefaults,
            child: const Text('Reset to Defaults'),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Staff List',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newStaffController,
                decoration: const InputDecoration(
                  labelText: 'Add new staff member',
                  border: OutlineInputBorder(),
                  hintText: 'Enter staff name',
                ),
                onSubmitted: (_) => _addStaff(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _addStaff, child: const Text('Add')),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Current Staff',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _staff.isEmpty
              ? const Center(
                  child: Text(
                    'No staff members added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _staff.length,
                  itemBuilder: (context, index) {
                    final staff = _staff[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Text(staff),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeStaff(staff),
                          tooltip: 'Remove staff',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStudentWorkersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Student Workers List',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newStudentWorkerController,
                decoration: const InputDecoration(
                  labelText: 'Add new student worker',
                  border: OutlineInputBorder(),
                  hintText: 'Enter student worker name',
                ),
                onSubmitted: (_) => _addStudentWorker(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addStudentWorker,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Current Student Workers',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _studentWorkers.isEmpty
              ? const Center(
                  child: Text(
                    'No student workers added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _studentWorkers.length,
                  itemBuilder: (context, index) {
                    final studentWorker = _studentWorkers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Text(studentWorker),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeStudentWorker(studentWorker),
                          tooltip: 'Remove student worker',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        title: Text('Manage Paid To Options'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null) {
      return AlertDialog(
        title: const Text('Manage Paid To Options'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Center(child: Text(_errorMessage!)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Manage Paid To Options'),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            // Tab bar
            Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'Vendors'),
                  _buildTabButton(1, 'Staff'),
                  _buildTabButton(2, 'Students'),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: [
                _buildVendorsTab(),
                _buildStaffTab(),
                _buildStudentWorkersTab(),
              ][_currentTab],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label) {
    return Expanded(
      child: TextButton(
        onPressed: () {
          setState(() {
            _currentTab = index;
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.pressed) || _currentTab == index) {
              return Theme.of(context).primaryColor;
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.pressed) || _currentTab == index) {
              return Colors.white;
            }
            return Theme.of(context).textTheme.bodyLarge?.color;
          }),
        ),
        child: Text(label),
      ),
    );
  }

  @override
  void dispose() {
    _newVendorController.dispose();
    _newStaffController.dispose();
    _newStudentWorkerController.dispose();
    super.dispose();
  }
}
