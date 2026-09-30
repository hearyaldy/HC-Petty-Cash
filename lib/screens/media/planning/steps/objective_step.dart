import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';
import '../../../../widgets/media_ai_draft_button.dart';

/// Step 1 — General Objective.
class ObjectiveStep extends StatefulWidget {
  const ObjectiveStep({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<ObjectiveStep> createState() => _ObjectiveStepState();
}

class _ObjectiveStepState extends State<ObjectiveStep> {
  final _bulletsController = TextEditingController();
  late TextEditingController _painsController;
  late TextEditingController _whyController;
  late TextEditingController _conditionsController;

  @override
  void initState() {
    super.initState();
    final objective =
        context.read<MediaPlanningProvider>().planning?.objective ?? const PlanningObjective();
    _painsController = TextEditingController(text: objective.pains.join('\n'));
    _whyController = TextEditingController(text: objective.whyItExists);
    _conditionsController = TextEditingController(text: objective.practicalConditions);
  }

  @override
  void dispose() {
    _bulletsController.dispose();
    _painsController.dispose();
    _whyController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<MediaPlanningProvider>();
    final ok = await provider.saveObjective(
      PlanningObjective(
        pains: _painsController.text.split('\n').where((l) => l.trim().isNotEmpty).toList(),
        whyItExists: _whyController.text,
        practicalConditions: _conditionsController.text,
        metricPriority: provider.planning?.objective.metricPriority ?? const [],
      ),
    );
    if (ok) widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaPlanningProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. General Objective', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'What pains do we need to attend? Why does this program exist? '
            'Do we have practical conditions to meet this pain?',
          ),
          const SizedBox(height: 20),
          Text('Have a few rough notes? Let AI expand them:',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _bulletsController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'e.g. "Youth drifting from church media", "Want a Gen Z-facing short-form show"',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          MediaAiDraftButton(
            label: 'Draft objective with AI',
            isBusy: provider.isDrafting,
            onPressed: () {
              final bullets = _bulletsController.text
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .toList();
              if (bullets.isEmpty) return;
              provider.draftObjectiveWithAi(bullets).then((_) {
                final o = provider.planning?.objective;
                if (o != null) {
                  _painsController.text = o.pains.join('\n');
                  _whyController.text = o.whyItExists;
                  _conditionsController.text = o.practicalConditions;
                }
              });
            },
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 8),
            Text(provider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const Divider(height: 40),
          TextField(
            controller: _painsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Pains we need to attend (one per line)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _whyController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Why does this program exist?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _conditionsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Do we have practical conditions to meet this pain?',
              border: OutlineInputBorder(),
            ),
          ),
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
