import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/equipment.dart';
import '../../services/equipment_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final String equipmentId;

  const EquipmentDetailScreen({super.key, required this.equipmentId});

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen>
    with SingleTickerProviderStateMixin {
  final EquipmentService _equipmentService = EquipmentService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.canManageUsers();

    return StreamBuilder<List<Equipment>>(
      stream: _equipmentService.getAllEquipment(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Equipment Details')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Equipment Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final equipment = snapshot.data?.firstWhere(
          (e) => e.id == widget.equipmentId,
          orElse: () => throw Exception('Equipment not found'),
        );

        if (equipment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Equipment Details')),
            body: const Center(child: Text('Equipment not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(equipment.name),
            elevation: ResponsiveHelper.isDesktop(context) ? 1 : 0,
            actions: [
              if (isAdmin) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      context.push('/inventory/edit/${equipment.id}'),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmDelete(equipment),
                  tooltip: 'Delete',
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.info), text: 'Details'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailsTab(equipment),
              _buildHistoryTab(equipment),
            ],
          ),
          floatingActionButton: _buildActionButton(equipment),
        );
      },
    );
  }

  Widget? _buildActionButton(Equipment equipment) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (equipment.status == EquipmentStatus.available) {
      return FloatingActionButton.extended(
        onPressed: () => _showCheckoutDialog(equipment),
        icon: const Icon(Icons.output),
        label: const Text('Check Out'),
        backgroundColor: Colors.orange,
      );
    } else if (equipment.status == EquipmentStatus.checkedOut) {
      // Only the person who checked it out or admin can check it in
      final canCheckIn =
          authProvider.canManageUsers() ||
          equipment.currentHolderId == user?.id;
      if (canCheckIn) {
        return FloatingActionButton.extended(
          onPressed: () => _showCheckInDialog(equipment),
          icon: const Icon(Icons.input),
          label: const Text('Check In'),
          backgroundColor: Colors.green,
        );
      }
    }
    return null;
  }

  Widget _buildDetailsTab(Equipment equipment) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'THB ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: ResponsiveHelper.getScreenPadding(context),
      child: ResponsiveHelper.isDesktop(context)
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _buildDetailsContent(
                  equipment,
                  currencyFormat,
                  dateFormat,
                ),
              ),
            )
          : _buildDetailsContent(equipment, currencyFormat, dateFormat),
    );
  }

  Widget _buildDetailsContent(
    Equipment equipment,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(equipment, currencyFormat),
        const SizedBox(height: 16),
        if (equipment.isCheckedOut)
          _buildCurrentCheckoutCard(equipment, dateFormat),
        if (equipment.isCheckedOut) const SizedBox(height: 16),
        ResponsiveHelper.isDesktop(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSpecificationsCard(equipment)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPurchaseInfoCard(
                      equipment,
                      currencyFormat,
                      dateFormat,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildSpecificationsCard(equipment),
                  const SizedBox(height: 16),
                  _buildPurchaseInfoCard(equipment, currencyFormat, dateFormat),
                ],
              ),
        if (equipment.notes != null && equipment.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildNotesCard(equipment),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderCard(Equipment equipment, NumberFormat currencyFormat) {
    final statusColor = _getStatusColor(equipment.status);
    final conditionColor = _getConditionColor(equipment.condition);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              _getCategoryColor(equipment.category).withOpacity(0.1),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(
                      equipment.category,
                    ).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getCategoryIcon(equipment.category),
                    size: 48,
                    color: _getCategoryColor(equipment.category),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (equipment.brand != null || equipment.model != null)
                        Text(
                          '${equipment.brand ?? ''} ${equipment.model ?? ''}'
                              .trim(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(
                            equipment.category,
                            _getCategoryColor(equipment.category),
                            Icons.category,
                          ),
                          _buildChip(
                            equipment.status.displayName,
                            statusColor,
                            Icons.info,
                          ),
                          _buildChip(
                            equipment.condition.displayName,
                            conditionColor,
                            Icons.star,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (equipment.purchasePrice != null) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Asset Value',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    currencyFormat.format(equipment.purchasePrice),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCheckoutCard(Equipment equipment, DateFormat dateFormat) {
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                color: Colors.orange.shade700,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currently Checked Out',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    equipment.currentHolderName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.orange.shade300,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificationsCard(Equipment equipment) {
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
                Icon(Icons.settings, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Specifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (equipment.serialNumber != null)
              _buildInfoRow('Serial Number', equipment.serialNumber!),
            if (equipment.assetTag != null)
              _buildInfoRow('Asset Tag', equipment.assetTag!),
            if (equipment.location != null)
              _buildInfoRow('Location', equipment.location!),
            if (equipment.description != null)
              _buildInfoRow('Description', equipment.description!),
            if (equipment.serialNumber == null &&
                equipment.assetTag == null &&
                equipment.location == null &&
                equipment.description == null)
              Text(
                'No specifications available',
                style: TextStyle(color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseInfoCard(
    Equipment equipment,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
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
                Icon(Icons.receipt_long, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Purchase Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (equipment.purchaseDate != null)
              _buildInfoRow(
                'Purchase Date',
                dateFormat.format(equipment.purchaseDate!),
              ),
            if (equipment.supplier != null)
              _buildInfoRow('Supplier', equipment.supplier!),
            if (equipment.warrantyExpiry != null)
              _buildInfoRow(
                'Warranty Until',
                dateFormat.format(equipment.warrantyExpiry!),
                isWarrantyExpired: equipment.warrantyExpiry!.isBefore(
                  DateTime.now(),
                ),
              ),
            _buildInfoRow('Created', dateFormat.format(equipment.createdAt)),
            if (equipment.updatedAt != null)
              _buildInfoRow(
                'Last Updated',
                dateFormat.format(equipment.updatedAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(Equipment equipment) {
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
                Icon(Icons.note, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(equipment.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isWarrantyExpired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isWarrantyExpired ? Colors.red : null,
              ),
            ),
          ),
          if (isWarrantyExpired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Expired',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Equipment equipment) {
    return StreamBuilder<List<EquipmentCheckout>>(
      stream: _equipmentService.getEquipmentCheckoutHistory(equipment.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final checkouts = snapshot.data ?? [];

        if (checkouts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No checkout history',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: checkouts.length,
          itemBuilder: (context, index) {
            return _buildCheckoutHistoryItem(checkouts[index]);
          },
        );
      },
    );
  }

  Widget _buildCheckoutHistoryItem(EquipmentCheckout checkout) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: checkout.isReturned
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    checkout.isReturned ? Icons.check : Icons.schedule,
                    color: checkout.isReturned
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkout.checkedOutByName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        checkout.isReturned
                            ? 'Returned'
                            : 'Currently has equipment',
                        style: TextStyle(
                          color: checkout.isReturned
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        checkout.conditionAtCheckout ==
                            EquipmentCondition.excellent
                        ? Colors.green.shade50
                        : checkout.conditionAtCheckout ==
                              EquipmentCondition.good
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    checkout.conditionAtCheckout.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          checkout.conditionAtCheckout ==
                              EquipmentCondition.excellent
                          ? Colors.green.shade700
                          : checkout.conditionAtCheckout ==
                                EquipmentCondition.good
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checked Out',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        dateFormat.format(checkout.checkedOutAt),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (checkout.isReturned)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Returned',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          dateFormat.format(checkout.returnedAt!),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (checkout.purpose != null && checkout.purpose!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Purpose: ${checkout.purpose}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCheckoutDialog(Equipment equipment) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final purposeController = TextEditingController();
    DateTime? expectedReturn;
    EquipmentCondition selectedCondition = equipment.condition;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.output, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Check Out Equipment'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checking out: ${equipment.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'To: ${user?.name ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EquipmentCondition>(
                  value: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Current Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: EquipmentCondition.values.map((condition) {
                    return DropdownMenuItem(
                      value: condition,
                      child: Text(condition.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCondition = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose (optional)',
                    hintText: 'e.g., Studio shoot',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => expectedReturn = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expected Return (optional)',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      expectedReturn != null
                          ? DateFormat('dd MMM yyyy').format(expectedReturn!)
                          : 'Select date',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _equipmentService.checkOutEquipment(
                    equipmentId: equipment.id,
                    userId: user?.id ?? '',
                    userName: user?.name ?? 'Unknown',
                    purpose: purposeController.text.trim().isEmpty
                        ? null
                        : purposeController.text.trim(),
                    expectedReturnDate: expectedReturn,
                    conditionAtCheckout: selectedCondition,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Equipment checked out successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Check Out'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckInDialog(Equipment equipment) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final notesController = TextEditingController();
    EquipmentCondition selectedCondition = equipment.condition;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.input, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Check In Equipment'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Returning: ${equipment.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'From: ${equipment.currentHolderName ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EquipmentCondition>(
                  value: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Condition at Return',
                    border: OutlineInputBorder(),
                  ),
                  items: EquipmentCondition.values.map((condition) {
                    return DropdownMenuItem(
                      value: condition,
                      child: Text(condition.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCondition = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g., Any issues or damage',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _equipmentService.checkInEquipment(
                    equipmentId: equipment.id,
                    checkoutId: equipment.currentCheckoutId!,
                    returnedBy: user?.id ?? '',
                    returnedByName: user?.name ?? 'Unknown',
                    conditionAtReturn: selectedCondition,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Equipment checked in successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Check In'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Equipment'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${equipment.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _equipmentService.deleteEquipment(equipment.id);
                if (mounted) {
                  Navigator.pop(context);
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Equipment deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'camera':
        return Colors.blue;
      case 'lens':
        return Colors.purple;
      case 'audio':
        return Colors.pink;
      case 'lighting':
        return Colors.amber;
      case 'tripod & support':
        return Colors.brown;
      case 'computer':
        return Colors.indigo;
      case 'monitor & display':
        return Colors.cyan;
      case 'storage & media':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'camera':
        return Icons.camera_alt;
      case 'lens':
        return Icons.camera;
      case 'audio':
        return Icons.mic;
      case 'lighting':
        return Icons.light_mode;
      case 'tripod & support':
        return Icons.control_camera;
      case 'computer':
        return Icons.computer;
      case 'monitor & display':
        return Icons.monitor;
      case 'storage & media':
        return Icons.sd_card;
      default:
        return Icons.inventory_2;
    }
  }
}
