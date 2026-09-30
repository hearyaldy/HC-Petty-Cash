import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/adcom_minutes.dart';
import '../../models/cash_advance.dart' show CashAdvanceMeetingReference;
import '../../models/enums.dart';
import '../../models/expense_claim.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_claim_provider.dart';
import '../../services/adcom_minutes_service.dart';
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

  // Meeting minutes references (multiple action items, any meeting)
  final List<CashAdvanceMeetingReference> _meetingReferences = [];
  final _minutesService = AdcomMinutesService();

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

  Future<void> _pickMinutesReference() async {
    // Step 1 – pick a minutes document
    List<AdcomMinutes> minutesList = [];
    try {
      minutesList = await _minutesService.getMinutes().first;
    } catch (_) {}
    if (!mounted) return;

    final AdcomMinutes? selectedMinutes = await showDialog<AdcomMinutes>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Meeting Minutes'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: minutesList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No meeting minutes found.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: minutesList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = minutesList[index];
                    final dateStr =
                        DateFormat('MMM dd, yyyy').format(m.meetingDate);
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.article_outlined,
                            size: 20, color: Colors.deepOrange.shade600),
                      ),
                      title: Text('ADCOM – $dateStr',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(m.location,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: m.status == 'finalized'
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: m.status == 'finalized'
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          m.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: m.status == 'finalized'
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, m),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedMinutes == null || !mounted) return;

    // Step 2 – pick an action item from that minutes
    final MinutesItem? selectedItem = await showDialog<MinutesItem>(
      context: context,
      builder: (context) {
        final items = selectedMinutes.minutesItems;
        final dateStr =
            DateFormat('MMM dd, yyyy').format(selectedMinutes.meetingDate);
        return AlertDialog(
          title: Text('ADCOM – $dateStr'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No action items in this minutes.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: Colors.deepOrange.shade200),
                          ),
                          child: Text(
                            item.itemNumber,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange.shade700,
                            ),
                          ),
                        ),
                        title: Text(item.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: item.resolution != null
                            ? Text(item.resolution!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]))
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        );
      },
    );

    if (selectedItem == null || !mounted) return;

    final dateStr =
        DateFormat('MMM dd, yyyy').format(selectedMinutes.meetingDate);
    final reference = CashAdvanceMeetingReference(
      minutesId: selectedMinutes.id,
      minutesLabel: 'ADCOM – $dateStr',
      actionItemNumber: selectedItem.itemNumber,
      actionItemTitle: selectedItem.title,
      actionItemDescription: selectedItem.description,
      actionItemAction: selectedItem.status.displayName,
    );
    setState(() {
      _meetingReferences.removeWhere((r) =>
          r.minutesId == reference.minutesId &&
          r.actionItemNumber == reference.actionItemNumber);
      _meetingReferences.add(reference);
    });
  }

  void _removeMeetingReference(CashAdvanceMeetingReference reference) {
    setState(() => _meetingReferences.remove(reference));
  }

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
      meetingReferences: List.of(_meetingReferences),
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
                const SizedBox(height: 20),
                _sectionHeader(theme, 'Meeting Reference (optional)'),
                const SizedBox(height: 8),
                ..._buildMeetingReferenceTiles(),
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

  List<Widget> _buildMeetingReferenceTiles() {
    if (_meetingReferences.isEmpty) {
      return [_buildAddReferenceTile()];
    }
    return [
      for (final ref in _meetingReferences) ...[
        _buildMeetingReferenceCard(ref),
        const SizedBox(height: 10),
      ],
      _buildAddReferenceTile(),
    ];
  }

  Widget _buildAddReferenceTile() {
    return InkWell(
      onTap: _pickMinutesReference,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline,
                color: Colors.deepOrange[400], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _meetingReferences.isEmpty
                        ? 'Link to Meeting Minutes'
                        : 'Add Another Action Item',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  Text(
                    'Tap to select minutes & action item',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingReferenceCard(CashAdvanceMeetingReference ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepOrange.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.deepOrange.shade50,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.article_outlined, color: Colors.deepOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.minutesLabel,
                  style: TextStyle(fontSize: 12, color: Colors.deepOrange[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ref.actionItemNumber,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange[700],
                        ),
                      ),
                    ),
                    if (ref.actionItemAction != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          ref.actionItemAction!,
                          style: TextStyle(fontSize: 11, color: Colors.teal[700]),
                        ),
                      ),
                    ],
                  ],
                ),
                if (ref.actionItemTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ref.actionItemTitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (ref.actionItemDescription != null &&
                    ref.actionItemDescription!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _plainText(ref.actionItemDescription!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            color: Colors.grey[500],
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: () => _removeMeetingReference(ref),
          ),
        ],
      ),
    );
  }

  String _plainText(String text) {
    if (text.startsWith('[')) {
      try {
        final List<dynamic> ops = jsonDecode(text) as List;
        return ops
            .where((op) => op is Map && op['insert'] is String)
            .map((op) => op['insert'] as String)
            .join()
            .trim();
      } catch (_) {}
    }
    return text;
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
