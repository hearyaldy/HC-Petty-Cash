import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/cash_advance.dart';
import '../../models/enums.dart';
import '../../models/purchase_requisition.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/opening_balance_currency_fields.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({
    super.key,
    this.reportType = 'petty_cash',
    this.cashAdvanceId,
    this.purchaseRequisitionId,
  });

  final String reportType; // 'petty_cash', 'advance_settlement'
  final String? cashAdvanceId;
  final String? purchaseRequisitionId;

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _obCurrency = OpeningBalanceCurrencyState();
  final _notesController = TextEditingController();
  final _purposeController = TextEditingController();
  DateTime? _advanceTakenDate;

  late String _reportType;
  DateTime _periodStart = DateTime.now();
  DateTime _periodEnd = DateTime.now().add(const Duration(days: 7));
  CashAdvance? _linkedAdvance;
  PurchaseRequisition? _linkedPR;
  bool _isPrefilling = false;
  List<PurchaseRequisitionItem> _prItems = [];
  final Map<String, TextEditingController> _realPriceControllers = {};

  @override
  void initState() {
    super.initState();
    // Set default company name to Hope Channel Southeast Asia
    _companyNameController.text = AppConstants.companyName;
    _reportType = widget.reportType;
    if (widget.cashAdvanceId != null) {
      _reportType = 'advance_settlement';
      _loadLinkedAdvance(widget.cashAdvanceId!);
      // Also load PR items if this advance came from a purchase requisition
      if (widget.purchaseRequisitionId != null) {
        _loadPRItemsOnly(widget.purchaseRequisitionId!);
      }
    } else if (widget.purchaseRequisitionId != null) {
      _reportType = 'advance_settlement';
      _loadLinkedPurchaseRequisition(widget.purchaseRequisitionId!);
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
    for (final ctrl in _realPriceControllers.values) {
      ctrl.dispose();
    }
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
                          OpeningBalanceCurrencyFields(
                            thbController: _openingBalanceController,
                            state: _obCurrency,
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_prItems.isNotEmpty) ...[
                    _buildPRItemsCard(),
                    const SizedBox(height: 24),
                  ],
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
    final transactionProvider = context.read<TransactionProvider>();
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
        openingBalanceCurrency:
            _obCurrency.isForeign ? _obCurrency.currencyCode : null,
        openingBalanceForeign:
            _obCurrency.isForeign ? _obCurrency.foreignAmount : null,
        openingExchangeRate: _obCurrency.isForeign ? _obCurrency.rate : null,
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
        purchaseRequisitionId: widget.purchaseRequisitionId,
      );

      // Auto-create a transaction for each PR line item using the actual prices
      if (_prItems.isNotEmpty) {
        final txDate = _advanceTakenDate ?? DateTime.now();
        for (final item in _prItems) {
          final ctrl = _realPriceControllers[item.id];
          final actualUnitPrice =
              double.tryParse(ctrl?.text ?? '') ?? item.unitPrice;
          final lineTotal = item.quantity * actualUnitPrice;
          await transactionProvider.createTransaction(
            reportId: report.id,
            date: txDate,
            receiptNo: 'PR-${item.itemNo}',
            description: item.description +
                (item.remark != null && item.remark!.isNotEmpty
                    ? ' (${item.remark})'
                    : ''),
            category: ExpenseCategory.supplies,
            amount: lineTotal,
            paymentMethod: PaymentMethod.cash,
            requestorId: user.id,
          );
        }
      }

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

  Future<void> _loadLinkedPurchaseRequisition(String prId) async {
    setState(() => _isPrefilling = true);
    try {
      final pr = await FirestoreService().getPurchaseRequisition(prId);
      final items = pr != null
          ? await FirestoreService().getPurchaseRequisitionItems(prId)
          : <PurchaseRequisitionItem>[];
      if (pr != null && mounted) {
        // Create a controller for each item pre-filled with the estimated unit price
        final newControllers = <String, TextEditingController>{};
        for (final item in items) {
          newControllers[item.id] = TextEditingController(
            text: item.unitPrice.toStringAsFixed(2),
          );
        }
        setState(() {
          _linkedPR = pr;
          _prItems = items;
          _realPriceControllers.addAll(newControllers);
          _reportNameController.text = pr.chargeToDepartment;
          _purposeController.text = pr.purchaseReason ?? pr.requisitionNumber;
          _advanceTakenDate = DateTime.now();
          // Default to PR total; overridden below by actual item prices
          _openingBalanceController.text = pr.totalAmount.toStringAsFixed(2);
        });
        // Recalculate opening balance from item actual prices if items are present
        if (items.isNotEmpty) {
          _recalcTotalFromPRItems();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load linked purchase requisition'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrefilling = false);
    }
  }

  // ── Fetch PR items when advance was created from a PR ────────────────────
  Future<void> _loadPRItemsOnly(String prId) async {
    try {
      final items = await FirestoreService().getPurchaseRequisitionItems(prId);
      if (items.isNotEmpty && mounted) {
        final newControllers = <String, TextEditingController>{};
        for (final item in items) {
          newControllers[item.id] = TextEditingController(
            text: item.unitPrice.toStringAsFixed(2),
          );
        }
        setState(() {
          _prItems = items;
          _realPriceControllers.addAll(newControllers);
        });
      }
    } catch (_) {
      // Items are optional — silently skip if fetch fails
    }
  }

  // ── PR items helpers ──────────────────────────────────────────────────────

  void _recalcTotalFromPRItems() {
    if (_prItems.isEmpty) return;
    double total = 0;
    for (final item in _prItems) {
      final ctrl = _realPriceControllers[item.id];
      final realUnitPrice = double.tryParse(ctrl?.text ?? '') ?? item.unitPrice;
      total += item.quantity * realUnitPrice;
    }
    setState(() {
      _openingBalanceController.text = total.toStringAsFixed(2);
    });
  }

  Widget _buildPRItemsCard() {
    final currencyFormat = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    double runningTotal = 0;
    for (final item in _prItems) {
      final ctrl = _realPriceControllers[item.id];
      final realUnitPrice = double.tryParse(ctrl?.text ?? '') ?? item.unitPrice;
      runningTotal += item.quantity * realUnitPrice;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Purchase Requisition Items',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Total: ${currencyFormat.format(runningTotal)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Edit the "Actual Unit Price" for each item to reflect the real purchase amount. The Advance Amount above will update automatically.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              _prItems.length,
              (i) => _buildPRItemRow(_prItems[i], i),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Grand Total: ${currencyFormat.format(runningTotal)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPRItemRow(PurchaseRequisitionItem item, int index) {
    final currencyFormat = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    final ctrl = _realPriceControllers[item.id];
    final realUnitPrice = double.tryParse(ctrl?.text ?? '') ?? item.unitPrice;
    final lineTotal = item.quantity * realUnitPrice;

    return Column(
      children: [
        if (index > 0) const Divider(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item number badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${item.itemNo}',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Description + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (item.remark != null && item.remark!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.remark!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Price row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Qty',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Est. Unit Price',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(item.unitPrice),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Actual Unit Price',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => _recalcTotalFromPRItems(),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                border: const OutlineInputBorder(),
                                prefixText: AppConstants.currencySymbol,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Line total
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Line Total: ${currencyFormat.format(lineTotal)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
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
