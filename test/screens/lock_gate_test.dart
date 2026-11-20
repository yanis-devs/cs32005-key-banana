import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/screens/lock_gate.dart';
import 'package:key_banana/services/biometric_service.dart';

/// Returns the given results in order (repeating the last) and counts calls.
///
/// If a [gate] is given, every unlock waits until it is completed, so a test
/// can look at the screen while the system prompt is still open.
class _FakeBiometrics extends BiometricService {
  _FakeBiometrics(this.results, {this.gate});

  final List<LockResult> results;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<LockResult> unlock() async {
    final result = results[min(calls, results.length - 1)];
    calls++;
    await gate?.future;
    return result;
  }
}

Widget _app(BiometricService service) {
  return MaterialApp(
    home: LockGate(
      service: service,
      builder: (context, lockEnabled) => Text('app open, lock=$lockEnabled'),
    ),
  );
}

void main() {
  // ==========================================
  // 1. SUCCESSFUL UNLOCK
  // ==========================================
  group('when unlock succeeds', () {
    testWidgets('opens the app with the lock enabled', (tester) async {
      final service = _FakeBiometrics([LockResult.unlocked]);

      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      expect(find.text('app open, lock=true'), findsOneWidget);
    });

    testWidgets('asks to unlock exactly once per launch', (tester) async {
      final service = _FakeBiometrics([LockResult.unlocked]);

      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      // Rebuild the tree: an open gate must not prompt again.
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      expect(service.calls, 1);
    });

    testWidgets('does not show the locked screen', (tester) async {
      await tester.pumpWidget(_app(_FakeBiometrics([LockResult.unlocked])));
      await tester.pumpAndSettle();

      expect(find.text('K-Banana is locked'), findsNothing);
      expect(find.text('Unlock'), findsNothing);
    });
  });

  // ==========================================
  // 2. WHILE CHECKING
  // ==========================================
  group('while the system prompt is open', () {
    testWidgets('shows a spinner and keeps the app hidden', (tester) async {
      final gate = Completer<void>();
      final service = _FakeBiometrics([LockResult.unlocked], gate: gate);

      await tester.pumpWidget(_app(service));
      await tester.pump(); // runs the first-frame callback that starts unlock

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('app open'), findsNothing);
      expect(find.text('K-Banana is locked'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('app open, lock=true'), findsOneWidget);
    });

    testWidgets('the spinner is announced as "Unlocking"', (tester) async {
      final handle = tester.ensureSemantics();
      final gate = Completer<void>();

      await tester.pumpWidget(
        _app(_FakeBiometrics([LockResult.unlocked], gate: gate)),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Unlocking'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('asks the service only once while the prompt is open', (
      tester,
    ) async {
      final gate = Completer<void>();
      final service = _FakeBiometrics([LockResult.unlocked], gate: gate);

      await tester.pumpWidget(_app(service));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(service.calls, 1);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('closing the screen before the answer arrives is safe', (
      tester,
    ) async {
      final gate = Completer<void>();
      final service = _FakeBiometrics([LockResult.unlocked], gate: gate);

      await tester.pumpWidget(_app(service));
      await tester.pump();

      // Remove the gate from the tree, then let the answer arrive.
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // ==========================================
  // 3. FAILED UNLOCK
  // ==========================================
  group('when unlock fails', () {
    testWidgets('shows the locked screen', (tester) async {
      await tester.pumpWidget(_app(_FakeBiometrics([LockResult.failed])));
      await tester.pumpAndSettle();

      expect(find.text('K-Banana is locked'), findsOneWidget);
      expect(
        find.text('Use your fingerprint, face or screen lock to play.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('keeps the app hidden', (tester) async {
      await tester.pumpWidget(_app(_FakeBiometrics([LockResult.failed])));
      await tester.pumpAndSettle();

      expect(find.textContaining('app open'), findsNothing);
    });

    testWidgets('the Unlock button retries and opens the app on success', (
      tester,
    ) async {
      final service = _FakeBiometrics([LockResult.failed, LockResult.unlocked]);
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      expect(find.text('K-Banana is locked'), findsOneWidget);

      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('app open, lock=true'), findsOneWidget);
      expect(find.text('K-Banana is locked'), findsNothing);
      expect(service.calls, 2);
    });

    testWidgets('stays locked when the retry fails too', (tester) async {
      final service = _FakeBiometrics([LockResult.failed]);
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('K-Banana is locked'), findsOneWidget);
      expect(find.textContaining('app open'), findsNothing);
      expect(service.calls, 2);
    });

    testWidgets('can be retried several times', (tester) async {
      final service = _FakeBiometrics([
        LockResult.failed,
        LockResult.failed,
        LockResult.failed,
        LockResult.unlocked,
      ]);
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Unlock'));
        await tester.pumpAndSettle();
      }
      expect(find.text('K-Banana is locked'), findsOneWidget);

      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('app open, lock=true'), findsOneWidget);
      expect(service.calls, 4);
    });
  });

  // ==========================================
  // 4. NO LOCK ON THE DEVICE
  // ==========================================
  group('when the device has no screen lock', () {
    testWidgets('opens the app with lock=false', (tester) async {
      await tester.pumpWidget(_app(_FakeBiometrics([LockResult.notAvailable])));
      await tester.pumpAndSettle();

      expect(find.text('app open, lock=false'), findsOneWidget);
    });

    testWidgets('never shows the locked screen', (tester) async {
      await tester.pumpWidget(_app(_FakeBiometrics([LockResult.notAvailable])));
      await tester.pumpAndSettle();

      expect(find.text('K-Banana is locked'), findsNothing);
      expect(find.text('Unlock'), findsNothing);
    });

    testWidgets('only asks once', (tester) async {
      final service = _FakeBiometrics([LockResult.notAvailable]);

      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      expect(service.calls, 1);
    });
  });
}
