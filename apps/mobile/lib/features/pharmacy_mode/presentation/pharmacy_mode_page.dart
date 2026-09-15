import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_progress_indicator.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_view_state.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/medication_counter_content.dart';

typedef _Progress = ({int currentStep, int totalSteps, String label});

class PharmacyModePage extends StatefulWidget {
  const PharmacyModePage({super.key});

  @override
  State<PharmacyModePage> createState() {
    return _PharmacyModePageState();
  }
}

class _PharmacyModePageState extends State<PharmacyModePage> {
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
    context.read<CheckoutCubit>().scanMedication(_eanController.text);
  }

  Future<void> _submitPrescription() async {
    final reference = _prescriptionController.text.trim();

    if (reference.isEmpty) {
      return;
    }

    await context.read<CheckoutCubit>().submitPrescription(reference);
  }

  @override
  void initState() {
    super.initState();
    debugPrint('PharmacyModePage: initState');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('PharmacyModePage: build');

    return Scaffold(
      appBar: AppBar(title: const Text('Modo Farmácia')),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocSelector<CheckoutCubit, CheckoutViewState, _Progress>(
              selector: (state) => (
                currentStep: state.currentStep,
                totalSteps: state.totalSteps,
                label: state.stepLabel,
              ),
              builder: (context, progress) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: CheckoutProgressIndicator(
                    currentStep: progress.currentStep,
                    totalSteps: progress.totalSteps,
                    label: progress.label,
                  ),
                );
              },
            ),
            // O seletor devolve um objeto só, com igualdade de valor. Antes era
            // um registro de três campos montado aqui, e a decisão de qual
            // deles virava qual tela vivia neste `builder`.
            BlocSelector<CheckoutCubit, CheckoutViewState, CheckoutFeedback>(
              selector: (state) => state.feedback,
              builder: (context, feedback) {
                // `switch` exaustivo sobre a hierarquia selada: uma variante
                // nova quebra a compilação em vez de cair num caso silencioso.
                return switch (feedback) {
                  NoFeedback() => const SizedBox.shrink(),
                  SuccessFeedback(:final checkoutId) => _FeedbackBlock(
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Pagamento confirmado',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Checkout $checkoutId concluído.'),
                    ],
                  ),
                  RecoverableFailure(:final message) => _FeedbackBlock(
                    children: [
                      Semantics(liveRegion: true, child: Text(message)),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: () => context.read<CheckoutCubit>().retry(),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                  PermanentFailure(:final message) => _FeedbackBlock(
                    children: [Semantics(liveRegion: true, child: Text(message))],
                  ),
                };
              },
            ),
            Expanded(
              child: BlocConsumer<CheckoutCubit, CheckoutViewState>(
                listenWhen: (previous, current) {
                  return current.medicationCount > previous.medicationCount;
                },
                listener: (context, state) {
                  _eanController.clear();
                  FocusScope.of(context).unfocus();

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Medicamento adicionado à compra.')));
                },
                builder: (context, state) {
                  return MedicationCounterContent(
                    medicationLabel: state.medicationLabel,
                    medicationCount: state.medicationCount,
                    onScan: state.canScan ? _scanMedication : null,
                    prescriptionController: _prescriptionController,
                    eanController: _eanController,
                    formKey: _formKey,
                    onFillDemoEan: _fillDemoEan,
                    onSubmit: state.canSubmit ? _submitPrescription : null,
                    onCheckEligibility: state.canCheckEligibility
                        ? () => context.read<CheckoutCubit>().checkEligibility()
                        : null,
                    onCreateCheckout: state.canCreatePayment
                        ? () => context.read<CheckoutCubit>().createCheckout()
                        : null,
                    onConfirmPayment: state.canConfirmPayment
                        ? () => context.read<CheckoutCubit>().confirmPayment()
                        : null,
                  );
                },
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

class _FeedbackBlock extends StatelessWidget {
  const _FeedbackBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
