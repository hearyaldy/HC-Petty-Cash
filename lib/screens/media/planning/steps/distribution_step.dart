import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';
import '../../../../widgets/media_ai_draft_button.dart';

/// Step 6 — Distribution, including the Editorial Calendar Drafter AI
/// assistant.
class DistributionStep extends StatefulWidget {
  const DistributionStep({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<DistributionStep> createState() => _DistributionStepState();
}

class _DistributionStepState extends State<DistributionStep> {
  static const _platformOptions = [
    'YouTube',
    'Facebook',
    'Instagram',
    'TikTok',
    'X (Twitter)',
    'WhatsApp',
    'Telegram',
    'Website',
  ];

  final _frequencyController = TextEditingController();
  Set<String> _selectedPlatforms = {};
  DateTime _launchDate = DateTime.now();
  List<PlanningCalendarEntry> _calendar = const [];

  @override
  void initState() {
    super.initState();
    final dist = context.read<MediaPlanningProvider>().planning?.distribution;
    _frequencyController.text = dist?.frequency ?? '';
    _selectedPlatforms = Set.of(dist?.platforms ?? const []);
    _launchDate = dist?.launchDate ?? DateTime.now();
    _calendar = List.of(dist?.editorialCalendar ?? const []);
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    super.dispose();
  }

  Future<void> _addCustomPlatform() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add platform'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Platform name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _selectedPlatforms.add(name));
  }

  Future<void> _addManualEntry() async {
    final themeController = TextEditingController();
    final formatController = TextEditingController();
    final channelController = TextEditingController();
    final statusController = TextEditingController(text: 'Planned');
    var entryDate = DateTime.now();

    final entry = await showDialog<PlanningCalendarEntry>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add calendar entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Date: ${DateFormat.yMMMd().format(entryDate)}'),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: entryDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (picked != null) setDialogState(() => entryDate = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    TextField(
                      controller: themeController,
                      decoration: const InputDecoration(labelText: 'Theme'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: formatController,
                      decoration: const InputDecoration(labelText: 'Format'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: channelController,
                      decoration: const InputDecoration(labelText: 'Channel'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: statusController,
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    PlanningCalendarEntry(
                      date: entryDate,
                      theme: themeController.text.trim(),
                      format: formatController.text.trim(),
                      channel: channelController.text.trim(),
                      status: statusController.text.trim().isEmpty
                          ? 'Planned'
                          : statusController.text.trim(),
                      source: 'manual',
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    if (entry == null) return;
    setState(() => _calendar = [..._calendar, entry]);
  }

  void _removeCalendarEntryAt(int index) {
    setState(() {
      final updated = List.of(_calendar);
      updated.removeAt(index);
      _calendar = updated;
    });
  }

  void _clearAiEntries() {
    setState(() => _calendar = _calendar.where((e) => e.source != 'ai').toList());
  }

  Future<void> _save() async {
    final current =
        context.read<MediaPlanningProvider>().planning?.distribution ?? const PlanningDistribution();
    final ok = await context.read<MediaPlanningProvider>().saveDistribution(
          current.copyWith(
            platforms: _selectedPlatforms.toList(),
            frequency: _frequencyController.text,
            launchDate: _launchDate,
            editorialCalendar: _calendar,
          ),
        );
    if (ok) widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MediaPlanningProvider>();
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
          Text('Platforms', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final platform in {..._platformOptions, ..._selectedPlatforms})
                FilterChip(
                  label: Text(platform),
                  selected: _selectedPlatforms.contains(platform),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPlatforms.add(platform);
                      } else {
                        _selectedPlatforms.remove(platform);
                      }
                    });
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Other'),
                onPressed: _addCustomPlatform,
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          MediaAiDraftButton(
            label: 'Draft editorial calendar with AI',
            isBusy: provider.isDrafting,
            onPressed: () {
              final platforms = _selectedPlatforms.toList();
              if (platforms.isEmpty || _frequencyController.text.trim().isEmpty) return;
              provider
                  .draftEditorialCalendarWithAi(
                platforms: platforms,
                frequency: _frequencyController.text,
                launchDate: _launchDate,
              )
                  .then((_) {
                setState(() {
                  _calendar = List.of(provider.planning?.distribution.editorialCalendar ?? const []);
                });
              });
            },
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 8),
            Text(provider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const Divider(height: 40),
          Row(
            children: [
              Expanded(
                child: Text('Editorial calendar', style: Theme.of(context).textTheme.titleSmall),
              ),
              if (_calendar.any((e) => e.source == 'ai'))
                TextButton.icon(
                  onPressed: _clearAiEntries,
                  icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                  label: const Text('Clear AI-drafted'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                ),
              TextButton.icon(
                onPressed: _addManualEntry,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add entry'),
                style: TextButton.styleFrom(foregroundColor: Colors.pink.shade700),
              ),
            ],
          ),
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
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (var i = 0; i < _calendar.length; i++)
                    DataRow(cells: [
                      DataCell(Text(dateFormat.format(_calendar[i].date))),
                      DataCell(Text(_calendar[i].theme)),
                      DataCell(Text(_calendar[i].format)),
                      DataCell(Text(_calendar[i].channel)),
                      DataCell(Text(_calendar[i].status)),
                      DataCell(
                        Chip(
                          label: Text(
                            _calendar[i].source == 'ai' ? 'AI' : 'Manual',
                            style: const TextStyle(fontSize: 11),
                          ),
                          avatar: Icon(
                            _calendar[i].source == 'ai' ? Icons.auto_awesome : Icons.edit_note,
                            size: 14,
                          ),
                          backgroundColor: _calendar[i].source == 'ai'
                              ? Colors.blue.shade50
                              : Colors.grey.shade200,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Remove entry',
                          onPressed: () => _removeCalendarEntryAt(i),
                        ),
                      ),
                    ]),
                ],
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
