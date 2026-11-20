import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small pale-yellow card with a big value and a label, e.g. "42.3 / Best".
/// Read by screen readers as one item: "Best: 42.3".
///
/// Sizes itself to its content inside a Wrap, or fills its column inside an
/// Expanded. The text scales down rather than overflowing in a narrow column.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  /// The small caption under the value, e.g. "Best".
  final String label;

  /// The large text, e.g. "42.3" or "3 days".
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // The visible texts are hidden from screen readers and replaced by one
    // combined label.
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.yellowSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FittedBox shrinks the text to fit instead of overflowing.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: textTheme.titleLarge?.copyWith(fontSize: 24),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
