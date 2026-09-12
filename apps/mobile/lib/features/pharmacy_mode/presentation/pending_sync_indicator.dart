import 'package:flutter/material.dart';

/// Avisa que existe uma compra registrada no outbox e ainda não confirmada
/// pelo servidor.
///
/// Recebe `Stream<bool>`, e não o stream do Drift: o widget só precisa saber
/// se há algo pendente, e `OutboxEvent` é uma classe gerada pela camada de
/// persistência que não deve atravessar até a interface. A conversão acontece
/// na composição, em `main.dart`.
final class PendingSyncIndicator extends StatelessWidget {
  static const String message = 'Há uma compra aguardando sincronização.';

  final Stream<bool> hasPendingSync;

  const PendingSyncIndicator({super.key, required this.hasPendingSync});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: hasPendingSync,
      // Começar escondido é decisão, não detalhe: sem isto, a tela exibiria o
      // aviso — ou um espaço vazio instável — no intervalo entre a montagem e
      // a primeira emissão do stream.
      initialData: false,
      builder: (context, snapshot) {
        final hasPending = snapshot.data ?? false;

        if (!hasPending) {
          return const SizedBox.shrink();
        }

        return Semantics(liveRegion: true, child: Text(message, textAlign: TextAlign.center));
      },
    );
  }
}
