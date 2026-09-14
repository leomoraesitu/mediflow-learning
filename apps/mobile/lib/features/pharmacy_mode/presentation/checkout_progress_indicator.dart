import 'package:flutter/material.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';

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
                    i <= currentStep ? Icons.check_circle : Icons.circle_outlined,
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
            LinearProgressIndicator(value: progress, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
