import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/medication_counter_cubit.dart';

void main() {
  group('MedicationCounterCubit', () {
    test('starts with zero scanned medications', () {
      final cubit = MedicationCounterCubit();

      addTearDown(cubit.close);

      expect(cubit.state.scannedMedicationCount, 0);
    });

    blocTest<MedicationCounterCubit, MedicationCounterState>(
      'emits one scanned medication when a scan is registered',
      build: MedicationCounterCubit.new,
      act: (cubit) => cubit.registerMedicationScan(),
      expect: () => [
        isA<MedicationCounterState>().having(
          (state) => state.scannedMedicationCount,
          'scannedMedicationCount',
          1,
        ),
      ],
    );
  });
}
