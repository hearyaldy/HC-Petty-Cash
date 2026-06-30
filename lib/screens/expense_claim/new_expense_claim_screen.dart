import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/enums.dart';
import '../../models/expense_claim.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_claim_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/support_document_upload_dialog.dart';

class NewExpenseClaimScreen extends StatefulWidget {
  const NewExpenseClaimScreen({super.key});

  @override
  State<NewExpenseClaimScreen> createState() => _NewExpenseClaimScreenState();
}

class _NewExpenseClaimScreenState extends State<NewExpenseClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<_LineItemForm> _items = [];
  bool _submitting = false;

  final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _purposeCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_LineItemForm()));
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _total =>
      _items.fold(0.0, (acc, item) => acc + (item.parsedAmount ?? 0.0));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that all items have a date
    for (final item in _items) {
      if (item.date == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date for every item.')),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      setState(() => _submitting = false);
      return;
    }

    final lineItems = _items.map((f) {
      final categoryValue = f.isCustomCategory
          ? f.customCategoryCtrl.text.trim()
          : f.selectedCategory.name;
      return ExpenseLineItem(
        date: f.date!,
        category: categoryValue,
        description: f.descriptionCtrl.text.trim(),
        receiptRef: f.receiptRefCtrl.text.trim().isEmpty
            ? null
            : f.receiptRefCtrl.text.trim(),
        amount: f.parsedAmount ?? 0.0,
        supportDocumentUrls: List.from(f.supportDocumentUrls),
      );
    }).toList();

    final provider = context.read<ExpenseClaimProvider>();
    final result = await provider.createClaim(
      requester: user,
      title: _titleCtrl.text.trim(),
      purpose: _purposeCtrl.text.trim(),
      department: user.department,
      items: lineItems,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense claim submitted successfully.')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to submit claim.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Expense Claim',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            Text(
              'Fill in the expense details below',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
              children: [
                _sectionHeader(theme, 'Claim Details'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Claim Title *',
                    hintText: 'e.g. Office supplies – June 2026',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purposeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Purpose / Reason *',
                    hintText: 'Brief reason for this expense',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Purpose is required' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _sectionHeader(theme, 'Expense Items')),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map(
                  (entry) => _LineItemCard(
                    key: ValueKey(entry.value),
                    form: entry.value,
                    index: entry.key,
                    canRemove: _items.length > 1,
                    onRemove: () => _removeItem(entry.key),
                    onChanged: () => setState(() {}),
                  ),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: theme.textTheme.titleMedium),
                    Text(
                      _currencyFormat.format(_total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes (optional)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Claim'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─── Line item form state ────────────────────────────────────────────────────

class _LineItemForm {
  /// Stable temp ID used as the Firebase Storage folder path before the
  /// claim document exists in Firestore.
  final String tempId = const Uuid().v4();

  ExpenseLineCategory selectedCategory = ExpenseLineCategory.travel;
  bool isCustomCategory = false;

  DateTime? date;
  List<String> supportDocumentUrls = [];

  final descriptionCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final receiptRefCtrl = TextEditingController();
  final customCategoryCtrl = TextEditingController();

  double? get parsedAmount => double.tryParse(amountCtrl.text);

  void dispose() {
    descriptionCtrl.dispose();
    amountCtrl.dispose();
    receiptRefCtrl.dispose();
    customCategoryCtrl.dispose();
  }
}

// ─── Line item card widget ───────────────────────────────────────────────────

class _LineItemCard extends StatefulWidget {
  const _LineItemCard({
    super.key,
    required this.form,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _LineItemForm form;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<_LineItemCard> {
  final _dateFormat = DateFormat('MMM dd, yyyy');

  late String _dropdownValue;
  late bool _isCustomCategory;

  @override
  void initState() {
    super.initState();
    _isCustomCategory = widget.form.isCustomCategory;
    _dropdownValue = _isCustomCategory
        ? 'other_custom'
        : widget.form.selectedCategory.name;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.form.date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => widget.form.date = picked);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final form = widget.form;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Item ${widget.index + 1}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  isDense: true,
                ),
                child: Text(
                  form.date != null
                      ? _dateFormat.format(form.date!)
                      : 'Select date',
                  style: form.date == null
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        )
                      : theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _dropdownValue,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                ...ExpenseLineCategory.values.map(
                  (c) => DropdownMenuItem(
                    value: c.name,
                    child: Text(c.displayName),
                  ),
                ),
                const DropdownMenuItem(
                  value: 'other_custom',
                  child: Text('Custom...'),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _dropdownValue = v ?? _dropdownValue;
                  if (v == 'other_custom') {
                    _isCustomCategory = true;
                    form.isCustomCategory = true;
                  } else if (v != null) {
                    _isCustomCategory = false;
                    form.isCustomCategory = false;
                    form.selectedCategory = v.toExpenseLineCategory();
                  }
                });
                widget.onChanged();
              },
            ),
            if (_isCustomCategory) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: form.customCategoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom Category *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => form.isCustomCategory &&
                        (v == null || v.trim().isEmpty)
                    ? 'Enter category name'
                    : null,
              ),
            ],
            const SizedBox(height: 10),

            // Description
            TextFormField(
              controller: form.descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'What was this expense for?',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Description required' : null,
            ),
            const SizedBox(height: 10),

            // Receipt ref + Amount side by side
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: form.receiptRefCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Receipt No. (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    controller: form.amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => widget.onChanged(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      if ((double.tryParse(v) ?? 0) <= 0) return '> 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Support documents
            OutlinedButton.icon(
              onPressed: () => _openDocumentDialog(context),
              icon: Icon(
                form.supportDocumentUrls.isEmpty
                    ? Icons.attach_file
                    : Icons.attach_file,
                size: 18,
                color: form.supportDocumentUrls.isEmpty
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                    : theme.colorScheme.primary,
              ),
              label: Text(
                form.supportDocumentUrls.isEmpty
                    ? 'Attach Receipt / Document'
                    : '${form.supportDocumentUrls.length} document${form.supportDocumentUrls.length == 1 ? '' : 's'} attached',
                style: TextStyle(
                  color: form.supportDocumentUrls.isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                      : theme.colorScheme.primary,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: form.supportDocumentUrls.isEmpty
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocumentDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => SupportDocumentUploadDialog(
        transactionId: widget.form.tempId,
        existingDocumentUrls: widget.form.supportDocumentUrls,
        onDocumentsUploaded: (urls) {
          setState(() => widget.form.supportDocumentUrls = urls);
          widget.onChanged();
        },
      ),
    );
  }
}
