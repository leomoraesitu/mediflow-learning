import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/lifecycle/lifecycle_sync_triggers.dart';

void main() {
  late LifecycleSyncTriggers triggers;
  late StreamSubscription<void> subscription;
  var emissions = 0;

  setUp(() {
    emissions = 0;
    triggers = LifecycleSyncTriggers();
    addTearDown(triggers.dispose);
    subscription = triggers.stream.listen((_) {
      emissions++;
    });
    addTearDown(subscription.cancel);
  });

  // O Flutter valida as transições de ciclo de vida: `resumed` só pode vir de
  // `inactive` ou `detached`. Pular estados dispara asserção — e a falha
  // aparece como "não emitiu", que é o sintoma, não a causa.
  void irParaSegundoPlano(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void voltarAoPrimeiroPlano(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('emits when the app resumes', (tester) async {
    irParaSegundoPlano(tester);
    voltarAoPrimeiroPlano(tester);
    await tester.pump();

    expect(emissions, 1);
  });

  // Percorre `inactive`, `hidden` e `paused` sem emitir: guarda contra
  // `onStateChange`, `onHide` e `onInactive` usados no lugar de `onResume`.
  testWidgets('does not emit while the app is going to the background', (tester) async {
    irParaSegundoPlano(tester);
    await tester.pump();

    expect(emissions, 0);
  });

  testWidgets('stops emitting after dispose', (tester) async {
    irParaSegundoPlano(tester);
    voltarAoPrimeiroPlano(tester);
    await tester.pump();

    expect(emissions, 1);

    await triggers.dispose();

    irParaSegundoPlano(tester);
    voltarAoPrimeiroPlano(tester);
    await tester.pump();

    expect(emissions, 1);
  });
}
