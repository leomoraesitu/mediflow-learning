import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships a product name as the app label, not the package directory', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:label="MediFlow"'));
    expect(manifest, isNot(contains('mediflow_mobile')));
  });
}
