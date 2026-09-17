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

class BenefitsHomePage extends StatefulWidget {
  final String userId;
  final double availableBalance;
  final CheckoutDatabase database;
  final CheckoutRepository checkoutRepository;
  final PrescriptionRepository prescriptionRepository;
  final MedicationRepository medicationRepository;
  final OperationalSettings settings;
  final Stream<bool> Function(String userId) hasPendingSync;

  const BenefitsHomePage({
    super.key,
    required this.userId,
    required this.availableBalance,
    required this.database,
    required this.checkoutRepository,
    required this.prescriptionRepository,
    required this.medicationRepository,
    required this.settings,
    required this.hasPendingSync,
  });

  @override
  State<BenefitsHomePage> createState() => _BenefitsHomePageState();
}

class _BenefitsHomePageState extends State<BenefitsHomePage> {
  /// O fluxo é criado uma vez, e não a cada `build`.
  ///
  /// `hasPendingSync` é uma função porque depende do usuário, e o Drift
  /// devolve um `Stream` novo a cada chamada. Chamá-la dentro do `build`
  /// faria o `StreamBuilder` do indicador ver um fluxo diferente a cada
  /// reconstrução, reassinar, receber uma emissão, reconstruir — um laço
  /// infinito que ainda vaza uma consulta de banco por volta.
  late final Stream<bool> _hasPendingSync = widget.hasPendingSync(widget.userId);

  Future<void> _openPharmacyMode() async {
    final storage = DriftCheckoutSessionStorage(widget.database, widget.userId);

    final cubit = await CheckoutCubit.restore(
      fallbackSession: CheckoutSession(
        id: 'session-001',
        availableBalanceInCents: (widget.availableBalance * 100).round(),
        prescription: null,
        medications: [],
        status: CheckoutStatus.collectingMedication,
      ),
      storage: storage,
      stateMachine: const CheckoutStateMachine(),
      prescriptionRepository: widget.prescriptionRepository,
      medicationRepository: widget.medicationRepository,
      checkoutRepository: widget.checkoutRepository,
    );
    if (!mounted) {
      await cubit.close();
      return;
    }
    // `BlocProvider.value` não fecha o que recebe — por isso o fechamento é
    // explícito logo abaixo. `push` completa quando a rota é desempilhada,
    // então criação e destruição ficam simétricas, no mesmo método.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return BlocProvider.value(value: cubit, child: const PharmacyModePage());
        },
      ),
    );
    await cubit.close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedBalance = widget.availableBalance.toStringAsFixed(2).replaceFirst('.', ',');

    return Scaffold(
      appBar: AppBar(title: const Text('MediFlow')),
      body: SafeArea(
        child: Column(
          children: [
            PendingSyncIndicator(hasPendingSync: _hasPendingSync),
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
                        if (widget.settings.maintenanceMode)
                          Text(widget.settings.maintenanceMessage, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),

                        ElevatedButton(
                          onPressed: widget.settings.maintenanceMode
                              ? null
                              : () {
                                  _openPharmacyMode();
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
