import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';

/// Step 7 — Budget.
///
/// The total is always the sum of itemized budget entries (e.g. "Camera
/// rental — 5,000") rather than one free-typed number — a producer adds
/// as many line items as needed. The phase breakdown below is
/// rule-based, not a Gemini call: it applies Workflow HC's own
/// published benchmark split (10% Pre-production / 30% Production /
/// 10% Post-production / 45% Distribution / 5% Closure) to that total.
class BudgetStep extends StatefulWidget {
  const BudgetStep({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<BudgetStep> createState() => _BudgetStepState();
}

class _BudgetItemControllers {
  _BudgetItemControllers({String label = '', String amount = ''})
      : label = TextEditingController(text: label),
        amount = TextEditingController(text: amount);

  final TextEditingController label;
  final TextEditingController amount;

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class _BudgetStepState extends State<BudgetStep> {
  final List<_BudgetItemControllers> _items = [];
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    final budget = context.read<MediaPlanningProvider>().planning?.budget;
    _currency = budget?.currency ?? 'USD';
    if (budget != null && budget.items.isNotEmpty) {
      for (final item in budget.items) {
        _items.add(_BudgetItemControllers(
          label: item.label,
          amount: item.amount == 0 ? '' : item.amount.toStringAsFixed(0),
        ));
      }
    } else {
      _items.add(_BudgetItemControllers());
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _total => _items.fold<double>(
        0,
        (sum, item) => sum + (double.tryParse(item.amount.text) ?? 0),
      );

  List<PlanningBudgetItem> get _budgetItems => _items
      .where((c) => c.label.text.trim().isNotEmpty || (double.tryParse(c.amount.text) ?? 0) > 0)
      .map((c) => PlanningBudgetItem(
            label: c.label.text.trim(),
            amount: double.tryParse(c.amount.text) ?? 0,
          ))
      .toList();

  Future<void> _save() async {
    final ok = await context.read<MediaPlanningProvider>().saveBudget(
          PlanningBudget(items: _budgetItems, currency: _currency),
        );
    if (ok) widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaPlanningProvider>();
    final budget = PlanningBudget(items: _budgetItems, currency: _currency);

    Widget phaseRow(String label, String note, double amount, double pct) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(note, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text('${(pct * 100).toStringAsFixed(0)}%'),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: Text(
                '$_currency ${amount.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7. Budget', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Add every line item you expect to spend on — the total and phase '
              'breakdown below update as you go.'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('Budget items', style: Theme.of(context).textTheme.titleSmall),
              ),
              DropdownButton<String>(
                value: _currency,
                items: const ['USD', 'THB', 'MYR', 'VND', 'KHR', 'LAK', 'BND']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? _currency),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: item.label,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Camera rental',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: item.amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Amount',
                        prefixText: '$_currency ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove item',
                    onPressed: _items.length == 1
                        ? null
                        : () => setState(() {
                              _items[index].dispose();
                              _items.removeAt(index);
                            }),
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
            onPressed: () => setState(() => _items.add(_BudgetItemControllers())),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total budget', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '$_currency ${_total.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Split — Workflow HC benchmark', style: Theme.of(context).textTheme.titleSmall),
          const Divider(),
          phaseRow('Pre-production', 'Planning, research, script, initial organization',
              budget.preProduction, budget.split.preProductionPct),
          phaseRow('Production', 'Recruitment, technical team, operation, execution',
              budget.production, budget.split.productionPct),
          phaseRow('Post-production', 'Editing, finishing, audio and image adjustments',
              budget.postProduction, budget.split.postProductionPct),
          phaseRow('Distribution', 'Distribution, media, boosting, promotion',
              budget.distribution, budget.split.distributionPct),
          phaseRow('Closure & documentation', 'Reports, final organization, registration',
              budget.closure, budget.split.closurePct),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(provider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.pink),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
