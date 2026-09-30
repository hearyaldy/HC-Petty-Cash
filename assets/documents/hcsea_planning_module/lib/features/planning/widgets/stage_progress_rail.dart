import 'package:flutter/material.dart';

/// The 8-step Planning stage rail — mirrors the stage-rail navigation
/// from the original Planning Intelligence Hub proposal, so the same
/// visual language carries from the pitch document into the actual
/// screen. Also usable later for the Pre-production/Production/etc.
/// checklists since Workflow HC numbers those the same way.
class StageProgressRail extends StatelessWidget {
  const StageProgressRail({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.completed,
    required this.onStepSelected,
  });

  final List<String> steps;
  final int currentIndex;

  /// Same length as [steps]; true where that step already has content.
  final List<bool> completed;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      shrinkWrap: true,
      itemCount: steps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final isActive = index == currentIndex;
        final isDone = completed[index];
        return Material(
          color: isActive
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onStepSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: isDone
                        ? Icon(Icons.check_circle,
                            size: 16, color: theme.colorScheme.primary)
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.labelSmall,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
