import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/payment_voucher.dart';
import '../../providers/payment_voucher_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/constants.dart';

class EditPaymentVoucherScreen extends StatefulWidget {
  final String voucherId;
  const EditPaymentVoucherScreen({super.key, required this.voucherId});

  @override
  State<EditPaymentVoucherScreen> createState() =>
      _EditPaymentVoucherScreenState();
}

class _EditPaymentVoucherScreenState extends State<EditPaymentVoucherScreen> {
  final _formKey = GlobalKey<FormState>();

  // Recipient controllers — one per recipient (name only).
  final List<TextEditingController> _recipientControllers = [];

  // Other controllers
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedDepartment = 'Finance';
  String _selectedPaymentMethod = 'cash';
  DateTime _voucherDate = DateTime.now();
  bool _isSubmitting = false;
  bool _initialized = false;

  PaymentVoucher? _voucher;

  static const List<String> _departments = [
    'Finance',
    'Hope Channel',
    'Production',
    'Marketing',
    'Administration',
    'HR',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadVoucher();
    }
  }

  void _loadVoucher() {
    final provider = context.read<PaymentVoucherProvider>();
    final voucher = provider.vouchers.where((v) => v.id == widget.voucherId).firstOrNull;
    if (voucher != null) {
      _populate(voucher);
    } else {
      // Fetch from Firestore directly if not in provider cache
      provider.loadVouchers().then((_) {
        if (mounted) {
          final v = provider.vouchers.where((v) => v.id == widget.voucherId).firstOrNull;
          if (v != null) _populate(v);
        }
      });
    }
  }

  void _populate(PaymentVoucher voucher) {
    setState(() {
      _voucher = voucher;
      // Recipients
      for (final c in _recipientControllers) {
        c.dispose();
      }
      _recipientControllers.clear();
      for (final r in voucher.recipients) {
        _recipientControllers.add(TextEditingController(text: r.name));
      }
      if (_recipientControllers.isEmpty) {
        _recipientControllers.add(TextEditingController());
      }
      // Other fields
      _purposeController.text = voucher.purpose;
      _amountController.text = voucher.amount.toStringAsFixed(2);
      _bankNameController.text = voucher.bankName ?? '';
      _accountNumberController.text = voucher.accountNumber ?? '';
      _chequeNumberController.text = voucher.chequeNumber ?? '';
      _notesController.text = voucher.notes ?? '';
      _selectedDepartment = _departments.contains(voucher.department)
          ? voucher.department
          : 'Other';
      _selectedPaymentMethod = voucher.paymentMethod;
      _voucherDate = voucher.voucherDate;
    });
  }

  @override
  void dispose() {
    for (final c in _recipientControllers) {
      c.dispose();
    }
    _purposeController.dispose();
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _chequeNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addRecipient() {
    setState(() {
      _recipientControllers.add(TextEditingController());
    });
  }

  void _removeRecipient(int index) {
    setState(() {
      _recipientControllers[index].dispose();
      _recipientControllers.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _voucherDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _voucherDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_voucher == null) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final recipients = _recipientControllers
        .map((c) => VoucherRecipient(name: c.text.trim(), title: ''))
        .where((r) => r.name.isNotEmpty)
        .toList();

    final updated = _voucher!.copyWith(
      recipients: recipients,
      department: _selectedDepartment,
      purpose: _purposeController.text.trim(),
      amount: amount,
      paymentMethod: _selectedPaymentMethod,
      voucherDate: _voucherDate,
      bankName: _selectedPaymentMethod == 'bank_transfer'
          ? _bankNameController.text.trim().isEmpty
              ? null
              : _bankNameController.text.trim()
          : null,
      accountNumber: _selectedPaymentMethod == 'bank_transfer'
          ? _accountNumberController.text.trim().isEmpty
              ? null
              : _accountNumberController.text.trim()
          : null,
      chequeNumber: _selectedPaymentMethod == 'cheque'
          ? _chequeNumberController.text.trim().isEmpty
              ? null
              : _chequeNumberController.text.trim()
          : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final success =
        await context.read<PaymentVoucherProvider>().updateVoucher(updated);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voucher updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/payment-vouchers/${widget.voucherId}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update voucher. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _voucher == null
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveContainer(
                padding: EdgeInsets.zero,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _buildHeader(isMobile),
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionCard(
                              title: 'Voucher Info',
                              icon: Icons.info_outline,
                              child: Column(
                                children: [
                                  // Date picker
                                  InkWell(
                                    onTap: _selectDate,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Voucher Date',
                                        prefixIcon: const Icon(
                                            Icons.calendar_today_outlined),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        suffixIcon:
                                            const Icon(Icons.arrow_drop_down),
                                      ),
                                      child:
                                          Text(dateFormat.format(_voucherDate)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Department
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedDepartment,
                                    decoration: InputDecoration(
                                      labelText: 'Department',
                                      prefixIcon:
                                          const Icon(Icons.business_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: _departments
                                        .map((d) => DropdownMenuItem(
                                            value: d, child: Text(d)))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _selectedDepartment = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Recipients section
                            _buildSectionCard(
                              title: 'Recipients',
                              icon: Icons.people_outline,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...List.generate(
                                    _recipientControllers.length,
                                    _buildRecipientRow,
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton.icon(
                                    onPressed: _addRecipient,
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 18),
                                    label: const Text('Add Recipient'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Payment details
                            _buildSectionCard(
                              title: 'Payment Details',
                              icon: Icons.payment_outlined,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _purposeController,
                                    decoration: InputDecoration(
                                      labelText: 'Purpose / Description *',
                                      hintText: 'What is this payment for?',
                                      prefixIcon: const Icon(
                                          Icons.description_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Colors.deepPurple, width: 2),
                                      ),
                                    ),
                                    maxLines: 2,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Please enter a purpose'
                                            : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _amountController,
                                    decoration: InputDecoration(
                                      labelText: 'Amount *',
                                      prefixIcon:
                                          const Icon(Icons.attach_money),
                                      prefixText:
                                          '${AppConstants.currencySymbol} ',
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Colors.deepPurple, width: 2),
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}')),
                                    ],
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Please enter an amount'
                                            : null,
                                  ),
                                  const SizedBox(height: 16),
                                  // Payment method
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedPaymentMethod,
                                    decoration: InputDecoration(
                                      labelText: 'Payment Method',
                                      prefixIcon:
                                          const Icon(Icons.account_balance),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'cash', child: Text('Cash')),
                                      DropdownMenuItem(
                                          value: 'bank_transfer',
                                          child: Text('Bank Transfer')),
                                      DropdownMenuItem(
                                          value: 'cheque',
                                          child: Text('Cheque')),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _selectedPaymentMethod = v!),
                                  ),
                                  if (_selectedPaymentMethod ==
                                      'bank_transfer') ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _bankNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Bank Name',
                                        prefixIcon: const Icon(
                                            Icons.account_balance_outlined),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.deepPurple,
                                              width: 2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _accountNumberController,
                                      decoration: InputDecoration(
                                        labelText: 'Account Number',
                                        prefixIcon: const Icon(Icons.numbers),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.deepPurple,
                                              width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_selectedPaymentMethod == 'cheque') ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _chequeNumberController,
                                      decoration: InputDecoration(
                                        labelText: 'Cheque Number',
                                        prefixIcon: const Icon(Icons.receipt),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.deepPurple,
                                              width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Notes
                            _buildSectionCard(
                              title: 'Notes (Optional)',
                              icon: Icons.notes_outlined,
                              child: TextFormField(
                                controller: _notesController,
                                decoration: InputDecoration(
                                  hintText: 'Any additional notes...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.deepPurple, width: 2),
                                  ),
                                ),
                                maxLines: 3,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _save,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                    _isSubmitting ? 'Saving...' : 'Save Changes'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildHeaderActionButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Voucher',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_voucher != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _voucher!.voucherNumber,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientRow(int index) {
    final controller = _recipientControllers[index];
    final isOnly = _recipientControllers.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recipient ${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const Spacer(),
            if (!isOnly)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 20),
                tooltip: 'Remove recipient',
                onPressed: () => _removeRecipient(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: index == 0 ? 'Name *' : 'Name',
            hintText: 'Payee name or company',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
          ),
          validator: index == 0
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter at least one recipient name';
                  }
                  return null;
                }
              : null,
        ),
        if (index < _recipientControllers.length - 1) ...[
          const SizedBox(height: 12),
          const Divider(),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
