import 'dart:async';

final class OutboxSyncScheduler {
  final Stream<void> _triggers;
  final Future<void> Function() _drain;
  StreamSubscription<void>? _subscription;
  var _started = false;

  OutboxSyncScheduler(this._triggers, {required this._drain});

  void start() {
    if (_started) return;
    _started = true;
    _subscription = _triggers.listen((_) async {
      await _drain();
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
