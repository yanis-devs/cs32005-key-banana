import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of an unlock attempt.
enum LockResult {
  /// The user proved who they are (fingerprint, face, PIN, pattern or
  /// password).
  unlocked,

  /// The device has no screen lock or biometrics set up, so there is nothing
  /// to check. The app opens without a lock.
  notAvailable,

  /// The user cancelled, failed, or the device is temporarily locked out.
  failed,
}

/// Thin wrapper around `local_auth` (3.x API) so the rest of the app, and the
/// tests, never touch the plugin directly. Never throws.
class BiometricService {
  // ignore: prefer_initializing_formals
  BiometricService({LocalAuthentication? auth}) : _auth = auth;

  /// The plugin instance. Passed in by tests, otherwise created on first use.
  LocalAuthentication? _auth;

  /// The plugin instance, created lazily so tests can supply their own and
  /// the real plugin is only touched when needed.
  LocalAuthentication get _plugin => _auth ??= LocalAuthentication();

  /// True if the device can authenticate at all: biometrics, or a PIN /
  /// pattern / password. False when no screen lock is set up, or if the
  /// check itself fails.
  Future<bool> isAvailable() async {
    try {
      return await _plugin.isDeviceSupported();
    } catch (e) {
      debugPrint('Could not check device authentication support: $e');
      return false;
    }
  }

  /// Asks the user to authenticate. Biometrics are offered first, and the
  /// device PIN / pattern / password works as the fallback, so someone whose
  /// fingerprint fails is never locked out of their own app.
  ///
  /// Returns [LockResult.notAvailable] without showing a prompt if the device
  /// has no screen lock.
  Future<LockResult> unlock() async {
    if (!await isAvailable()) return LockResult.notAvailable;

    try {
      final success = await _plugin.authenticate(
        localizedReason: 'Unlock K-Banana to play',
        // If the prompt is interrupted (a call comes in, say), wait for the
        // app to return and ask again instead of failing.
        persistAcrossBackgrounding: true,
      );
      return success ? LockResult.unlocked : LockResult.failed;
    } catch (e) {
      // Cancelled, locked out, or a platform error. All mean "not unlocked".
      debugPrint('Authentication did not complete: $e');
      return LockResult.failed;
    }
  }
}
