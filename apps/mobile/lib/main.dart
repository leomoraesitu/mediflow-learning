import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: PharmacyModePage());
  }
}

class PharmacyModePage extends StatefulWidget {
  const PharmacyModePage({super.key});

  @override
  State<PharmacyModePage> createState() {
    return _PharmacyModePageState();
  }
}

class _PharmacyModePageState extends State<PharmacyModePage> {
  int _scannedMedicationCount = 0;

  void _scanMedication() {
    setState(() {
      _scannedMedicationCount++;
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('PharmacyModePage: initState');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'PharmacyModePage: build — $_scannedMedicationCount medicamento(s)',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Modo Farmácia')),
      body: MedicationCounterContent(
        count: _scannedMedicationCount,
        onScan: _scanMedication,
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('PharmacyModePage: dispose');
    super.dispose();
  }
}

class MedicationCounterContent extends StatelessWidget {
  const MedicationCounterContent({
    required this.count,
    required this.onScan,
    super.key,
  });

  final int count;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    debugPrint('MedicationCounterContent: build — $count');

    final medicationLabel = switch (count) {
      0 => 'Nenhum medicamento lido',
      1 => '1 medicamento lido',
      _ => '$count medicamentos lidos',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medicationLabel),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onScan,
            child: const Text('Simular leitura'),
          ),
        ],
      ),
    );
  }
}
