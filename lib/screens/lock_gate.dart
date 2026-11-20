import 'package:flutter/material.dart';

import '../services/biometric_service.dart';

/// Which screen [LockGate] is showing.
enum _GateState {
  /// Waiting for the unlock prompt to finish.
  checking,

  /// The prompt failed or was cancelled, so the lock screen is shown.
  locked,

  /// Unlocked (or no lock available): the real app is shown.
  open,
}

/// Keeps the app locked until the user authenticates, once per app launch.
///
/// [builder] builds the real app. Its `lockEnabled` flag is false when the
/// device has no screen lock, so the app can tell the user the lock is off.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.service, required this.builder});

  /// Runs the device authentication prompt.
  final BiometricService service;

  /// Builds the real app once unlocked. `lockEnabled` is false if the device
  /// has no screen lock.
  final Widget Function(BuildContext context, bool lockEnabled) builder;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  _GateState _state = _GateState.checking;

  /// False when the device has no screen lock and the app opened without one.
  bool _lockEnabled = true;
  bool _busy = false; // stops a second prompt opening on top of the first

  @override
  void initState() {
    super.initState();
    // Wait for the first frame so the Android activity is ready to show the
    // system prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  /// Shows the unlock prompt and updates [_state] from the result. Ignored if
  /// a prompt is already open.
  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    setState(() => _state = _GateState.checking);

    final result = await widget.service.unlock();
    _busy = false;
    if (!mounted) return;

    setState(() {
      if (result == LockResult.failed) {
        _state = _GateState.locked;
      } else {
        // Both "unlocked" and "no lock available" open the app; only the
        // first means the app is actually protected.
        _state = _GateState.open;
        _lockEnabled = result == LockResult.unlocked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.open:
        return widget.builder(context, _lockEnabled);

      case _GateState.checking:
        return Scaffold(
          body: Center(
            child: Semantics(
              label: 'Unlocking',
              child: CircularProgressIndicator(),
            ),
          ),
        );

      case _GateState.locked:
        final textTheme = Theme.of(context).textTheme;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(Icons.lock_outline, size: 64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'K-Banana is locked',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use your fingerprint, face or screen lock to play.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _unlock,
                      child: const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}
