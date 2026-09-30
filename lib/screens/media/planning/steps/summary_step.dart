import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';

final _hexTokenPattern = RegExp(r'#?[0-9A-Fa-f]{6}\b');

List<String> _paletteHexCodes(String palette) {
  final seen = <String>{};
  for (final match in _hexTokenPattern.allMatches(palette)) {
    seen.add('#${match.group(0)!.replaceFirst('#', '').toUpperCase()}');
  }
  return seen.toList();
}

Color _hexToColor(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

/// A read-only review of everything filled in across the 7 Planning
/// sections, shown right before Approvals so a producer can check the
/// whole document at a glance instead of clicking back through every
/// step. Each section heading jumps straight back to that step for a
/// quick edit.
class SummaryStep extends StatelessWidget {
  const SummaryStep({super.key, required this.onContinue, required this.onEditStep});

  final VoidCallback onContinue;
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final planning = context.watch<MediaPlanningProvider>().planning;
    if (planning == null) return const SizedBox();
    final dateFormat = DateFormat.yMMMd();

    Widget field(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            Text(value.isEmpty ? '—' : value),
          ],
        ),
      );
    }

    Widget section({
      required String title,
      required int stepIndex,
      required bool isFilled,
      required List<Widget> children,
    }) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isFilled ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: isFilled ? Colors.green : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    onPressed: () => onEditStep(stepIndex),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: Colors.pink.shade700),
                  ),
                ],
              ),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '${planning.budget.currency} ', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review before Approvals', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Check everything below, or edit a section, before signing off.'),
          const SizedBox(height: 20),
          section(
            title: '1. General Objective',
            stepIndex: 0,
            isFilled: !planning.objective.isEmpty,
            children: [
              field('Pains to attend', planning.objective.pains.join(', ')),
              field('Why this program exists', planning.objective.whyItExists),
              field('Practical conditions', planning.objective.practicalConditions),
            ],
          ),
          section(
            title: '2. Audience',
            stepIndex: 1,
            isFilled: !planning.audience.isEmpty,
            children: [
              field('Gender / Age', '${planning.audience.gender} · ${planning.audience.ageRange}'),
              field('Social situation / Activity',
                  '${planning.audience.socialSituation} · ${planning.audience.activity}'),
              field('Geography', planning.audience.geography),
              field('Who is NOT the target audience', planning.audience.notAudience),
            ],
          ),
          section(
            title: '3. Strategic Intent',
            stepIndex: 2,
            isFilled: !planning.strategicIntent.isEmpty,
            children: [
              field('Transformation', planning.strategicIntent.transformation),
              field('What attracts the audience', planning.strategicIntent.attractionHook),
              field('Retention plan', planning.strategicIntent.retentionPlan),
              field('Metrics', planning.strategicIntent.metrics.join(', ')),
            ],
          ),
          section(
            title: '4. Format — Market Research',
            stepIndex: 3,
            isFilled: !planning.marketResearch.isEmpty,
            children: [
              field('References',
                  planning.marketResearch.references.isEmpty
                      ? ''
                      : planning.marketResearch.references.map((r) => r.title).join(', ')),
              field('Platforms', planning.marketResearch.preferredPlatforms.join(', ')),
              field('Style / Aspect ratio',
                  '${planning.marketResearch.style} · ${planning.marketResearch.aspectRatio.label}'),
            ],
          ),
          section(
            title: '5. Program Identity',
            stepIndex: 4,
            isFilled: !planning.identity.isEmpty,
            children: [
              field('Program name', planning.identity.programName),
              field('Briefing', planning.identity.briefing),
              field('Font choice', planning.identity.fontChoice),
              field('Color palette', planning.identity.colorPalette),
              if (_paletteHexCodes(planning.identity.colorPalette).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hex in _paletteHexCodes(planning.identity.colorPalette))
                        Chip(
                          avatar: CircleAvatar(backgroundColor: _hexToColor(hex), radius: 9),
                          label: Text(hex, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          section(
            title: '6. Distribution',
            stepIndex: 5,
            isFilled: !planning.distribution.isEmpty,
            children: [
              field('Platforms', planning.distribution.platforms.join(', ')),
              field('Frequency', planning.distribution.frequency),
              field(
                'Launch date',
                planning.distribution.launchDate == null
                    ? ''
                    : dateFormat.format(planning.distribution.launchDate!),
              ),
              field('Editorial calendar entries',
                  '${planning.distribution.editorialCalendar.length} entries'),
            ],
          ),
          section(
            title: '7. Budget',
            stepIndex: 6,
            isFilled: !planning.budget.isEmpty,
            children: [
              if (planning.budget.items.isEmpty)
                field('Items', '')
              else
                ...planning.budget.items.map(
                  (i) => field(i.label.isEmpty ? 'Item' : i.label, currencyFormat.format(i.amount)),
                ),
              const Divider(height: 20),
              field('Total', currencyFormat.format(planning.budget.total)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: ${dateFormat.format(DateTime.now())}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.pink),
            onPressed: onContinue,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue to Approvals'),
          ),
        ],
      ),
    );
  }
}
