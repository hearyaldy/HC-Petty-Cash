import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';
import '../../../../widgets/media_ai_draft_button.dart';
import '../../../../widgets/media_reference_card.dart';

/// Step 4 — Format: market research, including the Reference Scout AI
/// assistant.
class MarketResearchStep extends StatefulWidget {
  const MarketResearchStep({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<MarketResearchStep> createState() => _MarketResearchStepState();
}

class _MarketResearchStepState extends State<MarketResearchStep> {
  final _ideaController = TextEditingController();
  final _platformController = TextEditingController();
  List<PlanningReference> _references = const [];
  PlanningAspectRatio _aspectRatio = PlanningAspectRatio.landscape169;
  final _styleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final mr = context.read<MediaPlanningProvider>().planning?.marketResearch;
    if (mr != null) {
      _references = List.of(mr.references);
      _aspectRatio = mr.aspectRatio;
      _styleController.text = mr.style;
    }
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _platformController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await context.read<MediaPlanningProvider>().saveMarketResearch(
          PlanningMarketResearch(
            references: _references,
            style: _styleController.text,
            aspectRatio: _aspectRatio,
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
          Text('4. Format — Market Research', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Submit 3 references from similar or related programs. Choose the '
            'platform, style, and aspect ratio (16:9 landscape / 9:16 portrait).',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ideaController,
            decoration: const InputDecoration(
              labelText: 'Program idea (one or two sentences)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _platformController,
            decoration: const InputDecoration(
              labelText: "Platform you're leaning toward (optional)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          MediaAiDraftButton(
            label: 'Scout references with AI',
            isBusy: provider.isDrafting,
            onPressed: () {
              if (_ideaController.text.trim().isEmpty) return;
              provider
                  .scoutReferencesWithAi(
                programIdea: _ideaController.text,
                preferredPlatform:
                    _platformController.text.trim().isEmpty ? null : _platformController.text,
              )
                  .then((_) {
                final mr = provider.planning?.marketResearch;
                if (mr == null) return;
                setState(() {
                  _references = List.of(mr.references);
                  _aspectRatio = mr.aspectRatio;
                  _styleController.text = mr.style;
                });
              });
            },
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 8),
            Text(provider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const Divider(height: 40),
          Text('References (Workflow HC asks for exactly 3)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          ..._references.asMap().entries.map(
                (entry) => MediaReferenceCard(
                  reference: entry.value,
                  onChanged: (updated) => setState(() {
                    final next = List.of(_references);
                    next[entry.key] = updated;
                    _references = next;
                  }),
                  onRemove: () => setState(() {
                    final next = List.of(_references)..removeAt(entry.key);
                    _references = next;
                  }),
                ),
              ),
          if (_references.length < 3)
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add reference'),
              onPressed: () => setState(() {
                _references = List.of(_references)..add(const PlanningReference());
              }),
            ),
          const SizedBox(height: 20),
          Text('Style', style: Theme.of(context).textTheme.titleSmall),
          TextFormField(
            controller: _styleController,
            decoration: const InputDecoration(
              hintText: 'podcast, documentary, shorts, talk show, etc.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Aspect ratio', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<PlanningAspectRatio>(
            title: const Text('16:9 (landscape)'),
            value: PlanningAspectRatio.landscape169,
            groupValue: _aspectRatio,
            onChanged: (v) => setState(() => _aspectRatio = v!),
          ),
          RadioListTile<PlanningAspectRatio>(
            title: const Text('9:16 (portrait)'),
            value: PlanningAspectRatio.portrait916,
            groupValue: _aspectRatio,
            onChanged: (v) => setState(() => _aspectRatio = v!),
          ),
          const SizedBox(height: 12),
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
