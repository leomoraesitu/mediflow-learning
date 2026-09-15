import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/design_system/widgets/mediflow_content_card.dart';

class MedicationCounterContent extends StatelessWidget {
  const MedicationCounterContent({
    required this.medicationLabel,
    required this.medicationCount,
    required this.onScan,
    required this.prescriptionController,
    required this.eanController,
    required this.formKey,
    required this.onFillDemoEan,
    required this.onSubmit,
    required this.onCheckEligibility,
    required this.onCreateCheckout,
    required this.onConfirmPayment,
    super.key,
  });

  final String medicationLabel;
  final int medicationCount;
  final VoidCallback? onScan;
  final TextEditingController prescriptionController;
  final TextEditingController eanController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onFillDemoEan;
  final VoidCallback? onSubmit;
  final VoidCallback? onCheckEligibility;
  final VoidCallback? onCreateCheckout;
  final VoidCallback? onConfirmPayment;

  @override
  Widget build(BuildContext context) {
    debugPrint('MedicationCounterContent: build — $medicationCount');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MediFlowContentCard(
      child: Form(
        key: formKey,
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
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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
              value: '$medicationCount',
              child: ExcludeSemantics(
                child: Text(medicationLabel, style: theme.textTheme.titleMedium),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onScan, child: const Text('Simular leitura')),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(onPressed: onSubmit, child: const Text('Validar compra')),
            if (onCheckEligibility != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: onCheckEligibility,
                child: const Text('Verificar elegibilidade'),
              ),
            ],
            if (onCreateCheckout != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(onPressed: onCreateCheckout, child: const Text('Criar pagamento')),
            ],
            if (onConfirmPayment != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(onPressed: onConfirmPayment, child: const Text('Confirmar pagamento')),
            ],
          ],
        ),
      ),
    );
  }
}
