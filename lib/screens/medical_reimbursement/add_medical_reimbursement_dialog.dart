import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/adcom_minutes.dart';
import '../../models/medical_bill_reimbursement.dart';
import '../../models/enums.dart';
import '../../models/staff.dart';
import '../../models/user.dart';
import '../../providers/medical_bill_reimbursement_provider.dart';
import '../../services/adcom_minutes_service.dart';
import '../../services/staff_service.dart';
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
  final _staffService = StaffService();
  final _minutesService = AdcomMinutesService();
  final _formKey = GlobalKey<FormState>();
  final _requesterNameController = TextEditingController();
  final _requesterFocusNode = FocusNode();
  final _subjectController = TextEditingController();
  final _departmentController = TextEditingController();
  final _paidToController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _reportDate = DateTime.now();
  List<MedicalClaimItem> _claimItems = [];
  bool _isLoading = false;
  Staff? _selectedRequester; // set when a staff is picked from autocomplete

  // Meeting reference
  String? _linkedMinutesId;
  String? _linkedMinutesLabel;
  String? _linkedActionItemNumber;
  String? _linkedActionItemTitle;
  String? _linkedActionItemDescription;
  String? _linkedActionItemAction;

  @override
  void initState() {
    super.initState();
    _requesterNameController.text = widget.user.name;
    _departmentController.text = widget.user.department;
    // Clear the resolved staff if the name is typed manually after selection
    _requesterNameController.addListener(() {
      if (_selectedRequester != null &&
          _requesterNameController.text.trim() !=
              _selectedRequester!.fullName) {
        _selectedRequester = null;
      }
    });

    if (widget.existingReimbursement != null) {
      final existing = widget.existingReimbursement!;
      _requesterNameController.text = existing.requesterName;
      _subjectController.text = existing.subject;
      _departmentController.text = existing.department;
      _paidToController.text = existing.paidTo ?? '';
      _notesController.text = existing.notes ?? '';
      _reportDate = existing.reportDate;
      _claimItems = List.from(existing.claimItems);
      _linkedMinutesId = existing.linkedMinutesId;
      _linkedMinutesLabel = existing.linkedMinutesLabel;
      _linkedActionItemNumber = existing.linkedActionItemNumber;
      _linkedActionItemTitle = existing.linkedActionItemTitle;
      _linkedActionItemDescription = existing.linkedActionItemDescription;
      _linkedActionItemAction = existing.linkedActionItemAction;
    }
  }

  @override
  void dispose() {
    _requesterNameController.dispose();
    _requesterFocusNode.dispose();
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

  bool get _canSelectRequester =>
      widget.user.roleEnum == UserRole.admin ||
      widget.user.roleEnum == UserRole.manager ||
      widget.user.roleEnum == UserRole.finance;

  Widget _buildRequesterNameField() {
    if (!_canSelectRequester) {
      return TextFormField(
        controller: _requesterNameController,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person),
        ),
        validator: _validateRequesterName,
      );
    }

    return StreamBuilder<List<Staff>>(
      stream: _staffService.getAllStaff(),
      builder: (context, snapshot) {
        final staffList = snapshot.data ?? const <Staff>[];
        if (staffList.isEmpty) {
          return TextFormField(
            controller: _requesterNameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
              suffixIcon: snapshot.connectionState == ConnectionState.waiting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            validator: _validateRequesterName,
          );
        }

        return RawAutocomplete<Staff>(
          textEditingController: _requesterNameController,
          focusNode: _requesterFocusNode,
          displayStringForOption: (staff) => staff.fullName,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) {
              return staffList.take(8);
            }
            return staffList
                .where((staff) {
                  return staff.fullName.toLowerCase().contains(query) ||
                      staff.employeeId.toLowerCase().contains(query) ||
                      staff.department.toLowerCase().contains(query) ||
                      staff.position.toLowerCase().contains(query);
                })
                .take(12);
          },
          onSelected: (staff) {
            setState(() {
              _selectedRequester = staff;
              _requesterNameController.text = staff.fullName;
              _departmentController.text = staff.department;
            });
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  validator: _validateRequesterName,
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 330,
                    maxHeight: 280,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final staff = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(staff.fullName),
                        subtitle: Text(
                          [
                            if (staff.employeeId.isNotEmpty) staff.employeeId,
                            if (staff.department.isNotEmpty) staff.department,
                            if (staff.position.isNotEmpty) staff.position,
                          ].join(' · '),
                        ),
                        onTap: () => onSelected(staff),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _validateRequesterName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter name';
    }
    return null;
  }

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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 28,
                  ),
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
                          Expanded(child: _buildRequesterNameField()),
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
                                Icon(
                                  Icons.receipt_long,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No claim items added yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Click "Add Item" to add medical claims',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
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
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
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
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
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
                      const SizedBox(height: 16),

                      // Meeting Reference
                      const Text(
                        'Meeting Reference (Optional)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _buildMinutesReferenceTile(),
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
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
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
    final descController = TextEditingController(
      text: existingItem?.description ?? '',
    );
    final amountController = TextEditingController(
      text: existingItem?.totalBill.toString() ?? '',
    );
    MedicalClaimCategory claimCategory =
        existingItem?.claimCategoryEnum ??
        MedicalClaimCategory.outpatientGeneral;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existingItem != null ? 'Edit Claim Item' : 'Add Claim Item',
          ),
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
              DropdownButtonFormField<MedicalClaimCategory>(
                initialValue: claimCategory,
                decoration: const InputDecoration(
                  labelText: 'Claim Category',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: MedicalClaimCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(
                      cat.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => claimCategory = value);
                  }
                },
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: claimCategory.isInpatient
                      ? Colors.orange.withValues(alpha: 0.08)
                      : Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      claimCategory.isInpatient
                          ? Icons.local_hospital_outlined
                          : Icons.medical_services_outlined,
                      size: 14,
                      color: claimCategory.isInpatient
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${claimCategory.isInpatient ? "In Patient" : "Out Patient"} · '
                      '${(claimCategory.reimbursementRate * 100).toInt()}% reimbursed · '
                      '${claimCategory.limitDescription}',
                      style: TextStyle(
                        fontSize: 11,
                        color: claimCategory.isInpatient
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Total Bill Amount',
                  border: const OutlineInputBorder(),
                  prefixText: '${AppConstants.currencySymbol} ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                    claimType: claimCategory.claimType,
                    claimCategory: claimCategory.name,
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

  Future<void> _pickMinutesReference() async {
    setState(() => _isLoading = true);
    List<AdcomMinutes> minutesList = [];
    try {
      minutesList = await _minutesService.getMinutes().first;
    } catch (_) {}
    setState(() => _isLoading = false);
    if (!mounted) return;

    final AdcomMinutes? selectedMinutes = await showDialog<AdcomMinutes>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Meeting Minutes'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: minutesList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No meeting minutes found.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: minutesList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = minutesList[index];
                    final dateStr = DateFormat('MMM dd, yyyy').format(m.meetingDate);
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                        child: Icon(Icons.article_outlined, size: 20, color: Colors.teal.shade600),
                      ),
                      title: Text('ADCOM – $dateStr', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(m.location, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: m.status == 'finalized' ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: m.status == 'finalized' ? Colors.green.shade200 : Colors.orange.shade200),
                        ),
                        child: Text(
                          m.status.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: m.status == 'finalized' ? Colors.green[700] : Colors.orange[700]),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, m),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
    if (selectedMinutes == null || !mounted) return;

    final MinutesItem? selectedItem = await showDialog<MinutesItem>(
      context: context,
      builder: (context) {
        final items = selectedMinutes.minutesItems;
        final dateStr = DateFormat('MMM dd, yyyy').format(selectedMinutes.meetingDate);
        return AlertDialog(
          title: Text('ADCOM – $dateStr'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: items.isEmpty
                ? const Padding(padding: EdgeInsets.all(20), child: Text('No action items in this minutes.'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
                          child: Text(item.itemNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                        ),
                        title: Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: item.resolution != null
                            ? Text(item.resolution!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          ],
        );
      },
    );
    if (selectedItem == null || !mounted) return;

    final dateStr = DateFormat('MMM dd, yyyy').format(selectedMinutes.meetingDate);
    setState(() {
      _linkedMinutesId = selectedMinutes.id;
      _linkedMinutesLabel = 'ADCOM – $dateStr';
      _linkedActionItemNumber = selectedItem.itemNumber;
      _linkedActionItemTitle = selectedItem.title;
      _linkedActionItemDescription = selectedItem.description;
      _linkedActionItemAction = selectedItem.status.displayName;
    });
  }

  Widget _buildMinutesReferenceTile() {
    final hasReference = _linkedMinutesId != null;
    return InkWell(
      onTap: _pickMinutesReference,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: hasReference ? Colors.teal.shade300 : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
          color: hasReference ? Colors.teal.shade50 : null,
        ),
        child: Row(
          children: [
            Icon(Icons.article_outlined, color: hasReference ? Colors.teal : Colors.grey[500], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: hasReference
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_linkedMinutesLabel!, style: TextStyle(fontSize: 12, color: Colors.teal[600])),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text(_linkedActionItemNumber!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[700])),
                            ),
                            if (_linkedActionItemAction != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.teal.shade200)),
                                child: Text(_linkedActionItemAction!, style: TextStyle(fontSize: 11, color: Colors.teal[700])),
                              ),
                            ],
                          ],
                        ),
                        if (_linkedActionItemTitle != null) ...[
                          const SizedBox(height: 4),
                          Text(_linkedActionItemTitle!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                        if (_linkedActionItemDescription != null && _linkedActionItemDescription!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(_plainText(_linkedActionItemDescription!), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Link to Meeting Minutes', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
                        Text('Tap to select minutes & action item', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
            ),
            if (hasReference)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                color: Colors.grey[500],
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () => setState(() {
                  _linkedMinutesId = null;
                  _linkedMinutesLabel = null;
                  _linkedActionItemNumber = null;
                  _linkedActionItemTitle = null;
                  _linkedActionItemDescription = null;
                  _linkedActionItemAction = null;
                }),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  String _plainText(String text) {
    if (text.startsWith('[')) {
      try {
        final ops = jsonDecode(text) as List;
        return ops.whereType<Map>().map((op) => op['insert']).whereType<String>().join().trim();
      } catch (_) {}
    }
    return text;
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

      // Approver roles may file on behalf of another staff member. Regular
      // staff always create and edit their own reimbursement.
      final resolvedRequesterId = _canSelectRequester
          ? _selectedRequester?.userId ?? _selectedRequester?.id
          : null;

      if (widget.existingReimbursement != null) {
        // Update existing
        final updated = widget.existingReimbursement!
            .copyWith(
              requesterId:
                  resolvedRequesterId ??
                  widget.existingReimbursement!.requesterId,
              requesterName: _canSelectRequester
                  ? _requesterNameController.text.trim()
                  : widget.existingReimbursement!.requesterName,
              department: _departmentController.text.trim(),
              subject: _subjectController.text.trim(),
              reportDate: _reportDate,
              claimItems: _claimItems,
              paidTo: _paidToController.text.trim().isEmpty
                  ? null
                  : _paidToController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              linkedMinutesId: _linkedMinutesId,
              linkedMinutesLabel: _linkedMinutesLabel,
              linkedActionItemNumber: _linkedActionItemNumber,
              linkedActionItemTitle: _linkedActionItemTitle,
              linkedActionItemDescription: _linkedActionItemDescription,
              linkedActionItemAction: _linkedActionItemAction,
            )
            .recalculateTotals();

        await provider.updateReimbursement(updated);

        if (mounted) {
          Navigator.of(context).pop(updated);
        }
      } else {
        // Create new
        final result = await provider.createReimbursement(
          requester: widget.user,
          requesterName: _canSelectRequester
              ? _requesterNameController.text.trim()
              : widget.user.name,
          overrideRequesterId: resolvedRequesterId,
          department: _departmentController.text.trim(),
          subject: _subjectController.text.trim(),
          claimItems: _claimItems,
          reportDate: _reportDate,
          paidTo: _paidToController.text.trim().isEmpty
              ? null
              : _paidToController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          linkedMinutesId: _linkedMinutesId,
          linkedMinutesLabel: _linkedMinutesLabel,
          linkedActionItemNumber: _linkedActionItemNumber,
          linkedActionItemTitle: _linkedActionItemTitle,
          linkedActionItemDescription: _linkedActionItemDescription,
          linkedActionItemAction: _linkedActionItemAction,
        );

        if (mounted) {
          if (result != null) {
            Navigator.of(context).pop(result);
          } else {
            // Show error if creation failed
            final errorMessage =
                provider.errorMessage ??
                'Failed to create medical reimbursement';
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
