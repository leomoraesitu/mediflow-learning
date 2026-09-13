import 'dart:async';

import 'package:flutter/widgets.dart';

class LifecycleSyncTriggers {
  LifecycleSyncTriggers() {
    _listener = AppLifecycleListener(onResume: _onResume);
  }

  final StreamController<void> _controller = StreamController<void>.broadcast();

  late final AppLifecycleListener _listener;

  bool _disposed = false;

  Stream<void> get stream => _controller.stream;

  void _onResume() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  /// Em produção ninguém chama isto: o adaptador vive o processo inteiro,
  /// como o agendador que ele alimenta. Existe para os testes e para o dia em
  /// que alguém lhe der um dono.
  ///
  /// Idempotente de propósito. `StreamController.close` já é, mas
  /// `AppLifecycleListener.dispose` **não** — a segunda chamada lança
  /// "was used after being disposed". A assimetria não é óbvia para quem lê,
  /// e um `addTearDown` somado a um descarte explícito basta para encontrá-la.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    _listener.dispose();
    await _controller.close();
  }
}
