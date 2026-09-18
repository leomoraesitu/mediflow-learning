import 'dart:async';

/// Liga os gatilhos de sincronização à drenagem do outbox.
///
/// Não conhece autenticação, e isso é decisão da Aula 56. Os três gatilhos
/// — inicialização, volta da conectividade e retomada do aplicativo —
/// disparam independentemente de haver sessão, e quem recusa é o
/// `OutboxSynchronizer`, que já precisa do `uid` para ler a fila certa.
///
/// Consultar a sessão aqui seria uma segunda decisão sobre a mesma coisa, no
/// lugar que menos sabe a respeito dela.
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
