import 'package:flutter/material.dart';

import '../models/media_production_planning.dart';

/// One row of the "3 references from similar or related programs"
/// requirement in Workflow HC's Format/Market Research step. Used for
/// both AI-drafted and manually-entered references, so a producer can
/// freely mix the two.
class MediaReferenceCard extends StatelessWidget {
  const MediaReferenceCard({
    super.key,
    required this.reference,
    required this.onChanged,
    required this.onRemove,
  });

  final PlanningReference reference;
  final ValueChanged<PlanningReference> onChanged;
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
                      PlanningReference(title: v, url: reference.url, whatWorks: reference.whatWorks),
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
                PlanningReference(title: reference.title, url: v, whatWorks: reference.whatWorks),
              ),
            ),
            TextFormField(
              initialValue: reference.whatWorks,
              decoration: const InputDecoration(labelText: 'What works about it'),
              maxLines: 2,
              onChanged: (v) => onChanged(
                PlanningReference(title: reference.title, url: reference.url, whatWorks: v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
