import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planning_project_provider.dart';

/// Step 5 — Program Identity.
///
/// No AI assistant in this scaffold — naming, moodboards, and key
/// visuals are creative decisions Workflow HC treats as a design
/// task, not a research task, so they stay manual for now. A "Draft
/// name options with AI" button would follow the same
/// AiDraftButton + GeminiPlanningService pattern as the other steps
/// if wanted later.
class ProgramIdentityStep extends StatefulWidget {
  const ProgramIdentityStep({super.key});

  @override
  State<ProgramIdentityStep> createState() => _ProgramIdentityStepState();
}

class _ProgramIdentityStepState extends State<ProgramIdentityStep> {
  late final TextEditingController _briefingController;
  late final TextEditingController _nameController;
  late final TextEditingController _fontController;
  late final TextEditingController _paletteController;
  late final TextEditingController _keyVisualController;

  @override
  void initState() {
    super.initState();
    final identity = context.read<PlanningProjectProvider>().project?.identity;
    _briefingController = TextEditingController(text: identity?.briefing ?? '');
    _nameController = TextEditingController(text: identity?.programName ?? '');
    _fontController = TextEditingController(text: identity?.fontChoice ?? '');
    _paletteController = TextEditingController(text: identity?.colorPalette ?? '');
    _keyVisualController = TextEditingController(text: identity?.keyVisualDescription ?? '');
  }

  @override
  void dispose() {
    _briefingController.dispose();
    _nameController.dispose();
    _fontController.dispose();
    _paletteController.dispose();
    _keyVisualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<PlanningProjectProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('5. Program Identity', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Briefing, naming, moodboard, font/logo/palette, key visual, and derivations.'),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Program name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _briefingController,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Program description (briefing)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _fontController,
            decoration: const InputDecoration(labelText: 'Font choice', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _paletteController,
            decoration: const InputDecoration(
                labelText: 'Color palette (hex list or description)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _keyVisualController,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Key Visual (KV) description', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('Derivations needed', style: Theme.of(context).textTheme.titleSmall),
          const Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Thumbnail (YouTube)')),
              Chip(label: Text('Reel')),
              Chip(label: Text('Square Post')),
              Chip(label: Text('Carousel')),
              Chip(label: Text('Story')),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: null,
            child: const Text('Save (wire up saveProgramIdentity())'),
          ),
        ],
      ),
    );
  }
}
