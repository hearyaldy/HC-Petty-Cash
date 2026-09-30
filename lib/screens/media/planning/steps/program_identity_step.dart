import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../../../../models/media_production_planning.dart';
import '../../../../providers/media_planning_provider.dart';

final _hexTokenPattern = RegExp(r'#?[0-9A-Fa-f]{6}\b');

String? _normalizeHexToken(String token) {
  final match = _hexTokenPattern.firstMatch(token.trim());
  if (match == null) return null;
  return '#${match.group(0)!.replaceFirst('#', '').toUpperCase()}';
}

Color _hexToColor(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

/// Step 5 — Program Identity (Visual Identity).
///
/// No AI assistant here — naming, moodboards, and key visuals are
/// creative decisions Workflow HC treats as a design task, not a
/// research task, so they stay manual.
class ProgramIdentityStep extends StatefulWidget {
  const ProgramIdentityStep({super.key, this.onSaved});

  final VoidCallback? onSaved;

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
    final identity = context.read<MediaPlanningProvider>().planning?.identity;
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

  List<String> get _paletteHexColors {
    final seen = <String>{};
    for (final raw in _paletteController.text.split(',')) {
      final hex = _normalizeHexToken(raw);
      if (hex != null) seen.add(hex);
    }
    return seen.toList();
  }

  void _removeColor(String hexToRemove) {
    setState(() {
      final kept = _paletteController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty && _normalizeHexToken(t) != hexToRemove);
      _paletteController.text = kept.join(', ');
    });
  }

  Future<void> _openColorPicker() async {
    Color picked = Colors.pink;
    final result = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: picked,
              onColorChanged: (c) => picked = c,
              enableAlpha: false,
              labelTypes: const [],
              hexInputBar: true,
              pickerAreaHeightPercent: 0.7,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, picked),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    final hex = '#${result.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    setState(() {
      final current = _paletteController.text.trim();
      _paletteController.text = current.isEmpty ? hex : '$current, $hex';
    });
  }

  Future<void> _save() async {
    final current = context.read<MediaPlanningProvider>().planning?.identity;
    final ok = await context.read<MediaPlanningProvider>().saveProgramIdentity(
          PlanningProgramIdentity(
            briefing: _briefingController.text,
            programName: _nameController.text,
            moodboardRefs: current?.moodboardRefs ?? const [],
            fontChoice: _fontController.text,
            colorPalette: _paletteController.text,
            keyVisualDescription: _keyVisualController.text,
            derivationsNeeded: current?.derivationsNeeded ??
                const ['Thumbnail (YouTube)', 'Reel', 'Square Post', 'Carousel', 'Story'],
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
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Color palette (hex list or description)',
                helperText: 'Type hex codes separated by commas, e.g. #FF5733, #1E90FF',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final hex in _paletteHexColors)
                Chip(
                  avatar: CircleAvatar(backgroundColor: _hexToColor(hex), radius: 9),
                  label: Text(hex, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  onDeleted: () => _removeColor(hex),
                ),
              ActionChip(
                avatar: const Icon(Icons.colorize, size: 16),
                label: const Text('Pick color'),
                onPressed: _openColorPicker,
              ),
            ],
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
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            Text(provider.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
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
