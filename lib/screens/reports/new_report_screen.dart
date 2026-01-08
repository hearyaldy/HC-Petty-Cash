import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../utils/constants.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _periodStart = DateTime.now();
  DateTime _periodEnd = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    // Set default company name to Hope Channel Southeast Asia
    _companyNameController.text = AppConstants.companyName;
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _companyNameController.dispose();
    _openingBalanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
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
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.apartment),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a department';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _openingBalanceController,
                            decoration: InputDecoration(
                              labelText: 'Opening Balance',
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
