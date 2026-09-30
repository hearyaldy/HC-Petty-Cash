import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/approval_item.dart';
import '../../models/planning_step_status.dart';
import '../../state/planning_project_provider.dart';

/// Step 8 — Approvals, mirroring Workflow HC's own
/// "Pre-production Approval Checklist" table (Item | Status | Owner |
/// Notes), applied here to sign off the Planning stage before moving
/// a project to Pre-production.
class ApprovalsStep extends StatefulWidget {
  const ApprovalsStep({super.key});

  @override
  State<ApprovalsStep> createState() => _ApprovalsStepState();
}

class _ApprovalsStepState extends State<ApprovalsStep> {
  late List<ApprovalItem> _approvals;

  @override
  void initState() {
    super.initState();
    final approvals = context.read<PlanningProjectProvider>().project?.approvals ?? const [];
    _approvals = approvals.isNotEmpty ? List.of(approvals) : ApprovalItem.defaultPlanningChecklist();
  }

  void _updateItem(int index, ApprovalItem updated) {
    setState(() {
      final next = List.of(_approvals);
      next[index] = updated;
      _approvals = next;
    });
    context.read<PlanningProjectProvider>().saveApprovals(_approvals);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('8. Approvals', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Sign off each Planning step before moving into Pre-production.'),
          const SizedBox(height: 20),
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
