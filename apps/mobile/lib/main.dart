import 'package:flutter/material.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/design_system/app_theme.dart';
import 'package:mediflow_mobile/design_system/widgets/mediflow_content_card.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const PharmacyModePage(), theme: AppTheme.light);
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
      body: SafeArea(
        child: MedicationCounterContent(
          count: _scannedMedicationCount,
          onScan: _scanMedication,
        ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final medicationLabel = switch (count) {
      0 => 'Nenhum medicamento lido',
      1 => '1 medicamento lido',
      _ => '$count medicamentos lidos',
    };
    return MediFlowContentCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined, size: 48, color: colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Leitura de medicamentos',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Simule a leitura para acompanhar os itens desta compra.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(medicationLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: onScan,
            child: const Text('Simular leitura'),
          ),
        ],
      ),
    );
  }
}
