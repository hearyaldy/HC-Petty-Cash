import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';

/// Step 8 — Approvals, mirroring Workflow HC's own "Pre-production
/// Approval Checklist" table (Item | Status | Owner | Notes), applied
/// here to sign off the Planning stage before moving a production into
/// Pre-production / In Production.
class ApprovalsStep extends StatefulWidget {
  const ApprovalsStep({super.key});

  @override
  State<ApprovalsStep> createState() => _ApprovalsStepState();
}

class _ApprovalsStepState extends State<ApprovalsStep> {
  late List<PlanningApprovalItem> _approvals;

  @override
  void initState() {
    super.initState();
    final approvals = context.read<MediaPlanningProvider>().planning?.approvals ?? const [];
    _approvals =
        approvals.isNotEmpty ? List.of(approvals) : PlanningApprovalItem.defaultChecklist();
  }

  void _updateItem(int index, PlanningApprovalItem updated) {
    setState(() {
      final next = List.of(_approvals);
      next[index] = updated;
      _approvals = next;
    });
    context.read<MediaPlanningProvider>().saveApprovals(_approvals);
  }

  @override
  Widget build(BuildContext context) {
    final allComplete =
        _approvals.isNotEmpty && _approvals.every((a) => a.status == PlanningStepStatus.complete);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('8. Approvals', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Sign off each Planning step before moving into Pre-production.'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: allComplete ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: allComplete ? Colors.green.shade200 : Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  allComplete ? Icons.check_circle : Icons.info_outline,
                  color: allComplete ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allComplete
                        ? 'Planning is signed off — this production is ready to move into production.'
                        : 'Planning is not fully signed off yet. Update the production status to '
                            '"In Production" only once every item below is Complete.',
                    style: TextStyle(
                      color: allComplete ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._approvals.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(item.item)),
                    Expanded(
                      flex: 2,
                      child: DropdownButton<PlanningStepStatus>(
                        isExpanded: true,
                        value: item.status,
                        items: PlanningStepStatus.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: (s) {
                          if (s != null) _updateItem(index, item.copyWith(status: s));
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: item.owner,
                        decoration: const InputDecoration(hintText: 'Owner'),
                        onChanged: (v) => _updateItem(index, item.copyWith(owner: v)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
