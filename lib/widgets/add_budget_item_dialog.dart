import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/enums.dart';

/// Data returned by the dialog — enough for the provider to create the item.
class NewBudgetItemData {
  final String scheduleCode;
  final String sectionTitle;
  final String sectionType;
  final String name;
  final double budgetAmount;
  final String? linkedTransactionCategory;
  final String? linkedReportType;

  const NewBudgetItemData({
    required this.scheduleCode,
    required this.sectionTitle,
    required this.sectionType,
    required this.name,
    required this.budgetAmount,
    this.linkedTransactionCategory,
    this.linkedReportType,
  });
}

class AddBudgetItemDialog extends StatefulWidget {
  /// Pre-filled when adding to an existing section. Null when creating a new section.
  final String? scheduleCode;
  final String? sectionTitle;

  /// Pre-selected tab type ('income', 'expense', 'appropriation').
  final String sectionType;

  const AddBudgetItemDialog({
    super.key,
    this.scheduleCode,
    this.sectionTitle,
    required this.sectionType,
  });

  bool get isNewSection => scheduleCode == null;

  @override
  State<AddBudgetItemDialog> createState() => _AddBudgetItemDialogState();
}

class _AddBudgetItemDialogState extends State<AddBudgetItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _sectionTitleCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  String? _linkedTxCategory;
  String? _linkedReportType;
  late String _sectionType;
  List<String> _customCategories = [];
  bool _isSubmitting = false;

  static const _sectionTypes = [
    (value: 'income', label: 'Income'),
    (value: 'expense', label: 'Expense'),
    (value: 'appropriation', label: 'Appropriation'),
  ];

  static const _reportTypes = [
    (value: 'traveling', label: 'Traveling Reports'),
    (value: 'income', label: 'Income Reports'),
    (value: 'petty_cash', label: 'Petty Cash Reports'),
    (value: 'project', label: 'Project Reports'),
  ];

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.scheduleCode ?? '');
    _sectionTitleCtrl = TextEditingController(text: widget.sectionTitle ?? '');
    _nameCtrl = TextEditingController();
    _amountCtrl = TextEditingController();
    _sectionType = widget.sectionType;
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('transactions')
          .where('customCategory', isNotEqualTo: '')
          .limit(500)
          .get();
      final cats = <String>{};
      for (final doc in snap.docs) {
        final c = doc.data()['customCategory'] as String?;
        if (c != null && c.isNotEmpty) cats.add(c);
      }
      if (mounted) setState(() => _customCategories = cats.toList()..sort());
    } catch (_) {}
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _sectionTitleCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    Navigator.of(context).pop(
      NewBudgetItemData(
        scheduleCode: _codeCtrl.text.trim(),
        sectionTitle: _sectionTitleCtrl.text.trim(),
        sectionType: _sectionType,
        name: _nameCtrl.text.trim(),
        budgetAmount: amount,
        linkedTransactionCategory: _linkedTxCategory,
        linkedReportType: _linkedReportType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final isNew = widget.isNewSection;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title row ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isNew
                            ? Icons.create_new_folder_outlined
                            : Icons.add_circle_outline,
                        color: cs.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNew ? 'New Budget Section' : 'Add Line Item',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isNew)
                            Text(
                              '${widget.scheduleCode} · ${widget.sectionTitle}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Section fields (new section only) ──────────────────────
                if (isNew) ...[
                  Text(
                    'Section Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.none,
                          decoration: const InputDecoration(
                            labelText: 'Code *',
                            hintText: 'S-26',
                            border: OutlineInputBorder(),
                            helperText: 'e.g. S-26',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sectionTitleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Section Title *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('type_$_sectionType'),
                    initialValue: _sectionType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _sectionTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.value,
                            child: Text(t.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _sectionType = v!),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    'First Line Item',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Line item name ─────────────────────────────────────────
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Line Item Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // ── Budget amount ──────────────────────────────────────────
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Budget Amount (฿)',
                    border: const OutlineInputBorder(),
                    prefixText: '฿ ',
                    helperText: _amountCtrl.text.isNotEmpty
                        ? 'Formatted: ฿${fmt.format(double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0)}'
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (double.tryParse(v.replaceAll(',', '')) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Auto-link section ──────────────────────────────────────
                Text(
                  'Auto-link Actuals (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  key: ValueKey(
                    'txCat_${_linkedTxCategory}_${_customCategories.length}',
                  ),
                  initialValue: _linkedTxCategory,
                  decoration: const InputDecoration(
                    labelText: 'Link to Transaction Category',
                    border: OutlineInputBorder(),
                    helperText: 'Sums approved transactions of this category',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— None —'),
                    ),
                    ...ExpenseCategory.values.map(
                      (e) => DropdownMenuItem(
                        value: e.name,
                        child: Text(e.displayName),
                      ),
                    ),
                    if (_customCategories.isNotEmpty) ...[
                      const DropdownMenuItem(
                        value: '__sep__',
                        enabled: false,
                        child: Text(
                          '── Custom Categories ──',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      ..._customCategories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                  ],
                  onChanged: (v) {
                    if (v == '__sep__') return;
                    setState(() => _linkedTxCategory = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('rptType_$_linkedReportType'),
                  initialValue: _linkedReportType,
                  decoration: const InputDecoration(
                    labelText: 'Link to Report Type',
                    border: OutlineInputBorder(),
                    helperText: 'Sums totals from approved reports',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— None —'),
                    ),
                    ..._reportTypes.map(
                      (r) => DropdownMenuItem(
                        value: r.value,
                        child: Text(r.label),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _linkedReportType = v),
                ),
                const SizedBox(height: 24),

                // ── Actions ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _save,
                      icon: Icon(
                        isNew ? Icons.create_new_folder : Icons.add,
                        size: 16,
                      ),
                      label: Text(isNew ? 'Create Section' : 'Add Item'),
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
