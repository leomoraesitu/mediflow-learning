# 0002 — A fronteira da camada de apresentação

## Status

Aceito (Aula 51).

## Contexto

Até a Aula 49, toda a interface vivia em `apps/mobile/lib/main.dart` — 645 linhas contendo as quatro telas, o `main()` e o `MainApp`. O `CheckoutCubit` estendia `Cubit<CheckoutSession>`, isto é, emitia o objeto de domínio diretamente para a View.

A consequência não era estética. Quem recebe `CheckoutSession` precisa saber o que `CheckoutStatus.awaitingConfirmation` significa, e por isso as regras de apresentação foram se alojando dentro de `build()`:

- cinco expressões decidindo quais botões existem (`session.status == ... && session.medications.isNotEmpty`);
- a escolha de **qual** medicamento verificar (`session.medications.first`);
- a construção de objetos de domínio no widget (`Medication(ean: ..., name: 'Medicamento demonstrativo', unitPriceInCents: 2500)`);
- a pluralização do contador;
- um `if` de três ramos traduzindo status e mensagem em tela de sucesso, tela de erro ou nada.

Havia também um efeito mensurável: `CheckoutSession` não declara `==`. O `Cubit` suprime emissões de estado repetido comparando com `==`, e como toda transição produzia uma instância nova, **essa supressão nunca atuou**.

## Decisão

### O Cubit é o ViewModel, e emite um estado de visão próprio

`CheckoutCubit` passou a ser `Cubit<CheckoutViewState>`. A `CheckoutSession` virou campo privado `_session`: ela continua sendo a fonte de verdade do fluxo e o que vai para o armazenamento, mas não atravessa para a View.

`CheckoutViewState` carrega decisões, não estado bruto: `canConfirmPayment`, não `status`. `CheckoutViewState.fromSession` é o único ponto que conhece o domínio.

**Alternativa considerada e recusada:** o [guia de arquitetura do Flutter](https://docs.flutter.dev/app-architecture/guide) descreve o ViewModel como `ChangeNotifier`. Adotá-lo literalmente exigiria reescrever os Cubits e descartar a suíte de `blocTest` existente, em troca de nenhuma propriedade que o desenho atual não tenha. O guia exige que a View não decida; não exige uma classe base específica.

### As perguntas de apresentação não sobem para o domínio

`CheckoutViewState.fromSession` lê `status`, `medications`, `remoteCheckoutId`, `statusMessage` e `retryTargetStatus`, e decide a partir deles. Nenhum `session.canConfirmPayment` foi acrescentado ao domínio: se `CheckoutSession` respondesse isso, o pacote puro passaria a saber que existe um botão.

### As assinaturas do ViewModel falam a língua da View

Com o domínio fora da View, ela não consegue mais construir `Medication` nem `Prescription`. Três métodos mudaram: `scanMedication(String ean)`, `submitPrescription(String reference)` e `checkEligibility()` sem parâmetro — a escolha do medicamento verificado passou a ser do ViewModel.

Isso não foi uma decisão de estilo tomada em separado; é uma consequência forçada pela fronteira de tipos.

### O feedback é uma hierarquia selada

`CheckoutFeedback` — `NoFeedback`, `SuccessFeedback`, `RecoverableFailure`, `PermanentFailure` — substitui o `if` de três ramos. A View renderiza com `switch` exaustivo, sem `default`: uma variante nova quebra a compilação em vez de cair num caso silencioso.

### A igualdade é de valor, e é verificada

`CheckoutViewState` e as quatro variantes de feedback declaram `==` e `hashCode` sobre a mesma lista de campos.

Isso é verificável, e foi verificado: substituindo o `==` de `CheckoutViewState` por identidade, **um único teste fica vermelho** — `does not emit again when a transition produces an identical view state`. Os outros treze continuariam verdes, o que significa que ele é o único que mede esta decisão.

O cenário dele é real e não fabricado: `submitPrescription` sem medicamentos passa por `validatingPrescription` e `checkingEligibility`, e os dois produzem o mesmo estado de visão — a etapa e o rótulo coincidem em `selectCheckoutProgress`, e `canCheckEligibility` exige pelo menos um item. Duas transições de domínio, uma emissão.

## Consequências

**Os oráculos dos testes mudaram de natureza.** Com `_session` privado, nenhum teste pode mais espiar estado interno. O EAN informado e a referência da receita passaram a ser verificados pelo que atravessou a fronteira: fakes que registram o que receberam. Verifica-se o contrato, não a implementação.

**A View perdeu poder de improvisar.** Uma tela que precise de uma informação nova não pode mais derivá-la de `session` no `build()` — o campo tem que ser acrescentado ao `CheckoutViewState` e ao seu `==`. É atrito deliberado.

**`CheckoutViewState.fromSession` virou o ponto de acoplamento único com o domínio.** Quando a Aula 55 acrescentar `userId` à sessão, só esse arquivo precisa decidir se isso vira informação de tela.

**O limite do `canScan` foi fechado na Aula 52.** Ele nasceu constante `true`, reproduzindo o comportamento anterior — o botão de leitura sempre esteve habilitado, e apertá-lo fora de `collectingMedication` levava a `InvalidCheckoutTransitionException`, porque `MedicationScanned` não tem transição a partir de outro estado. Agora `canScan` exige `collectingMedication`, e a regra tem teste nos dois sentidos.

**A propriedade do `CheckoutCubit` também ficou para a Aula 52.** `BlocProvider.value` não fecha o que recebe, e o cubit nascia dentro de um callback de navegação: cada abertura do Modo Farmácia deixava para trás um cubit com um `DriftCheckoutSessionStorage` dentro. A correção resolve o `restore()` antes de navegar e fecha depois de `Navigator.push` completar — criação e destruição simétricas, no mesmo método —, com `context.mounted` cobrindo o caso em que a tela sai antes da resolução.

**A validação da receita passou a ser por campo, não por formulário.** `_submitPrescription` chamava uma checagem paralela de `isEmpty` que retornava em silêncio. Trocá-la por `_formKey.currentState.validate()` parecia a simplificação óbvia e estava errada: o formulário inclui o campo do EAN, que o `listener` limpa depois de cada leitura, então validar tudo bloquearia a submissão no fluxo normal. Um teste existente pegou isso. A validação usa uma `GlobalKey<FormFieldState<String>>` do campo da receita.
