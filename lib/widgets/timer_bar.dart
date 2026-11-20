import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The countdown bar: banana yellow on a pale track, with a golden outline so
/// the full length of the bar is always visible. The number above it is the
/// precise cue; the bar is a quick visual one.
class TimerBar extends StatelessWidget {
  const TimerBar({super.key, required this.fraction});

  /// How full the bar is: 1.0 = full, 0.0 = time up. Values outside that
  /// range are clamped.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    // The outlined pale track.
    return Container(
      height: 16,

      decoration: BoxDecoration(
        color: AppColors.yellowSoft,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: AppColors.gold, width: 2),
      ),

      // Clip the yellow fill to the track's rounded corners (the radius is
      // 2 smaller to sit inside the 2-wide border).
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),

        child: Align(
          alignment: Alignment.centerLeft,

          // The fill shrinks towards the left as time runs out.
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),

            heightFactor: 1,

            child: const ColoredBox(color: AppColors.yellow),
          ),
        ),
      ),
    );
  }
}
