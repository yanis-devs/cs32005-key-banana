import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/theme/motion.dart';

const _normal = Duration(milliseconds: 250);

/// Builds a tree with the given setting and returns what motionDuration gives.
Future<Duration> durationWith(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  late Duration result;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          result = motionDuration(context, _normal);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  testWidgets('keeps the normal duration by default', (tester) async {
    expect(await durationWith(tester, disableAnimations: false), _normal);
  });

  testWidgets('is zero when the player reduces motion', (tester) async {
    expect(await durationWith(tester, disableAnimations: true), Duration.zero);
  });
}
