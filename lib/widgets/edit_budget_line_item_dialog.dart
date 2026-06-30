import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_line_item.dart';
import '../models/enums.dart';

class EditBudgetLineItemDialog extends StatefulWidget {
  final BudgetLineItem item;
  const EditBudgetLineItemDialog({super.key, required this.item});

  @override
  State<EditBudgetLineItemDialog> createState() =>
      _EditBudgetLineItemDialogState();
}

class _EditBudgetLineItemDialogState extends State<EditBudgetLineItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  String? _linkedTxCategory;
  String? _linkedReportType;
  List<String> _customCategories = [];

  static const _reportTypes = [
    (value: 'traveling', label: 'Traveling Reports'),
    (value: 'income', label: 'Income Reports'),
    (value: 'petty_cash', label: 'Petty Cash Reports'),
    (value: 'project', label: 'Project Reports'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _amountCtrl = TextEditingController(
      text: widget.item.budgetAmount == 0
          ? ''
          : widget.item.budgetAmount.toStringAsFixed(2),
    );
    _linkedTxCategory = widget.item.linkedTransactionCategory;
    _linkedReportType = widget.item.linkedReportType;
    // Seed current value immediately if it's already a custom category
    if (_linkedTxCategory != null &&
        !ExpenseCategory.values.any((e) => e.name == _linkedTxCategory)) {
      _customCategories = [_linkedTxCategory!];
    }
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
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    Navigator.of(context).pop(
      widget.item.copyWith(
        name: _nameCtrl.text.trim(),
        budgetAmount: amount,
        linkedTransactionCategory: _linkedTxCategory,
        linkedReportType: _linkedReportType,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00', 'en_US');

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.scheduleCode,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.item.sectionTitle,
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

                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Line Item Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Budget Amount
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

                // Auto-link section
                Text(
                  'Auto-link Actuals (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                // Transaction category
                DropdownButtonFormField<String?>(
                  key: ValueKey(
                    'txCat_${_linkedTxCategory}_${_customCategories.length}',
                  ),
                  initialValue: _linkedTxCategory,
                  decoration: InputDecoration(
                    labelText: 'Link to Transaction Category',
                    border: const OutlineInputBorder(),
                    helperText: _linkedReportType != null
                        ? 'Both links are summed — use only one to avoid double-counting'
                        : 'Sums approved transactions of this category',
                    helperStyle: _linkedReportType != null
                        ? const TextStyle(color: Colors.orange, fontSize: 11)
                        : null,
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

                // Report type
                DropdownButtonFormField<String?>(
                  key: ValueKey('rptType_$_linkedReportType'),
                  initialValue: _linkedReportType,
                  decoration: InputDecoration(
                    labelText: 'Link to Report Type',
                    border: const OutlineInputBorder(),
                    helperText: _linkedTxCategory != null
                        ? 'Both links are summed — use only one to avoid double-counting'
                        : 'Sums totals from all approved reports of this type',
                    helperStyle: _linkedTxCategory != null
                        ? const TextStyle(color: Colors.orange, fontSize: 11)
                        : null,
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

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: _save, child: const Text('Save')),
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
