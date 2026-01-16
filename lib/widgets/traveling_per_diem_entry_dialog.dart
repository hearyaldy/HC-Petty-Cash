import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/traveling_per_diem_entry.dart';
import '../models/traveling_report.dart';

class TravelingPerDiemEntryDialog extends StatefulWidget {
  final TravelingPerDiemEntry? entry; // null for new entry
  final TravelingReport report;

  const TravelingPerDiemEntryDialog({
    super.key,
    this.entry,
    required this.report,
  });

  @override
  State<TravelingPerDiemEntryDialog> createState() =>
      _TravelingPerDiemEntryDialogState();
}

class _TravelingPerDiemEntryDialogState
    extends State<TravelingPerDiemEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesController;
  late DateTime _date;
  late bool _hasBreakfast;
  late bool _hasLunch;
  late bool _hasSupper;
  late bool _hasIncidentMeal;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;

    _notesController = TextEditingController(
      text: entry?.notes ?? '',
    );
    _date = entry?.date ?? widget.report.departureTime;
    _hasBreakfast = entry?.hasBreakfast ?? false;
    _hasLunch = entry?.hasLunch ?? false;
    _hasSupper = entry?.hasSupper ?? false;
    _hasIncidentMeal = entry?.hasIncidentMeal ?? false;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    // Ensure firstDate is before or equal to lastDate
    final firstDate = widget.report.departureTime;
    var lastDate = widget.report.destinationTime;

    // If destinationTime is before or equal to departureTime, extend to 30 days
    if (lastDate.isBefore(firstDate) || lastDate.isAtSameMomentAs(firstDate)) {
      lastDate = firstDate.add(const Duration(days: 30));
    }

    // Ensure initialDate is within range
    var initialDate = _date;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  double _calculateAmount() {
    final mealRate = widget.report.travelLocationEnum.perDiemRate;
    int mealsCount =
        (_hasBreakfast ? 1 : 0) + (_hasLunch ? 1 : 0) + (_hasSupper ? 1 : 0) + (_hasIncidentMeal ? 1 : 0);
    final perPerson = mealsCount * mealRate;
    return perPerson * widget.report.totalMembers;
  }

  double _calculatePerPerson() {
    final mealRate = widget.report.travelLocationEnum.perDiemRate;
    int mealsCount =
        (_hasBreakfast ? 1 : 0) + (_hasLunch ? 1 : 0) + (_hasSupper ? 1 : 0) + (_hasIncidentMeal ? 1 : 0);
    return mealsCount * mealRate;
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      // Validate at least one meal selected
      if (!_hasBreakfast && !_hasLunch && !_hasSupper && !_hasIncidentMeal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one meal'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = {
        'date': _date,
        'hasBreakfast': _hasBreakfast,
        'hasLunch': _hasLunch,
        'hasSupper': _hasSupper,
        'hasIncidentMeal': _hasIncidentMeal,
        'notes': _notesController.text.trim(),
      };

      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isNew = widget.entry == null;
    final mealRate = widget.report.travelLocationEnum.perDiemRate;

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

                // Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Per Diem Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Travel Type: ${widget.report.travelLocationEnum.displayName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Rate: ${currencyFormat.format(mealRate)}฿ per meal',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Total Members: ${widget.report.totalMembers}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
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
                      helperText: 'Must be within travel period',
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
                        subtitle: Text('${currencyFormat.format(mealRate)}฿'),
                        value: _hasBreakfast,
                        onChanged: (value) {
                          setState(() {
                            _hasBreakfast = value ?? false;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: const Text('Lunch'),
                        subtitle: Text('${currencyFormat.format(mealRate)}฿'),
                        value: _hasLunch,
                        onChanged: (value) {
                          setState(() {
                            _hasLunch = value ?? false;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: const Text('Supper'),
                        subtitle: Text('${currencyFormat.format(mealRate)}฿'),
                        value: _hasSupper,
                        onChanged: (value) {
                          setState(() {
                            _hasSupper = value ?? false;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        title: const Text('Incident Meal'),
                        subtitle: Text('${currencyFormat.format(mealRate)}฿'),
                        value: _hasIncidentMeal,
                        onChanged: (value) {
                          setState(() {
                            _hasIncidentMeal = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    helperText: 'Brief description of activities',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                // Calculated Amount Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Calculated Amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Per Person:'),
                          Text(
                            '฿${currencyFormat.format(_calculatePerPerson())}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Total (${widget.report.totalMembers} members):'),
                          Text(
                            '฿${currencyFormat.format(_calculateAmount())}',
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
