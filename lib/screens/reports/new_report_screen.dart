import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/cash_advance.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({
    super.key,
    this.reportType = 'petty_cash',
    this.cashAdvanceId,
  });

  final String reportType; // 'petty_cash', 'advance_settlement'
  final String? cashAdvanceId;

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
  CashAdvance? _linkedAdvance;
  bool _isPrefilling = false;

  @override
  void initState() {
    super.initState();
    // Set default company name to Hope Channel Southeast Asia
    _companyNameController.text = AppConstants.companyName;
    _reportType = widget.reportType;
    if (widget.cashAdvanceId != null) {
      _reportType = 'advance_settlement';
      _loadLinkedAdvance(widget.cashAdvanceId!);
    }
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
    final currencyFormat = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    final title = _reportType == 'advance_settlement'
        ? 'Create Advance Settlement Report'
        : 'Create New Report';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          padding: ResponsiveHelper.getScreenPadding(context).copyWith(
            top: MediaQuery.of(context).padding.top + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(title),
                const SizedBox(height: 16),
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
                            initialValue: _reportType,
                            decoration: InputDecoration(
                              labelText: 'Report Type',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.assignment),
                              helperText: widget.cashAdvanceId != null
                                  ? 'Linked to Cash Advance ${widget.cashAdvanceId}'
                                  : null,
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
                            onChanged: widget.cashAdvanceId != null
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _reportType = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 16),
                          if (widget.cashAdvanceId != null &&
                              _linkedAdvance != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.shade100,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.link,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Linked cash advance: ${_linkedAdvance!.requestNumber} '
                                      '(${currencyFormat.format(_linkedAdvance!.disbursedAmount ?? _linkedAdvance!.requestedAmount)})',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
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
                                child: _buildDateField(
                                  'End Date',
                                  _periodEnd,
                                  (date) {
                                    setState(() {
                                      _periodEnd = date;
                                    });
                                  },
                                ),
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
                        onPressed: _isPrefilling ? null : _createReport,
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildHeaderCard(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Navigation row
          Row(
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.go('/admin-hub'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_outlined, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _reportType == 'advance_settlement'
                          ? 'Settlement Report'
                          : 'Petty Cash Report',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
        cashAdvanceId: widget.cashAdvanceId,
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

  Future<void> _loadLinkedAdvance(String advanceId) async {
    setState(() => _isPrefilling = true);
    try {
      final advance = await FirestoreService().getCashAdvance(advanceId);
      if (advance != null && mounted) {
        setState(() {
          _linkedAdvance = advance;
          _reportNameController.text = advance.department;
          _purposeController.text = advance.purpose;
          _openingBalanceController.text =
              (advance.disbursedAmount ?? advance.requestedAmount).toString();
          _advanceTakenDate = advance.disbursedAt ?? advance.requestDate;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load linked cash advance'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrefilling = false);
      }
    }
  }
}
