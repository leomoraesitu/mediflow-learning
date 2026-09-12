import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/pending_sync_indicator.dart';

void main() {
  late StreamController<bool> pendingSyncController;

  Widget buildIndicator() {
    return MaterialApp(
      home: Scaffold(body: PendingSyncIndicator(hasPendingSync: pendingSyncController.stream)),
    );
  }

  setUp(() {
    pendingSyncController = StreamController<bool>.broadcast();
  });

  tearDown(() async {
    await pendingSyncController.close();
  });

  // Sem emitir nada: o que está sob teste é o `initialData`. Emitir `false`
  // aqui tornaria o caso incapaz de falhar, porque o estado esperado é o mesmo
  // de antes da emissão — não haveria como distinguir "reagiu" de "ignorou o
  // stream".
  testWidgets('starts hidden before the stream emits', (tester) async {
    await tester.pumpWidget(buildIndicator());

    expect(find.text(PendingSyncIndicator.message), findsNothing);
  });

  testWidgets('shows the indicator when a checkout is pending', (tester) async {
    await tester.pumpWidget(buildIndicator());

    pendingSyncController.add(true);
    await tester.pumpAndSettle();

    expect(find.text(PendingSyncIndicator.message), findsOneWidget);
  });

  testWidgets('hides the indicator after the pending checkout syncs', (tester) async {
    await tester.pumpWidget(buildIndicator());

    pendingSyncController.add(true);
    await tester.pumpAndSettle();

    expect(find.text(PendingSyncIndicator.message), findsOneWidget);

    pendingSyncController.add(false);
    await tester.pumpAndSettle();

    expect(find.text(PendingSyncIndicator.message), findsNothing);
  });
}
