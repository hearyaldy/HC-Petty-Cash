import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/purchase_requisition.dart';

class EditPurchaseRequisitionDialog extends StatefulWidget {
  final PurchaseRequisition? requisition; // null for new requisition
  final String requesterId;
  final String requesterName;

  const EditPurchaseRequisitionDialog({
    super.key,
    this.requisition,
    required this.requesterId,
    required this.requesterName,
  });

  @override
  State<EditPurchaseRequisitionDialog> createState() =>
      _EditPurchaseRequisitionDialogState();
}

class _EditPurchaseRequisitionDialogState
    extends State<EditPurchaseRequisitionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _requestedByController;
  late TextEditingController _idNoController;
  late TextEditingController _departmentController;
  late TextEditingController _notesController;
  late DateTime _requisitionDate;

  @override
  void initState() {
    super.initState();
    final requisition = widget.requisition;

    _requestedByController = TextEditingController(
      text: requisition?.requestedBy ?? widget.requesterName,
    );
    _idNoController = TextEditingController(
      text: requisition?.idNo ?? '',
    );
    _departmentController = TextEditingController(
      text: requisition?.chargeToDepartment ?? '',
    );
    _notesController = TextEditingController(
      text: requisition?.notes ?? '',
    );

    _requisitionDate = requisition?.requisitionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _requestedByController.dispose();
    _idNoController.dispose();
    _departmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _requisitionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _requisitionDate = picked;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final result = {
        'requisitionDate': _requisitionDate,
        'requestedBy': _requestedByController.text.trim(),
        'idNo': _idNoController.text.trim(),
        'chargeToDepartment': _departmentController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isNew = widget.requisition == null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isNew
                          ? 'New Purchase Requisition'
                          : 'Edit Purchase Requisition',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Requisition Number (Read-only for existing requisitions)
                if (!isNew)
                  Column(
                    children: [
                      TextFormField(
                        initialValue: widget.requisition!.requisitionNumber,
                        decoration: const InputDecoration(
                          labelText: 'Requisition Number',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Requisition Date
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(dateFormat.format(_requisitionDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // Requested By
                TextFormField(
                  controller: _requestedByController,
                  decoration: const InputDecoration(
                    labelText: 'Requested By',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter requester name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ID No
                TextFormField(
                  controller: _idNoController,
                  decoration: const InputDecoration(
                    labelText: 'ID No.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter ID number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Charge to Department
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Charge to Department',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter department';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Notes (Optional)
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isNew ? 'Create' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
