import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget_plan.dart';
import '../../state/planning_project_provider.dart';

/// Step 7 — Budget.
///
/// The Budget Allocator from the proposal is deliberately rule-based,
/// not a Gemini call: it applies Workflow HC's own published benchmark
/// split. This screen just needs a total; the phase breakdown below
/// updates live. Phase 4 of the roadmap (cross-project memory) is
/// where this benchmark gets replaced by an average of the user's own
/// logged projects — until then, [BudgetPhaseSplit.workflowHcBenchmark]
/// is the right default.
class BudgetStep extends StatefulWidget {
  const BudgetStep({super.key});

  @override
  State<BudgetStep> createState() => _BudgetStepState();
}

class _BudgetStepState extends State<BudgetStep> {
  late final TextEditingController _totalController;
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    final budget = context.read<PlanningProjectProvider>().project?.budget;
    _totalController = TextEditingController(
      text: budget != null && budget.total > 0 ? budget.total.toStringAsFixed(0) : '',
    );
    _currency = budget?.currency ?? 'USD';
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<PlanningProjectProvider>();
    final total = double.tryParse(_totalController.text) ?? 0;
    final budget = BudgetPlan(total: total, currency: _currency);

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
          const Text('Defines and estimates financial resources per phase.'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _totalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total project budget',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _currency,
                items: const ['USD', 'THB', 'MYR', 'VND', 'KHR', 'LAK', 'BND']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? _currency),
              ),
            ],
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: null,
            child: const Text('Save (wire up saveBudget())'),
          ),
        ],
      ),
    );
  }
}
