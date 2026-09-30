import 'package:flutter/material.dart';

/// The 8-step Planning stage rail for a Media Production — a vertical
/// list on wide screens, collapsing to a horizontal strip on phone
/// width (see usage in `media_planning_tab.dart`).
class MediaPlanningStageRail extends StatelessWidget {
  const MediaPlanningStageRail({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.completed,
    required this.onStepSelected,
    this.horizontal = false,
  });

  final List<String> steps;
  final int currentIndex;

  /// Same length as [steps]; true where that step already has content.
  final List<bool> completed;
  final ValueChanged<int> onStepSelected;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget item(int index) {
      final isActive = index == currentIndex;
      final isDone = completed[index];
      return Material(
        color: isActive ? Colors.pink.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onStepSelected(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
              children: [
                SizedBox(
                  width: 22,
                  child: isDone
                      ? Icon(Icons.check_circle, size: 16, color: Colors.pink.shade400)
                      : Text('${index + 1}', style: theme.textTheme.labelSmall),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[index],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? Colors.pink.shade700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) => item(index),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: steps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) => item(index),
    );
  }
}
