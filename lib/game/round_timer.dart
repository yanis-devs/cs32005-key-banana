import 'dart:async';

class RoundTimer {
  final void Function() onRoundEnded;

  RoundTimer(this.onRoundEnded);

  DateTime? currentTime;
  DateTime? deadline;
  Timer? _timer;

  void startTimer() {
    _timer?.cancel();

    currentTime = DateTime.now();
    deadline = currentTime!.add(
      const Duration(seconds: 10),
    );

    _timer = Timer(const Duration(seconds: 10), () {
      onRoundEnded();
    });
  }

  double? whatTimeRemains() {
    if (deadline == null) {
      return null;
    }

    final remaining = deadline!.difference(DateTime.now());

    return remaining.inMicroseconds /
        Duration.microsecondsPerSecond;
  }

  void cancelTimer() {
    _timer?.cancel();
  }
}