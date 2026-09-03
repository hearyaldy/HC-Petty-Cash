import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../models/internal_debit_note.dart';
import '../../providers/internal_debit_note_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';

class _LineItemRow {
  final quill.QuillController descriptionController = quill.QuillController.basic();
  final TextEditingController amountController = TextEditingController();
  final FocusNode descriptionFocusNode = FocusNode();
  final ScrollController descriptionScrollController = ScrollController();

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    descriptionFocusNode.dispose();
    descriptionScrollController.dispose();
  }
}

class NewInternalDebitNoteScreen extends StatefulWidget {
  const NewInternalDebitNoteScreen({super.key});

  @override
  State<NewInternalDebitNoteScreen> createState() =>
      _NewInternalDebitNoteScreenState();
}

class _NewInternalDebitNoteScreenState
    extends State<NewInternalDebitNoteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyController = TextEditingController();
  final _issuedToController = TextEditingController();
  final _reasonController = TextEditingController();
  final _termsController =
      TextEditingController(text: 'To be settled through intercompany accounting.');
  final _checkedByController = TextEditingController();
  final _approvedByController = TextEditingController();

  final List<_LineItemRow> _lineItems = [_LineItemRow()];

  String _selectedDepartment = 'Finance';
  String _selectedCurrency = 'THB';
  DateTime _noteDate = DateTime.now();
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

  static const List<String> _currencies = ['THB', 'USD', 'MYR', 'SGD', 'EUR', 'GBP'];

  @override
  void dispose() {
    _companyController.dispose();
    _issuedToController.dispose();
    _reasonController.dispose();
    _termsController.dispose();
    _checkedByController.dispose();
    _approvedByController.dispose();
    for (final row in _lineItems) {
      row.dispose();
    }
    super.dispose();
  }

  void _addLineItem() {
    setState(() => _lineItems.add(_LineItemRow()));
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  double get _totalAmount => _lineItems.fold(0.0, (sum, row) {
        final parsed = double.tryParse(row.amountController.text.trim());
        return sum + (parsed ?? 0.0);
      });

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _noteDate,
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
      setState(() => _noteDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final lineItems = _lineItems
        .where((row) =>
            row.descriptionController.document.toPlainText().trim().isNotEmpty &&
            (double.tryParse(row.amountController.text.trim()) ?? 0) > 0)
        .map((row) => DebitNoteLineItem(
              description: jsonEncode(
                  row.descriptionController.document.toDelta().toJson()),
              amount: double.tryParse(row.amountController.text.trim()) ?? 0.0,
            ))
        .toList();

    if (lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one line item with a description and amount'),
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

    final note = await context.read<InternalDebitNoteProvider>().createNote(
          noteDate: _noteDate,
          companyName: _companyController.text.trim(),
          issuedToCompany: _issuedToController.text.trim(),
          department: _selectedDepartment,
          lineItems: lineItems,
          currency: _selectedCurrency,
          reasonForDebit: _reasonController.text.trim(),
          paymentTerms: _termsController.text.trim(),
          createdById: user.id,
          createdByName: user.name,
          checkedByName: _checkedByController.text.trim().isEmpty
              ? null
              : _checkedByController.text.trim(),
          approvedByName: _approvedByController.text.trim().isEmpty
              ? null
              : _approvedByController.text.trim(),
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (note != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Internal debit note created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/internal-debit-notes/${note.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create debit note. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputDecoration _decoration(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
    );
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
                _buildHeader(isMobile),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionCard(
                          title: 'Note Information',
                          icon: Icons.info_outline,
                          children: [
                            TextFormField(
                              controller: _companyController,
                              decoration: _decoration('Company (Issuer) *',
                                  icon: Icons.business_outlined,
                                  hint: 'e.g. Hope Channel Thailand'),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Please enter the issuing company'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _issuedToController,
                              decoration: _decoration('Issued To *',
                                  icon: Icons.business_center_outlined,
                                  hint: 'e.g. Hope Channel Singapore'),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Please enter the recipient company'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDepartment,
                              decoration:
                                  _decoration('Department *', icon: Icons.apartment_outlined),
                              items: _departments
                                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedDepartment = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: Colors.deepPurple, size: 20),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Date',
                                            style: TextStyle(
                                                fontSize: 12, color: Colors.grey[600])),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateFormat.format(_noteDate),
                                          style: const TextStyle(
                                              fontSize: 15, fontWeight: FontWeight.w500),
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'Details',
                          icon: Icons.list_alt_outlined,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Line Items',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline,
                                      color: Colors.deepPurple),
                                  tooltip: 'Add line item',
                                  onPressed: _addLineItem,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                                _lineItems.length, (i) => _buildLineItemRow(i)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCurrency,
                              decoration:
                                  _decoration('Currency', icon: Icons.currency_exchange),
                              items: _currencies
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedCurrency = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Debit Amount',
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(
                                    '$_selectedCurrency ${NumberFormat('#,##0.00').format(_totalAmount)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'Reason & Terms',
                          icon: Icons.description_outlined,
                          children: [
                            TextFormField(
                              controller: _reasonController,
                              decoration: _decoration('Reason for Debit *',
                                  hint: 'Explain why this charge is being made'),
                              maxLines: 3,
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Please enter a reason for the debit'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _termsController,
                              decoration: _decoration('Payment / Settlement Terms *'),
                              maxLines: 2,
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Please enter payment/settlement terms'
                                      : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'Signatures (Optional)',
                          icon: Icons.draw_outlined,
                          children: [
                            TextFormField(
                              controller: _checkedByController,
                              decoration: _decoration('Checked By',
                                  icon: Icons.person_outline),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _approvedByController,
                              decoration: _decoration('Approved By',
                                  icon: Icons.person_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSubmitting ? 'Creating...' : 'Create Debit Note',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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

  Widget _buildLineItemRow(int index) {
    final row = _lineItems[index];
    final isOnly = _lineItems.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Item ${index + 1}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
            const Spacer(),
            if (!isOnly)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 20),
                tooltip: 'Remove item',
                onPressed: () => _removeLineItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          index == 0 ? 'Description *' : 'Description',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        _buildDescriptionEditor(row),
        const SizedBox(height: 10),
        TextFormField(
          controller: row.amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: _decoration(index == 0 ? 'Amount *' : 'Amount',
              icon: Icons.attach_money_outlined),
          onChanged: (_) => setState(() {}),
          validator: index == 0
              ? (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid positive amount';
                  }
                  return null;
                }
              : null,
        ),
        if (index < _lineItems.length - 1) ...[
          const SizedBox(height: 12),
          const Divider(),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDescriptionEditor(_LineItemRow row) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          quill.QuillSimpleToolbar(
            controller: row.descriptionController,
            config: const quill.QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: false,
              showBackgroundColorButton: false,
              showColorButton: false,
              showAlignmentButtons: false,
              showDirection: false,
              showDividers: false,
              showHeaderStyle: false,
              showIndent: false,
              showLink: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showCodeBlock: false,
              showInlineCode: false,
              showQuote: false,
              showSmallButton: false,
              showListCheck: false,
              multiRowsDisplay: false,
              toolbarSize: 32,
            ),
          ),
          const Divider(height: 1),
          Container(
            constraints: const BoxConstraints(minHeight: 110, maxHeight: 220),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: quill.QuillEditor(
              controller: row.descriptionController,
              focusNode: row.descriptionFocusNode,
              scrollController: row.descriptionScrollController,
              config: quill.QuillEditorConfig(
                placeholder: 'e.g. Hotel expense paid on behalf of...',
                padding: const EdgeInsets.all(10),
                autoFocus: false,
                expands: false,
                scrollable: true,
              ),
            ),
          ),
        ],
      ),
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
                onPressed: () => context.go('/internal-debit-notes'),
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
            child: const Icon(Icons.compare_arrows_outlined, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create Internal Debit Note',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Fill in the details below',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
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
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
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
