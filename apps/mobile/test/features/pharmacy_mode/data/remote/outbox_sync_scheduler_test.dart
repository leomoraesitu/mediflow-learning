import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/remote/outbox_sync_scheduler.dart';

void main() {
  late StreamController<void> triggers;
  late OutboxSyncScheduler scheduler;
  var drains = 0;

  setUp(() {
    drains = 0;
    triggers = StreamController<void>.broadcast();
    addTearDown(triggers.close);
    scheduler = OutboxSyncScheduler(triggers.stream, drain: () async => drains++);
    addTearDown(scheduler.dispose);
  });

  test('does not drain before start', () async {
    triggers.add(null);
    await pumpEventQueue();

    expect(drains, 0);
  });

  test('drains the outbox on every trigger', () async {
    scheduler.start();
    triggers.add(null);
    await pumpEventQueue();

    triggers.add(null);
    await pumpEventQueue();

    expect(drains, 2);
  });

  test('stops draining after dispose', () async {
    scheduler.start();
    triggers.add(null);
    await pumpEventQueue();
    await scheduler.dispose();
    triggers.add(null);
    await pumpEventQueue();

    expect(drains, 1);
  });
}
