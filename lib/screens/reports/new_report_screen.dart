import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({
    super.key,
    this.reportType = 'petty_cash',
  });

  final String reportType; // 'petty_cash', 'advance_settlement'

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _notesController = TextEditingController();
  final _purposeController = TextEditingController();
  DateTime? _advanceTakenDate;

  late String _reportType;
  DateTime _periodStart = DateTime.now();
  DateTime _periodEnd = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    // Set default company name to Hope Channel Southeast Asia
    _companyNameController.text = AppConstants.companyName;
    _reportType = widget.reportType;
    if (_reportType == 'advance_settlement') {
      _advanceTakenDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _companyNameController.dispose();
    _openingBalanceController.dispose();
    _notesController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _reportType == 'advance_settlement'
              ? 'Create Advance Settlement Report'
              : 'Create New Report',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/admin-hub'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Information',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            value: _reportType,
                            decoration: const InputDecoration(
                              labelText: 'Report Type',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.assignment),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'petty_cash',
                                child: Text('Petty Cash Report'),
                              ),
                              DropdownMenuItem(
                                value: 'advance_settlement',
                                child: Text('Advance Settlement Report'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _reportType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Company Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                              helperText:
                                  'Default: Hope Channel Southeast Asia',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _reportNameController,
                            decoration: InputDecoration(
                              labelText: _reportType == 'advance_settlement'
                                  ? 'Department'
                                  : 'Report Name',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.description),
                              helperText: _reportType == 'advance_settlement'
                                  ? 'Department or unit responsible for this report'
                                  : null,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _reportType == 'advance_settlement'
                                    ? 'Please enter a department'
                                    : 'Please enter a report name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_reportType == 'advance_settlement') ...[
                            TextFormField(
                              controller: _purposeController,
                              decoration: const InputDecoration(
                                labelText: 'For the Purpose of',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.assignment_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter the purpose';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _advanceTakenDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _advanceTakenDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Advance Taken Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event),
                                ),
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(
                                    _advanceTakenDate ?? DateTime.now(),
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _openingBalanceController,
                            decoration: InputDecoration(
                              labelText: _reportType == 'advance_settlement'
                                  ? 'Advance Amount'
                                  : 'Opening Balance',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(
                                Icons.account_balance_wallet,
                              ),
                              prefixText: AppConstants.currencySymbol,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an opening balance';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reporting Period',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  'Start Date',
                                  _periodStart,
                                  (date) {
                                    setState(() {
                                      _periodStart = date;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDateField('End Date', _periodEnd, (
                                  date,
                                ) {
                                  setState(() {
                                    _periodEnd = date;
                                  });
                                }),
                              ),
                            ],
                          ),
                          if (_periodEnd.isBefore(_periodStart)) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'End date must be after start date',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Notes',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes (Optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.note),
                            ),
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _createReport,
                        icon: const Icon(Icons.check),
                        label: const Text('Create Report'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
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

  Widget _buildDateField(
    String label,
    DateTime selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          DateFormat('MMM dd, yyyy').format(selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _createReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_periodEnd.isBefore(_periodStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final reportProvider = context.read<ReportProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final report = await reportProvider.createReport(
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        reportName: _reportNameController.text,
        custodian: user,
        openingBalance: double.parse(_openingBalanceController.text),
        reportType: _reportType,
        purpose: _reportType == 'advance_settlement'
            ? _purposeController.text.trim()
            : null,
        advanceTakenDate:
            _reportType == 'advance_settlement' ? _advanceTakenDate : null,
        companyName: _companyNameController.text.isEmpty
            ? null
            : _companyNameController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/reports/${report.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
