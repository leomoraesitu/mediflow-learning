import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/connectivity/connectivity_sync_triggers.dart';

void main() {
  late StreamController<List<ConnectivityResult>> source;
  late int triggers;
  late StreamSubscription<void> subscription;

  setUp(() {
    triggers = 0;
    source = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(source.close);
    subscription = ConnectivitySyncTriggers.triggersFrom(source.stream).listen((_) => triggers++);
    addTearDown(subscription.cancel);
  });

  Future<void> emit(List<ConnectivityResult> results) async {
    source.add(results);
    await pumpEventQueue();
  }

  test('emits when the network becomes available', () async {
    await emit([ConnectivityResult.none]);
    await emit([ConnectivityResult.wifi]);

    expect(triggers, 1);
  });

  test('emits when the network interface changes', () async {
    await emit([ConnectivityResult.wifi]);
    await emit([ConnectivityResult.mobile]);

    // Duas rotas diferentes, duas chances. É o usuário que abandona um wi-fi
    // quebrado pelo 4G — o gatilho que mais importa nesta aula.
    expect(triggers, 2);
  });

  test('ignores losing the network', () async {
    await emit([ConnectivityResult.wifi]);
    await emit([ConnectivityResult.none]);

    expect(triggers, 1);
  });

  test('collapses repeated emissions of the same state', () async {
    await emit([ConnectivityResult.wifi]);
    await emit([ConnectivityResult.wifi]);

    // Sem o comparador do `distinct`, este é o caso que falha: listas em Dart
    // comparam por identidade, e duas listas iguais são objetos distintos.
    expect(triggers, 1);
  });
}
