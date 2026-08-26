import 'package:flutter/material.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/design_system/app_theme.dart';
import 'package:mediflow_mobile/design_system/widgets/mediflow_content_card.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const BenefitsHomePage(availableBalance: 250.0),
      theme: AppTheme.light,
    );
  }
}

class BenefitsHomePage extends StatelessWidget {
  const BenefitsHomePage({required this.availableBalance, super.key});

  final double availableBalance;

  void _openPharmacyMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return const PharmacyModePage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedBalance = availableBalance
        .toStringAsFixed(2)
        .replaceFirst('.', ',');

    return Scaffold(
      appBar: AppBar(title: const Text('MediFlow')),
      body: SafeArea(
        child: MediFlowContentCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Saldo disponível',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'R\$ $formattedBalance',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Benefício fictício para esta demonstração.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () {
                  _openPharmacyMode(context);
                },
                child: const Text('Iniciar Modo Farmácia'),
              ),
            ],
          ),
        ),
      ),
    );
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
  final _formKey = GlobalKey<FormState>();
  final _prescriptionController = TextEditingController();
  final _eanController = TextEditingController();

  void _fillDemoEan() {
    _eanController.text = '7891000000011';
  }

  void _scanMedication() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    setState(() {
      _scannedMedicationCount++;
    });

    _eanController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medicamento adicionado à compra.')),
    );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const CheckoutProgressIndicator(
                currentStep: 1,
                totalSteps: 4,
                label: 'Leitura do medicamento',
              ),
            ),
            Expanded(
              child: MedicationCounterContent(
                count: _scannedMedicationCount,
                onScan: _scanMedication,
                prescriptionController: _prescriptionController,
                eanController: _eanController,
                formKey: _formKey,
                onFillDemoEan: _fillDemoEan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('PharmacyModePage: dispose');
    _prescriptionController.dispose();
    _eanController.dispose();
    super.dispose();
  }
}

class MedicationCounterContent extends StatelessWidget {
  const MedicationCounterContent({
    required this.count,
    required this.onScan,
    required this.prescriptionController,
    required this.eanController,
    required this.formKey,
    required this.onFillDemoEan,
    super.key,
  });

  final int count;
  final VoidCallback onScan;
  final TextEditingController prescriptionController;
  final TextEditingController eanController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onFillDemoEan;

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
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 48,
              color: colorScheme.primary,
            ),
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
            TextFormField(
              controller: prescriptionController,
              decoration: const InputDecoration(
                labelText: 'Referência da receita',
                hintText: 'RX-001',
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a referência da receita.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: eanController,
              decoration: const InputDecoration(
                labelText: 'EAN do medicamento',
                hintText: '13 dígitos',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o EAN do medicamento.';
                }
                if (value.length != 13) {
                  return 'O EAN deve conter 13 dígitos.';
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onFillDemoEan,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Usar EAN de demonstração'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              container: true,
              liveRegion: true,
              label: 'Quantidade de medicamentos lidos',
              value: '$count',
              child: ExcludeSemantics(
                child: Text(
                  medicationLabel,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: onScan,
              child: const Text('Simular leitura'),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutProgressIndicator extends StatelessWidget {
  const CheckoutProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.label,
    super.key,
  });

  final int currentStep;
  final int totalSteps;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = currentStep / totalSteps;

    return Semantics(
      container: true,
      label: 'Progresso do checkout',
      value: 'Etapa $currentStep de $totalSteps: $label',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Wrap(
              children: [
                for (var i = 1; i <= totalSteps; i++)
                  Icon(
                    i <= currentStep
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                Text(
                  'Etapa $currentStep de $totalSteps: $label',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: progress,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
