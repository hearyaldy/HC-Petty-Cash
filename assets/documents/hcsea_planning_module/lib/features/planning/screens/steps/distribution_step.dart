import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/distribution_plan.dart';
import '../../state/planning_project_provider.dart';
import '../../widgets/ai_draft_button.dart';

/// Step 6 — Distribution, including the Editorial Calendar Drafter
/// AI assistant.
class DistributionStep extends StatefulWidget {
  const DistributionStep({super.key});

  @override
  State<DistributionStep> createState() => _DistributionStepState();
}

class _DistributionStepState extends State<DistributionStep> {
  final _platformsController = TextEditingController();
  final _frequencyController = TextEditingController();
  DateTime _launchDate = DateTime.now();
  List<EditorialCalendarEntry> _calendar = const [];

  @override
  void initState() {
    super.initState();
    final dist = context.read<PlanningProjectProvider>().project?.distribution;
    _frequencyController.text = dist?.frequency ?? '';
    _calendar = List.of(dist?.editorialCalendar ?? const []);
  }

  @override
  void dispose() {
    _platformsController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanningProjectProvider>();
    final dateFormat = DateFormat.yMMMd();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('6. Distribution', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Frequency, format per platform, boosting strategy (pre/during/post), '
            'organic vs. paid traffic, and the editorial calendar.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _platformsController,
            decoration: const InputDecoration(
              labelText: 'Platforms (comma-separated)',
              hintText: 'YouTube, Facebook, TikTok',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _frequencyController,
            decoration: const InputDecoration(
              labelText: 'Frequency of publication',
              hintText: 'Weekly, every Tuesday',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Launch date: ${dateFormat.format(_launchDate)}'),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _launchDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _launchDate = picked);
              },
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 8),
          AiDraftButton(
            label: 'Draft editorial calendar with AI',
            isBusy: provider.isDrafting,
            onPressed: () {
              final platforms = _platformsController.text
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .toList();
              if (platforms.isEmpty || _frequencyController.text.trim().isEmpty) return;
              provider
                  .draftEditorialCalendarWithAi(
                platforms: platforms,
                frequency: _frequencyController.text,
                launchDate: _launchDate,
              )
                  .then((_) {
                setState(() {
                  _calendar = List.of(provider.project?.distribution.editorialCalendar ?? const []);
                });
              });
            },
          ),
          const Divider(height: 40),
          Text('Editorial calendar', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_calendar.isEmpty)
            const Text('No entries yet — draft with AI above, or add manually.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Theme')),
                  DataColumn(label: Text('Format')),
                  DataColumn(label: Text('Channel')),
                  DataColumn(label: Text('Status')),
                ],
                rows: _calendar
                    .map(
                      (e) => DataRow(cells: [
                        DataCell(Text(dateFormat.format(e.date))),
                        DataCell(Text(e.theme)),
                        DataCell(Text(e.format)),
                        DataCell(Text(e.channel)),
                        DataCell(Text(e.status)),
                      ]),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
