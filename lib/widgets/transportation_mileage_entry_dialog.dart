import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transportation_request.dart';
import '../models/enums.dart';

class TransportationMileageEntryDialog extends StatefulWidget {
  final TransportationMileageEntry? entry; // null for new entry
  final TransportationRequest request;

  const TransportationMileageEntryDialog({
    super.key,
    this.entry,
    required this.request,
  });

  @override
  State<TransportationMileageEntryDialog> createState() =>
      _TransportationMileageEntryDialogState();
}

class _TransportationMileageEntryDialogState
    extends State<TransportationMileageEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _mileageStartController;
  late TextEditingController _mileageEndController;
  late TextEditingController _remarkController;
  late DateTime _date;
  late TaxiAirport _selectedAirport;

  bool get _isTaxi => widget.request.vehicleType.toVehicleType().isFlatRate;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;

    _mileageStartController =
        TextEditingController(text: entry?.mileageStart.toString() ?? '0');
    _mileageEndController =
        TextEditingController(text: entry?.mileageEnd.toString() ?? '0');
    _remarkController = TextEditingController(text: entry?.remark ?? '');
    _date = entry?.date ?? widget.request.travelDateTime;
    _selectedAirport = entry?.airport?.toTaxiAirport() ?? TaxiAirport.suvarnabhumi;
  }

  @override
  void dispose() {
    _mileageStartController.dispose();
    _mileageEndController.dispose();
    _remarkController.dispose();
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

  double get _ratePerKm => widget.request.vehicleType.toVehicleType().ratePerKm;

  double get _totalKm {
    final start = double.tryParse(_mileageStartController.text) ?? 0.0;
    final end = double.tryParse(_mileageEndController.text) ?? 0.0;
    return end - start;
  }

  double get _amount => _isTaxi ? _selectedAirport.flatRate : _totalKm * _ratePerKm;

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_isTaxi) {
      Navigator.of(context).pop({
        'date': _date,
        'mileageStart': 0.0,
        'mileageEnd': 0.0,
        'ratePerKm': 0.0,
        'amount': _selectedAirport.flatRate,
        'airport': _selectedAirport.name,
        'remark': _remarkController.text.trim().isEmpty
            ? null
            : _remarkController.text.trim(),
      });
      return;
    }

    final start = double.parse(_mileageStartController.text.trim());
    final end = double.parse(_mileageEndController.text.trim());

    if (end < start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mileage end must be greater than or equal to mileage start'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'date': _date,
      'mileageStart': start,
      'mileageEnd': end,
      'ratePerKm': _ratePerKm,
      'amount': (end - start) * _ratePerKm,
      'airport': null,
      'remark': _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isNew = widget.entry == null;
    final vehicleType = widget.request.vehicleType.toVehicleType();

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
                      isNew ? 'Add Mileage Entry' : 'Edit Mileage Entry',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    _isTaxi
                        ? 'Vehicle: ${vehicleType.displayName} — flat rate by airport'
                        : 'Vehicle: ${vehicleType.displayName} — ${currencyFormat.format(_ratePerKm)}฿/km',
                    style: const TextStyle(fontSize: 13),
                  ),
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

                if (_isTaxi) ...[
                  // Airport (flat rate)
                  DropdownButtonFormField<TaxiAirport>(
                    initialValue: _selectedAirport,
                    decoration: const InputDecoration(
                      labelText: 'Destination Airport',
                      border: OutlineInputBorder(),
                    ),
                    items: TaxiAirport.values.map((airport) {
                      return DropdownMenuItem(
                        value: airport,
                        child: Text(
                          '${airport.displayName} — ฿${currencyFormat.format(airport.flatRate)}',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedAirport = value!),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Mileage Start
                  TextFormField(
                    controller: _mileageStartController,
                    decoration: const InputDecoration(
                      labelText: 'Mileage Start (KM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (_isTaxi) return null;
                      if (value == null || value.trim().isEmpty) return 'Required';
                      if (double.tryParse(value.trim()) == null) return 'Invalid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Mileage End
                  TextFormField(
                    controller: _mileageEndController,
                    decoration: const InputDecoration(
                      labelText: 'Mileage End (KM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (_isTaxi) return null;
                      if (value == null || value.trim().isEmpty) return 'Required';
                      if (double.tryParse(value.trim()) == null) return 'Invalid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Remark
                TextFormField(
                  controller: _remarkController,
                  decoration: const InputDecoration(
                    labelText: 'Remark (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Calculated Amount
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      if (!_isTaxi) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total KM:'),
                            Text(
                              currencyFormat.format(_totalKm),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount:'),
                          Text(
                            '฿${currencyFormat.format(_amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
