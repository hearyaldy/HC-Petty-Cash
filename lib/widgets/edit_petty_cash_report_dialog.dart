import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/petty_cash_report.dart';

class EditPettyCashReportDialog extends StatefulWidget {
  final PettyCashReport report;

  const EditPettyCashReportDialog({
    super.key,
    required this.report,
  });

  @override
  State<EditPettyCashReportDialog> createState() =>
      _EditPettyCashReportDialogState();
}

class _EditPettyCashReportDialogState extends State<EditPettyCashReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _departmentController;
  late TextEditingController _openingBalanceController;
  late TextEditingController _companyNameController;
  late TextEditingController _notesController;
  late DateTime _periodStart;
  late DateTime _periodEnd;

  @override
  void initState() {
    super.initState();
    _departmentController =
        TextEditingController(text: widget.report.department);
    _openingBalanceController =
        TextEditingController(text: widget.report.openingBalance.toString());
    _companyNameController =
        TextEditingController(text: widget.report.companyName ?? '');
    _notesController = TextEditingController(text: widget.report.notes ?? '');
    _periodStart = widget.report.periodStart;
    _periodEnd = widget.report.periodEnd;
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _openingBalanceController.dispose();
    _companyNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _periodStart : _periodEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final updatedReport = widget.report.copyWith(
        department: _departmentController.text.trim(),
        openingBalance: double.parse(_openingBalanceController.text.trim()),
        companyName: _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        updatedAt: DateTime.now(),
      );
      Navigator.of(context).pop(updatedReport);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Report',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Report Number (Read-only)
              TextFormField(
                initialValue: widget.report.reportNumber,
                decoration: const InputDecoration(
                  labelText: 'Report Number',
                  border: OutlineInputBorder(),
                ),
                enabled: false,
              ),
              const SizedBox(height: 16),

              // Department
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department',
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

              // Opening Balance
              TextFormField(
                controller: _openingBalanceController,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance',
                  border: OutlineInputBorder(),
                  prefixText: '฿ ',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter opening balance';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Period Start and End
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Period Start',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(dateFormat.format(_periodStart)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Period End',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(dateFormat.format(_periodEnd)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Company Name (Optional)
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Notes (Optional)
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
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
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
