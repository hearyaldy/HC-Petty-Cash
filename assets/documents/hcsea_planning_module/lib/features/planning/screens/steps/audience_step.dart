import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/planning_project_provider.dart';
import '../../widgets/ai_draft_button.dart';

/// Step 2 — Audience, including the Audience Synthesizer AI assistant.
class AudienceStep extends StatefulWidget {
  const AudienceStep({super.key});

  @override
  State<AudienceStep> createState() => _AudienceStepState();
}

class _AudienceStepState extends State<AudienceStep> {
  final _notesController = TextEditingController();
  late final Map<String, TextEditingController> _fieldControllers;

  static const _fields = [
    ('gender', 'Gender'),
    ('ageRange', 'Age'),
    ('socialSituation', 'Social situation'),
    ('activity', 'Activity (student, entrepreneur, farmer, etc.)'),
    ('geography', 'Geography'),
    ('notAudience', 'Who is NOT the target audience'),
  ];

  @override
  void initState() {
    super.initState();
    final audience = context.read<PlanningProjectProvider>().project?.audience;
    _fieldControllers = {
      'gender': TextEditingController(text: audience?.gender ?? ''),
      'ageRange': TextEditingController(text: audience?.ageRange ?? ''),
      'socialSituation': TextEditingController(text: audience?.socialSituation ?? ''),
      'activity': TextEditingController(text: audience?.activity ?? ''),
      'geography': TextEditingController(text: audience?.geography ?? ''),
      'notAudience': TextEditingController(text: audience?.notAudience ?? ''),
    };
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
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
          Text('2. Audience', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Gender, age, social situation, activity, geography — '
            'and who is not the target audience of this project.',
          ),
          const SizedBox(height: 20),

          Text('Paste raw notes or Survey C observations, and let AI structure them:',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'e.g. "Mostly urban young adults in KL, university students and young professionals, '
                  'active on TikTok and Instagram, skeptical of anything that feels like a sermon"',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          AiDraftButton(
            label: 'Synthesize audience with AI',
            isBusy: provider.isDrafting,
            onPressed: () {
              if (_notesController.text.trim().isEmpty) return;
              provider.synthesizeAudienceWithAi(_notesController.text).then((_) {
                final a = provider.project?.audience;
                if (a == null) return;
                _fieldControllers['gender']!.text = a.gender;
                _fieldControllers['ageRange']!.text = a.ageRange;
                _fieldControllers['socialSituation']!.text = a.socialSituation;
                _fieldControllers['activity']!.text = a.activity;
                _fieldControllers['geography']!.text = a.geography;
                _fieldControllers['notAudience']!.text = a.notAudience;
              });
            },
          ),

          const Divider(height: 40),

          for (final field in _fields) ...[
            TextField(
              controller: _fieldControllers[field.$1],
              maxLines: field.$1 == 'notAudience' ? 3 : 2,
              decoration: InputDecoration(
                labelText: field.$2,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // TODO: add `saveAudience()` to PlanningProjectProvider — same
          // pattern as `saveObjective()` in that class — then call it here
          // with an Audience built from the controllers above.
          FilledButton(
            onPressed: null,
            child: const Text('Save (wire up saveAudience())'),
          ),
        ],
      ),
    );
  }
}
