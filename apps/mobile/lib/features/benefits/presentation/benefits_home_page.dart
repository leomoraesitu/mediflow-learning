import 'package:checkout_domain/checkout_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/design_system/widgets/mediflow_content_card.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/cubit/checkout_cubit.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/drift_checkout_session_storage.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/pending_sync_indicator.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/pharmacy_mode_page.dart';

class BenefitsHomePage extends StatelessWidget {
  final double availableBalance;
  final CheckoutDatabase database;
  final CheckoutRepository checkoutRepository;
  final PrescriptionRepository prescriptionRepository;
  final MedicationRepository medicationRepository;
  final OperationalSettings settings;
  final Stream<bool> hasPendingSync;

  const BenefitsHomePage({
    super.key,
    required this.availableBalance,
    required this.database,
    required this.checkoutRepository,
    required this.prescriptionRepository,
    required this.medicationRepository,
    required this.settings,
    this.hasPendingSync = const Stream<bool>.empty(),
  });

  void _openPharmacyMode(BuildContext context) {
    final storage = DriftCheckoutSessionStorage(database);

    final cubitFuture = CheckoutCubit.restore(
      fallbackSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: (availableBalance * 100).round(),
        prescription: null,
        medications: [],
        status: CheckoutStatus.collectingMedication,
      ),
      storage: storage,
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: prescriptionRepository,
      medicationRepository: medicationRepository,
      checkoutRepository: checkoutRepository,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return FutureBuilder<CheckoutCubit>(
            future: cubitFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return BlocProvider.value(value: snapshot.data!, child: const PharmacyModePage());
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedBalance = availableBalance.toStringAsFixed(2).replaceFirst('.', ',');

    return Scaffold(
      appBar: AppBar(title: const Text('MediFlow')),
      body: SafeArea(
        child: Column(
          children: [
            PendingSyncIndicator(hasPendingSync: hasPendingSync),
            Expanded(
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

                    Column(
                      children: [
                        if (settings.maintenanceMode)
                          Text(settings.maintenanceMessage, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),

                        ElevatedButton(
                          onPressed: settings.maintenanceMode
                              ? null
                              : () {
                                  _openPharmacyMode(context);
                                },
                          child: const Text('Iniciar Modo Farmácia'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
