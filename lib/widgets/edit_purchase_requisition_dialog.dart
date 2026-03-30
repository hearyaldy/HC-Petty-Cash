import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/purchase_requisition.dart';
import '../models/adcom_minutes.dart';
import '../services/adcom_minutes_service.dart';

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
  late TextEditingController _purchaseReasonController;
  late TextEditingController _actionNoController;
  late TextEditingController _notesController;
  late DateTime _requisitionDate;

  // Meeting reference
  String? _linkedMinutesId;
  String? _linkedMinutesLabel;
  String? _linkedActionItemNumber;
  String? _linkedActionItemTitle;
  String? _linkedActionItemDescription;
  String? _linkedActionItemAction;

  final _minutesService = AdcomMinutesService();
  final _dateFormat = DateFormat('MMM dd, yyyy');

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
    _purchaseReasonController = TextEditingController(
      text: requisition?.purchaseReason ?? '',
    );
    _actionNoController = TextEditingController(
      text: requisition?.actionNo ?? '',
    );
    _notesController = TextEditingController(
      text: requisition?.notes ?? '',
    );

    _requisitionDate = requisition?.requisitionDate ?? DateTime.now();

    _linkedMinutesId = requisition?.linkedMinutesId;
    _linkedMinutesLabel = requisition?.linkedMinutesLabel;
    _linkedActionItemNumber = requisition?.linkedActionItemNumber;
    _linkedActionItemTitle = requisition?.linkedActionItemTitle;
    _linkedActionItemDescription = requisition?.linkedActionItemDescription;
    _linkedActionItemAction = requisition?.linkedActionItemAction;
  }

  Future<void> _pickMinutesReference() async {
    final allMinutes = await _minutesService.getMinutes().first;
    if (!mounted) return;

    final AdcomMinutes? selectedMinutes = await showDialog<AdcomMinutes>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Meeting Minutes'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: allMinutes.isEmpty
              ? const Center(child: Text('No minutes available'))
              : ListView.builder(
                  itemCount: allMinutes.length,
                  itemBuilder: (_, i) {
                    final m = allMinutes[i];
                    return ListTile(
                      title: Text('ADCOM \u2013 ${_dateFormat.format(m.meetingDate)}'),
                      subtitle: Text(m.organization),
                      onTap: () => Navigator.pop(ctx, m),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selectedMinutes == null || !mounted) return;

    final MinutesItem? selectedItem = await showDialog<MinutesItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Action Item'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: selectedMinutes.minutesItems.isEmpty
              ? const Center(child: Text('No action items'))
              : ListView.builder(
                  itemCount: selectedMinutes.minutesItems.length,
                  itemBuilder: (_, i) {
                    final item = selectedMinutes.minutesItems[i];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          item.itemNumber,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ),
                      title: Text(item.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: item.resolution != null
                          ? Text(item.resolution!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                          : null,
                      onTap: () => Navigator.pop(ctx, item),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
        ],
      ),
    );
    if (selectedItem == null || !mounted) return;

    setState(() {
      _linkedMinutesId = selectedMinutes.id;
      _linkedMinutesLabel = 'ADCOM \u2013 ${_dateFormat.format(selectedMinutes.meetingDate)}';
      _linkedActionItemNumber = selectedItem.itemNumber;
      _linkedActionItemTitle = selectedItem.title;
      _linkedActionItemDescription = selectedItem.description;
      _linkedActionItemAction = selectedItem.status.displayName;
    });
  }

  @override
  void dispose() {
    _requestedByController.dispose();
    _idNoController.dispose();
    _departmentController.dispose();
    _purchaseReasonController.dispose();
    _actionNoController.dispose();
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
        'purchaseReason': _purchaseReasonController.text.trim().isEmpty
            ? null
            : _purchaseReasonController.text.trim(),
        'actionNo': _actionNoController.text.trim().isEmpty
            ? null
            : _actionNoController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'linkedMinutesId': _linkedMinutesId,
        'linkedMinutesLabel': _linkedMinutesLabel,
        'linkedActionItemNumber': _linkedActionItemNumber,
        'linkedActionItemTitle': _linkedActionItemTitle,
        'linkedActionItemDescription': _linkedActionItemDescription,
        'linkedActionItemAction': _linkedActionItemAction,
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

                // Purchase Reason
                TextFormField(
                  controller: _purchaseReasonController,
                  decoration: const InputDecoration(
                    labelText: 'Purchase Reason',
                    border: OutlineInputBorder(),
                    hintText: 'Why is this purchase needed?',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter purchase reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Action No (Optional - for amounts > 20,000 Baht)
                TextFormField(
                  controller: _actionNoController,
                  decoration: InputDecoration(
                    labelText: 'Action No. (Optional)',
                    border: const OutlineInputBorder(),
                    hintText: 'Required for amounts > 20,000 Baht',
                    helperText: 'Enter action number if applicable',
                    helperStyle: TextStyle(color: Colors.orange.shade700),
                  ),
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
                const SizedBox(height: 16),

                // Meeting Reference
                InkWell(
                  onTap: _pickMinutesReference,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _linkedMinutesId != null
                            ? Colors.indigo.shade300
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: _linkedMinutesId != null ? Colors.indigo.shade50 : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          color: _linkedMinutesId != null ? Colors.indigo : Colors.grey[500],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _linkedMinutesId != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _linkedMinutesLabel ?? '',
                                      style: TextStyle(fontSize: 12, color: Colors.indigo[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _linkedActionItemNumber ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo[700],
                                            ),
                                          ),
                                        ),
                                        if (_linkedActionItemAction != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.teal.shade200),
                                            ),
                                            child: Text(
                                              _linkedActionItemAction!,
                                              style: TextStyle(fontSize: 11, color: Colors.teal[700]),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (_linkedActionItemTitle != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _linkedActionItemTitle!,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Link to Meeting Minutes',
                                      style: TextStyle(fontSize: 15, color: Colors.grey[500]),
                                    ),
                                    Text(
                                      'Tap to select minutes & action item',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                        ),
                        if (_linkedMinutesId != null)
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
                        backgroundColor: Colors.blue,
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
