import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transportation_request.dart';
import '../models/enums.dart';

class EditTransportationRequestDialog extends StatefulWidget {
  final TransportationRequest? request; // null for new request
  final String requesterId;
  final String requesterName;

  const EditTransportationRequestDialog({
    super.key,
    this.request,
    required this.requesterId,
    required this.requesterName,
  });

  @override
  State<EditTransportationRequestDialog> createState() =>
      _EditTransportationRequestDialogState();
}

class _EditTransportationRequestDialogState
    extends State<EditTransportationRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _departmentController;
  late TextEditingController _purposeController;
  late TextEditingController _destinationController;
  late TextEditingController _departureFlightNumberController;
  late TextEditingController _departureFlightTimeController;
  late TextEditingController _returnFlightNumberController;
  late TextEditingController _returnFlightTimeController;
  late TextEditingController _notesController;
  late DateTime _requestDate;
  late DateTime _travelDateTime;
  late DateTime _returnDateTime;
  late TravelLocation _travelLocation;
  late VehicleType _vehicleType;

  @override
  void initState() {
    super.initState();
    final request = widget.request;

    _departmentController = TextEditingController(text: request?.department ?? '');
    _purposeController = TextEditingController(text: request?.purpose ?? '');
    _destinationController =
        TextEditingController(text: request?.destinationPlace ?? '');
    _departureFlightNumberController =
        TextEditingController(text: request?.departureFlightNumber ?? '');
    _departureFlightTimeController =
        TextEditingController(text: request?.departureFlightTime ?? '');
    _returnFlightNumberController =
        TextEditingController(text: request?.returnFlightNumber ?? '');
    _returnFlightTimeController =
        TextEditingController(text: request?.returnFlightTime ?? '');
    _notesController = TextEditingController(text: request?.notes ?? '');

    _requestDate = request?.requestDate ?? DateTime.now();
    _travelDateTime = request?.travelDateTime ?? DateTime.now();
    _returnDateTime =
        request?.returnDateTime ?? DateTime.now().add(const Duration(days: 1));
    _travelLocation =
        request?.travelLocation.toTravelLocation() ?? TravelLocation.local;
    _vehicleType =
        request?.vehicleType.toVehicleType() ?? VehicleType.personalVehicle;
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _purposeController.dispose();
    _destinationController.dispose();
    _departureFlightNumberController.dispose();
    _departureFlightTimeController.dispose();
    _returnFlightNumberController.dispose();
    _returnFlightTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _requestDate = picked);
    }
  }

  Future<void> _selectDateTime(bool isTravel) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: isTravel ? _travelDateTime : _returnDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isTravel ? _travelDateTime : _returnDateTime,
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
          if (isTravel) {
            _travelDateTime = dateTime;
          } else {
            _returnDateTime = dateTime;
          }
        });
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_returnDateTime.isBefore(_travelDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date of return must be after date of travel'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'department': _departmentController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'destinationPlace': _destinationController.text.trim(),
      'requestDate': _requestDate,
      'travelDateTime': _travelDateTime,
      'returnDateTime': _returnDateTime,
      'travelLocation': _travelLocation.name,
      'vehicleType': _vehicleType.name,
      'departureFlightNumber': _departureFlightNumberController.text.trim().isEmpty
          ? null
          : _departureFlightNumberController.text.trim(),
      'departureFlightTime': _departureFlightTimeController.text.trim().isEmpty
          ? null
          : _departureFlightTimeController.text.trim(),
      'returnFlightNumber': _returnFlightNumberController.text.trim().isEmpty
          ? null
          : _returnFlightNumberController.text.trim(),
      'returnFlightTime': _returnFlightTimeController.text.trim().isEmpty
          ? null
          : _returnFlightTimeController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
    final isNew = widget.request == null;

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
                      isNew ? 'New Transportation Request' : 'Edit Transportation Request',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (!isNew)
                  Column(
                    children: [
                      TextFormField(
                        initialValue: widget.request!.requestNumber,
                        decoration: const InputDecoration(
                          labelText: 'Request Number',
                          border: OutlineInputBorder(),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Request Date
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(dateFormat.format(_requestDate)),
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
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter department' : null,
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
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter purpose' : null,
                ),
                const SizedBox(height: 16),

                // Destination
                TextFormField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: 'Destination Place',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter destination' : null,
                ),
                const SizedBox(height: 16),

                // Date of Travel
                InkWell(
                  onTap: () => _selectDateTime(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Travel',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(dateTimeFormat.format(_travelDateTime)),
                  ),
                ),
                const SizedBox(height: 16),

                // Date of Return
                InkWell(
                  onTap: () => _selectDateTime(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Return',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(dateTimeFormat.format(_returnDateTime)),
                  ),
                ),
                const SizedBox(height: 16),

                // Travel Location (Local/Abroad)
                DropdownButtonFormField<TravelLocation>(
                  initialValue: _travelLocation,
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
                  onChanged: (value) => setState(() => _travelLocation = value!),
                ),
                const SizedBox(height: 16),

                // Vehicle Type
                DropdownButtonFormField<VehicleType>(
                  initialValue: _vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(),
                    helperText: 'Sets the mileage reimbursement rate',
                  ),
                  items: VehicleType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.isFlatRate
                            ? '${type.displayName} (flat rate by airport)'
                            : '${type.displayName} (${type.ratePerKm.toStringAsFixed(0)}฿/km)',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _vehicleType = value!),
                ),
                const SizedBox(height: 16),

                // Flight info (optional)
                Text(
                  'Flight Info (Optional)',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _departureFlightNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Departure Flight No.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _departureFlightTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Departure Time',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _returnFlightNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Return Flight No.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _returnFlightTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Return Time',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
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
