import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/checkout_view_state.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/presentation/medication_counter_content.dart';

/// A tradução de `primaryAction` em tipo de botão.
///
/// `MedicationCounterContent` é um widget puro: ele recebe a decisão pronta e
/// não consulta cubit nenhum. Por isso estes testes não montam `BlocProvider`
/// nem esboço de repositório — a decisão em si é testada do outro lado da
/// costura, em `checkout_view_state_test.dart`.
void main() {
  late TextEditingController prescriptionController;
  late TextEditingController eanController;
  late GlobalKey<FormState> formKey;
  late GlobalKey<FormFieldState<String>> prescriptionFieldKey;

  setUp(() {
    prescriptionController = TextEditingController();
    eanController = TextEditingController();
    formKey = GlobalKey<FormState>();
    prescriptionFieldKey = GlobalKey<FormFieldState<String>>();
  });

  tearDown(() {
    prescriptionController.dispose();
    eanController.dispose();
  });

  // Os cinco callbacks são parâmetros porque três dos botões só são
  // renderizados quando o seu callback é não nulo. Com eles cravados em nulo,
  // a árvore teria dois botões e a contagem de preenchidos não afirmaria nada.
  Widget buildSubject({
    CheckoutAction? primaryAction,
    VoidCallback? onScan,
    VoidCallback? onSubmit,
    VoidCallback? onCheckEligibility,
    VoidCallback? onCreateCheckout,
    VoidCallback? onConfirmPayment,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MedicationCounterContent(
          medicationLabel: '2 medicamentos lidos',
          medicationCount: 2,
          primaryAction: primaryAction,
          onScan: onScan,
          prescriptionController: prescriptionController,
          eanController: eanController,
          formKey: formKey,
          prescriptionFieldKey: prescriptionFieldKey,
          onFillDemoEan: () {},
          onSubmit: onSubmit,
          onCheckEligibility: onCheckEligibility,
          onCreateCheckout: onCreateCheckout,
          onConfirmPayment: onConfirmPayment,
        ),
      ),
    );
  }

  Widget buildSubjectWithEveryAction({CheckoutAction? primaryAction}) {
    return buildSubject(
      primaryAction: primaryAction,
      onScan: () {},
      onSubmit: () {},
      onCheckEligibility: () {},
      onCreateCheckout: () {},
      onConfirmPayment: () {},
    );
  }

  group('button hierarchy', () {
    testWidgets('renders exactly one filled button, for the primary action', (tester) async {
      await tester.pumpWidget(
        buildSubjectWithEveryAction(primaryAction: CheckoutAction.confirmPayment),
      );

      // As duas asserções são uma só afirmação partida ao meio: a primeira é a
      // contagem, a segunda é a identidade. Sem a contagem, uma implementação
      // que preenchesse os cinco botões passaria — foi assim que a versão
      // anterior deste teste sobreviveu à quebra dirigida.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Confirmar pagamento'), findsOneWidget);
    });

    testWidgets('renders non-primary actions as outlined buttons', (tester) async {
      await tester.pumpWidget(buildSubjectWithEveryAction(primaryAction: CheckoutAction.submit));

      expect(find.widgetWithText(OutlinedButton, 'Simular leitura'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(4));
    });

    testWidgets('renders no filled button when no action is primary', (tester) async {
      // O estado da tela durante uma requisição em voo, em falha e em `paid`.
      // É também quando o bloco de feedback mostra "Tentar novamente"
      // preenchido: um primário aqui daria dois na mesma tela.
      await tester.pumpWidget(buildSubjectWithEveryAction());

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNWidgets(5));
    });

    testWidgets('forwards the callback of the button that was pressed', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        buildSubject(primaryAction: CheckoutAction.scan, onScan: () => pressed = true),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Simular leitura'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('forwards a null callback as a disabled button', (tester) async {
      await tester.pumpWidget(buildSubject(primaryAction: CheckoutAction.scan, onScan: null));

      final finder = find.widgetWithText(FilledButton, 'Simular leitura');

      expect(finder, findsOneWidget);
      expect(tester.widget<FilledButton>(finder).onPressed, isNull);
    });
  });
}
