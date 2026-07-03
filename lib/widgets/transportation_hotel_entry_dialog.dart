import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transportation_request.dart';

class TransportationHotelEntryDialog extends StatefulWidget {
  final TransportationHotelEntry? entry; // null for new entry
  final TransportationRequest request;

  const TransportationHotelEntryDialog({
    super.key,
    this.entry,
    required this.request,
  });

  @override
  State<TransportationHotelEntryDialog> createState() =>
      _TransportationHotelEntryDialogState();
}

class _TransportationHotelEntryDialogState
    extends State<TransportationHotelEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hotelNameController;
  late TextEditingController _amountController;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;

    _hotelNameController = TextEditingController(text: entry?.hotelName ?? '');
    _amountController =
        TextEditingController(text: entry?.amount.toString() ?? '0');
    _date = entry?.date ?? widget.request.travelDateTime;
  }

  @override
  void dispose() {
    _hotelNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop({
      'date': _date,
      'hotelName': _hotelNameController.text.trim(),
      'amount': double.parse(_amountController.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final isNew = widget.entry == null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
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
                      isNew ? 'Add Hotel Entry' : 'Edit Hotel Entry',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(dateFormat.format(_date)),
                  ),
                ),
                const SizedBox(height: 16),

                // Hotel name
                TextFormField(
                  controller: _hotelNameController,
                  decoration: const InputDecoration(
                    labelText: 'Room / Hotel',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter hotel/room name' : null,
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (฿)',
                    prefixText: '฿ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    final n = double.tryParse(value.trim());
                    if (n == null || n <= 0) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

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
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isNew ? 'Add' : 'Save'),
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
