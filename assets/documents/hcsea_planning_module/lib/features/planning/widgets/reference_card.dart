import 'package:flutter/material.dart';

import '../models/market_research.dart';

/// One row of the "3 references from similar or related programs"
/// requirement in Workflow HC's Format/market-research step. Used
/// both for AI-drafted references and manually-entered ones, so a
/// producer can freely mix the two.
class ReferenceCard extends StatelessWidget {
  const ReferenceCard({
    super.key,
    required this.reference,
    required this.onChanged,
    required this.onRemove,
  });

  final ProgramReference reference;
  final ValueChanged<ProgramReference> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: reference.title,
                    decoration: const InputDecoration(labelText: 'Program title'),
                    onChanged: (v) => onChanged(
                      ProgramReference(title: v, url: reference.url, whatWorks: reference.whatWorks),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove reference',
                  onPressed: onRemove,
                ),
              ],
            ),
            TextFormField(
              initialValue: reference.url,
              decoration: const InputDecoration(labelText: 'Link (optional)'),
              onChanged: (v) => onChanged(
                ProgramReference(title: reference.title, url: v, whatWorks: reference.whatWorks),
              ),
            ),
            TextFormField(
              initialValue: reference.whatWorks,
              decoration: const InputDecoration(labelText: 'What works about it'),
              maxLines: 2,
              onChanged: (v) => onChanged(
                ProgramReference(title: reference.title, url: reference.url, whatWorks: v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
