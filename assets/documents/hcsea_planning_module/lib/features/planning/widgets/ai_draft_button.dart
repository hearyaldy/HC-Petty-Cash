import 'package:flutter/material.dart';

/// The "Draft with AI" button used on every research-heavy Planning
/// step. Kept as one shared widget so every AI entry point in the
/// module looks and behaves identically — same icon, same label
/// pattern, same busy state — rather than each screen inventing its
/// own button.
class AiDraftButton extends StatelessWidget {
  const AiDraftButton({
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
