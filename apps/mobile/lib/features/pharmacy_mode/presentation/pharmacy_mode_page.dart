import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_progress_indicator.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_progress_selector.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/medication_counter_content.dart';

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
    context.read<CheckoutCubit>().scanMedication(
      Medication(
        ean: _eanController.text,
        name: 'Medicamento demonstrativo',
        unitPriceInCents: 2500,
      ),
    );
  }

  Future<void> _submitPrescription() async {
    final reference = _prescriptionController.text.trim();

    if (reference.isEmpty) {
      return;
    }

    await context.read<CheckoutCubit>().submitPrescription(Prescription(reference: reference));
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
            BlocSelector<CheckoutCubit, CheckoutSession, CheckoutProgressData>(
              selector: selectCheckoutProgress,
              builder: (context, progress) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: CheckoutProgressIndicator(
                    currentStep: progress.currentStep,
                    totalSteps: 4,
                    label: progress.label,
                  ),
                );
              },
            ),
            BlocSelector<
              CheckoutCubit,
              CheckoutSession,
              ({CheckoutStatus status, String? message, String? remoteCheckoutId})
            >(
              selector: (session) => (
                status: session.status,
                message: session.statusMessage,
                remoteCheckoutId: session.remoteCheckoutId,
              ),
              builder: (context, feedback) {
                if (feedback.status == CheckoutStatus.paid && feedback.remoteCheckoutId != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            'Pagamento confirmado',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Checkout ${feedback.remoteCheckoutId} concluído.'),
                      ],
                    ),
                  );
                }
                if (feedback.message == null) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(liveRegion: true, child: Text(feedback.message!)),
                      if (feedback.status == CheckoutStatus.recoverableFailure) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ElevatedButton(
                          onPressed: () => context.read<CheckoutCubit>().retry(),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: BlocConsumer<CheckoutCubit, CheckoutSession>(
                listenWhen: (previous, current) {
                  return current.medications.length > previous.medications.length;
                },
                listener: (context, session) {
                  _eanController.clear();
                  FocusScope.of(context).unfocus();

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Medicamento adicionado à compra.')));
                },
                builder: (context, session) {
                  return MedicationCounterContent(
                    count: session.medications.length,
                    onScan: _scanMedication,
                    prescriptionController: _prescriptionController,
                    eanController: _eanController,
                    formKey: _formKey,
                    onFillDemoEan: _fillDemoEan,
                    onSubmit:
                        session.status == CheckoutStatus.collectingMedication &&
                            session.medications.isNotEmpty
                        ? _submitPrescription
                        : null,
                    onCheckEligibility:
                        session.status == CheckoutStatus.checkingEligibility &&
                            session.medications.isNotEmpty
                        ? () => context.read<CheckoutCubit>().checkEligibility(
                            session.medications.first,
                          )
                        : null,
                    onCreateCheckout: session.status == CheckoutStatus.creatingPayment
                        ? () => context.read<CheckoutCubit>().createCheckout()
                        : null,
                    onConfirmPayment:
                        session.status == CheckoutStatus.awaitingConfirmation &&
                            session.remoteCheckoutId != null
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
