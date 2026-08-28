import 'package:flutter_bloc/flutter_bloc.dart';

final class MedicationCounterState {
  final int scannedMedicationCount;

  const MedicationCounterState({required this.scannedMedicationCount});
}

final class MedicationCounterCubit extends Cubit<MedicationCounterState> {
  MedicationCounterCubit()
    : super(const MedicationCounterState(scannedMedicationCount: 0));

  void registerMedicationScan() {
    final nextCount = state.scannedMedicationCount + 1;
    emit(MedicationCounterState(scannedMedicationCount: nextCount));
  }
}
