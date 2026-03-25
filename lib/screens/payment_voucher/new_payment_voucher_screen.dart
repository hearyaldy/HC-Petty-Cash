import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/payment_voucher.dart';
import '../../providers/payment_voucher_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/constants.dart';

class NewPaymentVoucherScreen extends StatefulWidget {
  const NewPaymentVoucherScreen({super.key});

  @override
  State<NewPaymentVoucherScreen> createState() =>
      _NewPaymentVoucherScreenState();
}

class _NewPaymentVoucherScreenState extends State<NewPaymentVoucherScreen> {
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
  void initState() {
    super.initState();
    // Start with one default recipient row.
    _addRecipient();
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
            colorScheme: const ColorScheme.light(
              primary: Colors.deepPurple,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _voucherDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    // Build recipients list, dropping any entries with an empty name.
    final recipients = _recipientControllers
        .map((c) => VoucherRecipient(
              name: c.text.trim(),
              title: '',
            ))
        .where((r) => r.name.isNotEmpty)
        .toList();

    final voucher =
        await context.read<PaymentVoucherProvider>().createVoucher(
              recipients: recipients,
              department: _selectedDepartment,
              purpose: _purposeController.text.trim(),
              amount: amount,
              paymentMethod: _selectedPaymentMethod,
              voucherDate: _voucherDate,
              createdById: user.id,
              createdByName: user.name,
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

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (voucher != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment voucher created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/payment-vouchers/${voucher.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create voucher. Please try again.'),
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
        child: ResponsiveContainer(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(isMobile),
                const SizedBox(height: 16),

                // Form
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Voucher Information Card (includes Recipients)
                        _buildSectionCard(
                          title: 'Voucher Information',
                          icon: Icons.info_outline,
                          children: [
                            // ---- Recipients section ----
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recipients',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.deepPurple,
                                  ),
                                  tooltip: 'Add recipient',
                                  onPressed: _addRecipient,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // One row per recipient
                            ...List.generate(
                              _recipientControllers.length,
                              (i) => _buildRecipientRow(i),
                            ),
                            const SizedBox(height: 8),

                            // Department
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDepartment,
                              decoration: InputDecoration(
                                labelText: 'Department *',
                                prefixIcon:
                                    const Icon(Icons.business_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Colors.deepPurple, width: 2),
                                ),
                              ),
                              items: _departments.map((dept) {
                                return DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                      () => _selectedDepartment = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Voucher Date
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: Colors.deepPurple, size: 20),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Voucher Date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateFormat.format(_voucherDate),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Icon(Icons.edit_outlined,
                                        color: Colors.grey[500], size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Purpose
                            TextFormField(
                              controller: _purposeController,
                              decoration: InputDecoration(
                                labelText: 'Purpose *',
                                hintText: 'Describe the payment purpose',
                                prefixIcon: const Icon(
                                    Icons.description_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Colors.deepPurple, width: 2),
                                ),
                              ),
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter the payment purpose';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Payment Details Card
                        _buildSectionCard(
                          title: 'Payment Details',
                          icon: Icons.payment_outlined,
                          children: [
                            // Amount
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Amount *',
                                prefixIcon: const Icon(
                                    Icons.attach_money_outlined),
                                prefixText:
                                    '${AppConstants.currencySymbol} ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Colors.deepPurple, width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter the amount';
                                }
                                final parsed =
                                    double.tryParse(value.trim());
                                if (parsed == null || parsed <= 0) {
                                  return 'Please enter a valid positive amount';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Payment Method
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPaymentMethod,
                              decoration: InputDecoration(
                                labelText: 'Payment Method *',
                                prefixIcon: const Icon(
                                    Icons.credit_card_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Colors.deepPurple, width: 2),
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
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() =>
                                      _selectedPaymentMethod = value);
                                }
                              },
                            ),

                            // Conditional: Bank Transfer fields
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.deepPurple, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _accountNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Account Number',
                                  prefixIcon:
                                      const Icon(Icons.numbers_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.deepPurple, width: 2),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],

                            // Conditional: Cheque field
                            if (_selectedPaymentMethod == 'cheque') ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _chequeNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Cheque Number',
                                  prefixIcon:
                                      const Icon(Icons.receipt_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.deepPurple, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Notes Card
                        _buildSectionCard(
                          title: 'Notes',
                          icon: Icons.notes_outlined,
                          children: [
                            TextFormField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'Additional Notes (Optional)',
                                hintText:
                                    'Any additional information...',
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
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
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
                              _isSubmitting
                                  ? 'Creating...'
                                  : 'Create Payment Voucher',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the UI block for a single recipient at [index].
  Widget _buildRecipientRow(int index) {
    final controller = _recipientControllers[index];
    final isOnly = _recipientControllers.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Index label + optional remove button
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
        // Name field
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: index == 0 ? 'Name *' : 'Name',
            hintText: 'Payee name or company',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.deepPurple, width: 2),
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
        // Divider between recipients (except after the last one)
        if (index < _recipientControllers.length - 1) ...[
          const SizedBox(height: 12),
          const Divider(),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepPurple, Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: () => context.go('/payment-vouchers'),
              ),
              _buildHeaderActionButton(
                icon: Icons.home_outlined,
                tooltip: 'Finance Dashboard',
                onPressed: () => context.go('/finance-dashboard'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create Payment Voucher',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fill in the details below',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
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
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
