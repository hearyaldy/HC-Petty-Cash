import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/medical_bill_reimbursement.dart';
import '../../models/enums.dart';
import '../../models/user.dart';
import '../../providers/medical_bill_reimbursement_provider.dart';
import '../../utils/constants.dart';

class AddMedicalReimbursementDialog extends StatefulWidget {
  final User user;
  final MedicalBillReimbursement? existingReimbursement;

  const AddMedicalReimbursementDialog({
    super.key,
    required this.user,
    this.existingReimbursement,
  });

  @override
  State<AddMedicalReimbursementDialog> createState() =>
      _AddMedicalReimbursementDialogState();
}

class _AddMedicalReimbursementDialogState
    extends State<AddMedicalReimbursementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _departmentController = TextEditingController();
  final _paidToController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _reportDate = DateTime.now();
  List<MedicalClaimItem> _claimItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _departmentController.text = widget.user.department ?? '';

    if (widget.existingReimbursement != null) {
      final existing = widget.existingReimbursement!;
      _subjectController.text = existing.subject;
      _departmentController.text = existing.department;
      _paidToController.text = existing.paidTo ?? '';
      _notesController.text = existing.notes ?? '';
      _reportDate = existing.reportDate;
      _claimItems = List.from(existing.claimItems);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _departmentController.dispose();
    _paidToController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalBill =>
      _claimItems.fold(0.0, (sum, item) => sum + item.totalBill);

  double get _totalReimbursement =>
      _claimItems.fold(0.0, (sum, item) => sum + item.amountReimburse);

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReimbursement != null;
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_hospital, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Edit Medical Bill Reimbursement'
                          : 'New Medical Bill Reimbursement',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: widget.user.name,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              enabled: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(_reportDate),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter department';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.subject),
                          hintText: 'e.g., Medical expenses for treatment',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter subject';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _paidToController,
                        decoration: const InputDecoration(
                          labelText: 'Paid To',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance_wallet),
                          hintText: 'e.g., Hospital name, Clinic, Pharmacy',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Claim Items Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Medical Claim Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addClaimItem,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Item'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_claimItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'No claim items added yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Click "Add Item" to add medical claims',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _claimItems.length,
                          itemBuilder: (context, index) {
                            return _buildClaimItemCard(index);
                          },
                        ),

                      const SizedBox(height: 16),

                      // Summary
                      if (_claimItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Bill',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  Text(
                                    '${AppConstants.currencySymbol} ${currencyFormat.format(_totalBill)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total Reimbursement',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  Text(
                                    '${AppConstants.currencySymbol} ${currencyFormat.format(_totalReimbursement)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveReimbursement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditing ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimItemCard(int index) {
    final item = _claimItems[index];
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.claimTypeEnum == MedicalClaimType.outPatient
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  item.claimTypeEnum.shortName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: item.claimTypeEnum == MedicalClaimType.outPatient
                        ? Colors.blue
                        : Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Bill: ${AppConstants.currencySymbol} ${currencyFormat.format(item.totalBill)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Reimburse (${(item.claimTypeEnum.reimbursementRate * 100).toInt()}%): ${AppConstants.currencySymbol} ${currencyFormat.format(item.amountReimburse)}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editClaimItem(index),
              color: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _removeClaimItem(index),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _reportDate = picked;
      });
    }
  }

  void _addClaimItem() {
    _showClaimItemDialog();
  }

  void _editClaimItem(int index) {
    _showClaimItemDialog(existingItem: _claimItems[index], index: index);
  }

  void _removeClaimItem(int index) {
    setState(() {
      _claimItems.removeAt(index);
    });
  }

  void _showClaimItemDialog({MedicalClaimItem? existingItem, int? index}) {
    final descController = TextEditingController(text: existingItem?.description ?? '');
    final amountController = TextEditingController(
      text: existingItem?.totalBill.toString() ?? '',
    );
    MedicalClaimType claimType = existingItem?.claimTypeEnum ?? MedicalClaimType.outPatient;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingItem != null ? 'Edit Claim Item' : 'Add Claim Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Doctor consultation, Medicine',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MedicalClaimType>(
                value: claimType,
                decoration: const InputDecoration(
                  labelText: 'Claim Type',
                  border: OutlineInputBorder(),
                ),
                items: MedicalClaimType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: type == MedicalClaimType.outPatient
                                ? Colors.blue.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type.shortName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: type == MedicalClaimType.outPatient
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${type.displayName} - ${(type.reimbursementRate * 100).toInt()}%'),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      claimType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Total Bill Amount',
                  border: const OutlineInputBorder(),
                  prefixText: '${AppConstants.currencySymbol} ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (descController.text.isNotEmpty &&
                    amountController.text.isNotEmpty) {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  final newItem = MedicalClaimItem(
                    id: existingItem?.id ?? const Uuid().v4(),
                    description: descController.text,
                    claimType: claimType.name,
                    totalBill: amount,
                  );

                  setState(() {
                    if (index != null) {
                      _claimItems[index] = newItem;
                    } else {
                      _claimItems.add(newItem);
                    }
                  });

                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text(existingItem != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveReimbursement() async {
    if (!_formKey.currentState!.validate()) return;

    if (_claimItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one claim item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<MedicalBillReimbursementProvider>();

      if (widget.existingReimbursement != null) {
        // Update existing
        final updated = widget.existingReimbursement!.copyWith(
          department: _departmentController.text.trim(),
          subject: _subjectController.text.trim(),
          reportDate: _reportDate,
          claimItems: _claimItems,
          paidTo: _paidToController.text.trim().isEmpty ? null : _paidToController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        ).recalculateTotals();

        await provider.updateReimbursement(updated);

        if (mounted) {
          Navigator.of(context).pop(updated);
        }
      } else {
        // Create new
        final result = await provider.createReimbursement(
          requester: widget.user,
          department: _departmentController.text.trim(),
          subject: _subjectController.text.trim(),
          claimItems: _claimItems,
          reportDate: _reportDate,
          paidTo: _paidToController.text.trim().isEmpty ? null : _paidToController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        if (mounted) {
          if (result != null) {
            Navigator.of(context).pop(result);
          } else {
            // Show error if creation failed
            final errorMessage = provider.errorMessage ?? 'Failed to create medical reimbursement';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
