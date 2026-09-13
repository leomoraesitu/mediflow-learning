import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comparador de goldens que tolera pequenas diferenças de renderização.
///
/// Goldens gerados no macOS não batem exatamente com o Linux da CI, mesmo sem
/// fontes reais carregadas — a divergência vem de antialiasing em bordas
/// arredondadas e sombras. Medido neste projeto: 1,25% e 1,72%.
///
/// A tolerância só é defensável porque as duas populações estão separadas por
/// uma ordem de grandeza. A regressão que motivou estes goldens — o cartão da
/// tela inicial subindo 82 px na Aula 43 — produz 46,34% e 43,43%. Três por
/// cento fica bem acima do ruído e muito abaixo do sinal.
///
/// O preço, aceito conscientemente: uma mudança visual que altere menos de 3%
/// dos pixels passa despercebida — uma cor levemente diferente num elemento
/// pequeno, por exemplo. A tolerância compra portabilidade em troca de
/// sensibilidade, e este número é a medida exata dessa troca.
///
/// As alternativas foram descartadas por quebrarem o ciclo local: gerar os
/// goldens na CI deixaria dois vermelhos permanentes no Mac, e rodá-los só lá
/// tiraria a possibilidade de gerar e inspecionar a imagem antes de versionar.
class _ToleranteGoldenComparator extends LocalFileComparator {
  static const double _toleranciaMaxima = 0.03;

  _ToleranteGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final resultado = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (resultado.passed || resultado.diffPercent <= _toleranciaMaxima) {
      return true;
    }

    final erro = await generateFailureOutput(resultado, golden, basedir);
    throw FlutterError(erro);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // O comparador precisa de um arquivo de referência para resolver caminhos
  // relativos; qualquer um dentro de `test/` serve.
  goldenFileComparator = _ToleranteGoldenComparator(
    Uri.parse('${Directory.current.path}/test/flutter_test_config.dart'),
  );

  await testMain();
}
