import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/market_research.dart';
import '../../state/planning_project_provider.dart';
import '../../widgets/ai_draft_button.dart';
import '../../widgets/reference_card.dart';

/// Step 4 — Format: market research, including the Reference Scout
/// AI assistant.
class MarketResearchStep extends StatefulWidget {
  const MarketResearchStep({super.key});

  @override
  State<MarketResearchStep> createState() => _MarketResearchStepState();
}

class _MarketResearchStepState extends State<MarketResearchStep> {
  final _ideaController = TextEditingController();
  final _platformController = TextEditingController();
  List<ProgramReference> _references = const [];
  ProgramAspectRatio _aspectRatio = ProgramAspectRatio.landscape169;
  String _style = '';

  @override
  void initState() {
    super.initState();
    final mr = context.read<PlanningProjectProvider>().project?.marketResearch;
    if (mr != null) {
      _references = List.of(mr.references);
      _aspectRatio = mr.aspectRatio;
      _style = mr.style;
    }
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _platformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanningProjectProvider>();

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
              labelText: 'Platform you\'re leaning toward (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          AiDraftButton(
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
                final mr = provider.project?.marketResearch;
                if (mr == null) return;
                setState(() {
                  _references = List.of(mr.references);
                  _aspectRatio = mr.aspectRatio;
                  _style = mr.style;
                });
              });
            },
          ),

          const Divider(height: 40),

          Text('References (Workflow HC asks for exactly 3)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          ..._references.asMap().entries.map(
                (entry) => ReferenceCard(
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
                _references = List.of(_references)..add(const ProgramReference());
              }),
            ),

          const SizedBox(height: 20),
          Text('Style', style: Theme.of(context).textTheme.titleSmall),
          TextFormField(
            initialValue: _style,
            decoration: const InputDecoration(
              hintText: 'podcast, documentary, shorts, talk show, etc.',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _style = v,
          ),

          const SizedBox(height: 20),
          Text('Aspect ratio', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<ProgramAspectRatio>(
            title: const Text('16:9 (landscape)'),
            value: ProgramAspectRatio.landscape169,
            groupValue: _aspectRatio,
            onChanged: (v) => setState(() => _aspectRatio = v!),
          ),
          RadioListTile<ProgramAspectRatio>(
            title: const Text('9:16 (portrait)'),
            value: ProgramAspectRatio.portrait916,
            groupValue: _aspectRatio,
            onChanged: (v) => setState(() => _aspectRatio = v!),
          ),

          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              // TODO: add `saveMarketResearch()` to PlanningProjectProvider
              // (same pattern as saveObjective) and call it with:
              // MarketResearch(references: _references, style: _style, aspectRatio: _aspectRatio)
            },
            child: const Text('Save (wire up saveMarketResearch())'),
          ),
        ],
      ),
    );
  }
}
