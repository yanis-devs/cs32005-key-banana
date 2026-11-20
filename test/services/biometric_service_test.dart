import 'package:flutter_test/flutter_test.dart';
import 'package:key_banana/services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';

/// A stand-in for the `local_auth` plugin.
///
/// `authenticate` is handled through [noSuchMethod] so this fake keeps
/// compiling if the plugin adds or renames optional parameters. It records
/// the arguments it receives.
class _FakeAuth implements LocalAuthentication {
  _FakeAuth({
    this.supported = true,
    this.authenticates = true,
    this.supportCheckThrows = false,
    this.authenticateThrows = false,
  });

  final bool supported;
  final bool authenticates;
  final bool supportCheckThrows;
  final bool authenticateThrows;

  int supportChecks = 0;
  int authenticateCalls = 0;
  Map<Symbol, dynamic>? lastArguments;

  @override
  Future<bool> isDeviceSupported() async {
    supportChecks++;
    if (supportCheckThrows) throw Exception('support check failed');
    return supported;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      authenticateCalls++;
      lastArguments = invocation.namedArguments;
      if (authenticateThrows) {
        return Future<bool>.error(Exception('authentication failed'));
      }
      return Future<bool>.value(authenticates);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  // ==========================================
  // 1. isAvailable
  // ==========================================
  group('isAvailable', () {
    test('is true when the device supports authentication', () async {
      final service = BiometricService(auth: _FakeAuth(supported: true));

      expect(await service.isAvailable(), isTrue);
    });

    test('is false when the device has no screen lock', () async {
      final service = BiometricService(auth: _FakeAuth(supported: false));

      expect(await service.isAvailable(), isFalse);
    });

    test('is false, not thrown, when the support check fails', () async {
      final service = BiometricService(
        auth: _FakeAuth(supportCheckThrows: true),
      );

      expect(await service.isAvailable(), isFalse);
    });
  });

  // ==========================================
  // 2. unlock
  // ==========================================
  group('unlock', () {
    test('is unlocked when authentication succeeds', () async {
      final service = BiometricService(auth: _FakeAuth());

      expect(await service.unlock(), LockResult.unlocked);
    });

    test('is failed when the user does not authenticate', () async {
      final service = BiometricService(auth: _FakeAuth(authenticates: false));

      expect(await service.unlock(), LockResult.failed);
    });

    test('is failed, not thrown, when authentication throws', () async {
      final service = BiometricService(
        auth: _FakeAuth(authenticateThrows: true),
      );

      expect(await service.unlock(), LockResult.failed);
    });

    test('is notAvailable when the device has no screen lock', () async {
      final service = BiometricService(auth: _FakeAuth(supported: false));

      expect(await service.unlock(), LockResult.notAvailable);
    });

    test('is notAvailable, not thrown, when the support check fails', () async {
      final service = BiometricService(
        auth: _FakeAuth(supportCheckThrows: true),
      );

      expect(await service.unlock(), LockResult.notAvailable);
    });

    test('never asks the user to authenticate when there is no lock', () async {
      final auth = _FakeAuth(supported: false);

      await BiometricService(auth: auth).unlock();

      expect(auth.authenticateCalls, 0);
    });

    test('checks support once, then authenticates once', () async {
      final auth = _FakeAuth();

      await BiometricService(auth: auth).unlock();

      expect(auth.supportChecks, 1);
      expect(auth.authenticateCalls, 1);
    });

    test('shows the K-Banana reason in the system prompt', () async {
      final auth = _FakeAuth();

      await BiometricService(auth: auth).unlock();

      expect(auth.lastArguments?[#localizedReason], 'Unlock K-Banana to play');
    });

    test('waits for the app to return if the prompt is interrupted', () async {
      final auth = _FakeAuth();

      await BiometricService(auth: auth).unlock();

      expect(auth.lastArguments?[#persistAcrossBackgrounding], isTrue);
    });

    test('allows the device PIN, pattern or password as a fallback', () async {
      final auth = _FakeAuth();

      await BiometricService(auth: auth).unlock();

      // biometricOnly would lock out someone whose fingerprint fails, so it
      // must be left unset (the plugin default is false) or false.
      expect(auth.lastArguments?[#biometricOnly], isNot(isTrue));
    });

    test('can be tried again after a failure', () async {
      final auth = _FakeAuth(authenticates: false);
      final service = BiometricService(auth: auth);

      expect(await service.unlock(), LockResult.failed);
      expect(await service.unlock(), LockResult.failed);
      expect(auth.authenticateCalls, 2);
    });
  });

  // ==========================================
  // 3. CONSTRUCTION AND RESULTS
  // ==========================================
  group('construction and results', () {
    test('can be created without a plugin, as the app does', () {
      // The plugin is only created when first used, so this must not throw.
      expect(BiometricService.new, returnsNormally);
    });

    test('LockResult has exactly the three outcomes the app handles', () {
      expect(LockResult.values, [
        LockResult.unlocked,
        LockResult.notAvailable,
        LockResult.failed,
      ]);
    });
  });
}
