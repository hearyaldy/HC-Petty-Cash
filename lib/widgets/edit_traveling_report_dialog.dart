import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/traveling_report.dart';
import '../models/enums.dart';

class EditTravelingReportDialog extends StatefulWidget {
  final TravelingReport? report; // null for new report
  final String reporterId;
  final String reporterName;

  const EditTravelingReportDialog({
    super.key,
    this.report,
    required this.reporterId,
    required this.reporterName,
  });

  @override
  State<EditTravelingReportDialog> createState() =>
      _EditTravelingReportDialogState();
}

class _EditTravelingReportDialogState extends State<EditTravelingReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _departmentController;
  late TextEditingController _purposeController;
  late TextEditingController _placeNameController;
  late TextEditingController _totalMembersController;
  late TextEditingController _mileageStartController;
  late TextEditingController _mileageEndController;
  late TextEditingController _notesController;
  late DateTime _reportDate;
  late DateTime _departureTime;
  late DateTime _destinationTime;
  late TravelLocation _travelLocation;

  @override
  void initState() {
    super.initState();
    final report = widget.report;

    _departmentController = TextEditingController(
      text: report?.department ?? '',
    );
    _purposeController = TextEditingController(
      text: report?.purpose ?? '',
    );
    _placeNameController = TextEditingController(
      text: report?.placeName ?? '',
    );
    _totalMembersController = TextEditingController(
      text: report?.totalMembers.toString() ?? '1',
    );
    _mileageStartController = TextEditingController(
      text: report?.mileageStart.toString() ?? '0',
    );
    _mileageEndController = TextEditingController(
      text: report?.mileageEnd.toString() ?? '0',
    );
    _notesController = TextEditingController(
      text: report?.notes ?? '',
    );

    _reportDate = report?.reportDate ?? DateTime.now();
    _departureTime = report?.departureTime ?? DateTime.now();
    _destinationTime = report?.destinationTime ?? DateTime.now().add(const Duration(hours: 8));
    _travelLocation = report?.travelLocationEnum ?? TravelLocation.local;
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _purposeController.dispose();
    _placeNameController.dispose();
    _totalMembersController.dispose();
    _mileageStartController.dispose();
    _mileageEndController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _reportDate = picked;
      });
    }
  }

  Future<void> _selectDateTime(bool isDeparture) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isDeparture ? _departureTime : _destinationTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isDeparture ? _departureTime : _destinationTime,
        ),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          final dateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isDeparture) {
            _departureTime = dateTime;
          } else {
            _destinationTime = dateTime;
          }
        });
      }
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      // Validate mileage
      final mileageStart = double.parse(_mileageStartController.text.trim());
      final mileageEnd = double.parse(_mileageEndController.text.trim());

      if (mileageEnd < mileageStart) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mileage end must be greater than or equal to mileage start'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate times
      if (_destinationTime.isBefore(_departureTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destination time must be after departure time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final totalMembers = int.parse(_totalMembersController.text.trim());
      if (totalMembers < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total members must be at least 1'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = {
        'department': _departmentController.text.trim(),
        'purpose': _purposeController.text.trim(),
        'placeName': _placeNameController.text.trim(),
        'reportDate': _reportDate,
        'departureTime': _departureTime,
        'destinationTime': _destinationTime,
        'totalMembers': totalMembers,
        'travelLocation': _travelLocation.name,
        'mileageStart': mileageStart,
        'mileageEnd': mileageEnd,
        'notes': _notesController.text.trim(),
      };

      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
    final isNew = widget.report == null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
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
                      isNew ? 'New Traveling Report' : 'Edit Traveling Report',
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

                // Report Number (Read-only for existing reports)
                if (!isNew)
                  Column(
                    children: [
                      TextFormField(
                        initialValue: widget.report!.reportNumber,
                        decoration: const InputDecoration(
                          labelText: 'Report Number',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Report Date
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Report Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(dateFormat.format(_reportDate)),
                  ),
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

                // Purpose
                TextFormField(
                  controller: _purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose of Travel',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter purpose';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Place Name
                TextFormField(
                  controller: _placeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Place Name / Destination',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter destination';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Departure Time
                InkWell(
                  onTap: () => _selectDateTime(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Departure Time',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(dateTimeFormat.format(_departureTime)),
                  ),
                ),
                const SizedBox(height: 16),

                // Destination Time
                InkWell(
                  onTap: () => _selectDateTime(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Destination Time',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(dateTimeFormat.format(_destinationTime)),
                  ),
                ),
                const SizedBox(height: 16),

                // Total Members
                TextFormField(
                  controller: _totalMembersController,
                  decoration: const InputDecoration(
                    labelText: 'Total Number of Members',
                    border: OutlineInputBorder(),
                    helperText: 'For per diem calculation',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter total members';
                    }
                    final number = int.tryParse(value.trim());
                    if (number == null || number < 1) {
                      return 'Must be at least 1';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Travel Location (Local/Abroad)
                DropdownButtonFormField<TravelLocation>(
                  value: _travelLocation,
                  decoration: const InputDecoration(
                    labelText: 'Travel Location',
                    border: OutlineInputBorder(),
                    helperText: 'Affects per diem rate (125฿ local, 250฿ abroad)',
                  ),
                  items: TravelLocation.values.map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(
                        '${location.displayName} (${location.perDiemRate.toStringAsFixed(0)}฿/meal)',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _travelLocation = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Mileage Start
                TextFormField(
                  controller: _mileageStartController,
                  decoration: const InputDecoration(
                    labelText: 'Mileage Start (KM)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter starting mileage';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
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
                    helperText: 'Reimbursement: 5฿ per KM',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter ending mileage';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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
