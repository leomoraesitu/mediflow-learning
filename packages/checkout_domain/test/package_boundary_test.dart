import 'dart:io';

import 'package:test/test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('checkout_domain boundaries', () {
    test('uses shared workspace resolution', () {
      expect(pubspec, contains('resolution: workspace'));
    });

    test('does not declare infrastructure dependencies', () {
      const forbiddenDependencies = <String>[
        'flutter:',
        'firebase_',
        'dio:',
        'drift:',
      ];

      for (final dependency in forbiddenDependencies) {
        expect(
          pubspec,
          isNot(contains(dependency)),
          reason: 'checkout_domain não pode depender de $dependency',
        );
      }
    });
  });
}
