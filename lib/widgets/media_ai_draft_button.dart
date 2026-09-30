import 'package:flutter/material.dart';

/// The "Draft with AI" button used on every research-heavy Media
/// Production Planning step — one shared widget so every AI entry
/// point looks and behaves identically.
class MediaAiDraftButton extends StatelessWidget {
  const MediaAiDraftButton({
    super.key,
    required this.label,
    required this.isBusy,
    required this.onPressed,
    this.enabled = true,
  });

  /// e.g. "Draft objective with AI", "Scout references with AI".
  final String label;
  final bool isBusy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: (enabled && !isBusy) ? onPressed : null,
      style: OutlinedButton.styleFrom(foregroundColor: Colors.pink.shade700),
      icon: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome, size: 18),
      label: Text(isBusy ? 'Drafting…' : label),
    );
  }
}
