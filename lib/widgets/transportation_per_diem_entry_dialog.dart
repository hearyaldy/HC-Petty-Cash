import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transportation_request.dart';
import '../models/enums.dart';

class TransportationPerDiemEntryDialog extends StatefulWidget {
  final TransportationPerDiemEntry? entry; // null for new entry
  final TransportationRequest request;

  const TransportationPerDiemEntryDialog({
    super.key,
    this.entry,
    required this.request,
  });

  @override
  State<TransportationPerDiemEntryDialog> createState() =>
      _TransportationPerDiemEntryDialogState();
}

class _TransportationPerDiemEntryDialogState
    extends State<TransportationPerDiemEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late bool _hasBreakfast;
  late bool _hasLunch;
  late bool _hasSupper;
  late bool _hasIncidentMeal;

  double get _mealRate => widget.request.travelLocation.toTravelLocation().perDiemRate;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;

    _date = entry?.date ?? widget.request.travelDateTime;
    _hasBreakfast = entry?.hasBreakfast ?? false;
    _hasLunch = entry?.hasLunch ?? false;
    _hasSupper = entry?.hasSupper ?? false;
    _hasIncidentMeal = entry?.hasIncidentMeal ?? false;
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

  int get _mealsCount =>
      (_hasBreakfast ? 1 : 0) +
      (_hasLunch ? 1 : 0) +
      (_hasSupper ? 1 : 0) +
      (_hasIncidentMeal ? 1 : 0);

  double get _amount => _mealsCount * _mealRate;

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasBreakfast && !_hasLunch && !_hasSupper && !_hasIncidentMeal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one meal'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'date': _date,
      'hasBreakfast': _hasBreakfast,
      'hasLunch': _hasLunch,
      'hasSupper': _hasSupper,
      'hasIncidentMeal': _hasIncidentMeal,
      'mealRate': _mealRate,
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isNew = widget.entry == null;
    final travelLocation = widget.request.travelLocation.toTravelLocation();

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
                      isNew ? 'Add Per Diem Entry' : 'Edit Per Diem Entry',
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
                    'Travel Type: ${travelLocation.displayName} — ${currencyFormat.format(_mealRate)}฿/meal',
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
                const SizedBox(height: 20),

                // Meals Section
                const Text(
                  'Meals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Breakfast'),
                        subtitle: Text('${currencyFormat.format(_mealRate)}฿'),
                        value: _hasBreakfast,
                        onChanged: (value) => setState(() => _hasBreakfast = value ?? false),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: const Text('Lunch'),
                        subtitle: Text('${currencyFormat.format(_mealRate)}฿'),
                        value: _hasLunch,
                        onChanged: (value) => setState(() => _hasLunch = value ?? false),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: const Text('Supper'),
                        subtitle: Text('${currencyFormat.format(_mealRate)}฿'),
                        value: _hasSupper,
                        onChanged: (value) => setState(() => _hasSupper = value ?? false),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: const Text('Incident Meal'),
                        subtitle: Text('${currencyFormat.format(_mealRate)}฿'),
                        value: _hasIncidentMeal,
                        onChanged: (value) => setState(() => _hasIncidentMeal = value ?? false),
                      ),
                    ],
                  ),
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
                  child: Row(
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
