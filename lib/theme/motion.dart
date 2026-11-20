import 'package:flutter/widgets.dart';

/// True when the player has asked the system to reduce animation.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// [normal], or no time at all when the player has asked for reduced motion.
/// Instant changes still show the new state; they just don't animate to it.
Duration motionDuration(BuildContext context, Duration normal) =>
    reduceMotion(context) ? Duration.zero : normal;
