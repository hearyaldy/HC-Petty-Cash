import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';
import '../../../../widgets/media_ai_draft_button.dart';

/// Step 3 — Strategic Intent, sharing the Objective & Intent Co-writer
/// assistant with the Objective step.
class StrategicIntentStep extends StatefulWidget {
  const StrategicIntentStep({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<StrategicIntentStep> createState() => _StrategicIntentStepState();
}

class _StrategicIntentStepState extends State<StrategicIntentStep> {
  final _bulletsController = TextEditingController();
  late final TextEditingController _transformationController;
  late final TextEditingController _attractionController;
  late final TextEditingController _retentionController;
  late final TextEditingController _metricsController;

  @override
  void initState() {
    super.initState();
    final intent = context.read<MediaPlanningProvider>().planning?.strategicIntent;
    _transformationController = TextEditingController(text: intent?.transformation ?? '');
    _attractionController = TextEditingController(text: intent?.attractionHook ?? '');
    _retentionController = TextEditingController(text: intent?.retentionPlan ?? '');
    _metricsController = TextEditingController(text: (intent?.metrics ?? const []).join(', '));
  }

  @override
  void dispose() {
    _bulletsController.dispose();
    _transformationController.dispose();
    _attractionController.dispose();
    _retentionController.dispose();
    _metricsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await context.read<MediaPlanningProvider>().saveStrategicIntent(
          PlanningStrategicIntent(
            transformation: _transformationController.text,
            attractionHook: _attractionController.text,
            retentionPlan: _retentionController.text,
            metrics: _metricsController.text
                .split(',')
                .map((m) => m.trim())
                .where((m) => m.isNotEmpty)
                .toList(),
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
          Text('3. Strategic Intent', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'What transformation do we want? What attracts the audience? '
            'How do we build return visits? What metrics guide us?',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bulletsController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Rough notes — one idea per line',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          MediaAiDraftButton(
            label: 'Draft strategic intent with AI',
            isBusy: provider.isDrafting,
            onPressed: () {
              final bullets = _bulletsController.text
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .toList();
              if (bullets.isEmpty) return;
              provider.draftStrategicIntentWithAi(bullets).then((_) {
                final si = provider.planning?.strategicIntent;
                if (si == null) return;
                _transformationController.text = si.transformation;
                _attractionController.text = si.attractionHook;
                _retentionController.text = si.retentionPlan;
                _metricsController.text = si.metrics.join(', ');
              });
            },
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 8),
            Text(provider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const Divider(height: 40),
          TextField(
            controller: _transformationController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What transformation do we want to generate?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _attractionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What will attract the audience?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _retentionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'How do we build audience to return regularly?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _metricsController,
            decoration: const InputDecoration(
              labelText: 'Metrics (comma-separated)',
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
