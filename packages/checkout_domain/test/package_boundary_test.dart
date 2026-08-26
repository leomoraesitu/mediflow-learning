import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

Future<void> main() async {
  final libraryUri = await Isolate.resolvePackageUri(
    Uri.parse('package:checkout_domain/checkout_domain.dart'),
  );
  final pubspecUri = libraryUri?.resolve('../pubspec.yaml');

  final pubspec = File.fromUri(pubspecUri!).readAsStringSync();

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
