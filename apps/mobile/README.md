# Mobile

Aplicativo Flutter Android principal do MediFlow Learning.

## Estado atual

Até a Aula 20, a aplicação passou a iniciar em uma tela de benefícios com saldo fictício e a navegar para o “Modo Farmácia”, que apresenta o primeiro passo do checkout com identidade visual própria, responsividade e acessibilidade. Essa etapa recebe uma referência de receita e um EAN fictícios, valida os dados e somente então permite simular a leitura do medicamento. `CheckoutCubit` é a fonte de verdade do fluxo em execução: ele mantém a `CheckoutSession`, coordena os contratos de repositório e delega as transições à máquina de estados do domínio. A confirmação visual agora é um efeito reativo da sessão atualizada, não uma consequência direta do callback do formulário.

A composição atual separa estado, apresentação e design system:

- `MainApp` configura o `MaterialApp`, aplica o tema global e define `BenefitsHomePage` como tela inicial;
- `BenefitsHomePage` apresenta o saldo fictício, cria a sessão inicial e fornece `CheckoutCubit` ao Modo Farmácia com `BlocProvider`;
- `PharmacyModePage` permanece como `StatefulWidget` para coordenar recursos ligados ao ciclo de vida da rota;
- `_PharmacyModePageState` mantém a `GlobalKey<FormState>` e os controllers da receita e do EAN durante o ciclo de vida da rota, mas não armazena mais o contador;
- `CheckoutCubit` mantém `CheckoutSession` como snapshot do fluxo, coordena os contratos de repositório e delega todas as transições para `CheckoutStateMachine`;
- `DemoPrescriptionRepository`, `DemoMedicationRepository` e `DemoCheckoutRepository` fornecem respostas locais e determinísticas aos contratos exigidos pelo Cubit;
- `BlocConsumer<CheckoutCubit, CheckoutSession>` observa as emissões, reconstrói a região de conteúdo e executa efeitos pontuais da interface;
- `MedicationCounterContent` continua como `StatelessWidget` e recebe do `builder` o contador, os callbacks, os controllers e a chave do formulário;
- `CheckoutProgressIndicator` recebe etapa atual, total de etapas e rótulo para apresentar o progresso do checkout;
- `AppTheme` centraliza o `ThemeData`, o Material 3 e o `ColorScheme` do aplicativo;
- `AppSpacing` oferece uma escala compartilhada de espaçamentos;
- `MediFlowContentCard` encapsula largura máxima, margem, padding e rolagem vertical.

O contador não possui mais estado independente no fluxo em execução. A ação de leitura cria um `Medication` sintético e usa `context.read<CheckoutCubit>()` para solicitar a transição sem assinar a página inteira às mudanças. `scanMedication` envia `MedicationScanned` à `CheckoutStateMachine`, que produz outro snapshot da sessão ainda em `collectingMedication`. Quando `emit()` publica essa sessão, o `builder` do `BlocConsumer` deriva o contador de `session.medications.length` e entrega o valor atualizado a `MedicationCounterContent`. O `listener` reage à mesma emissão para executar os efeitos que não pertencem à árvore declarativa. Os widgets visuais recuperam cores e tipografia do tema mais próximo com `Theme.of(context)`, sem depender diretamente de valores de marca espalhados pela interface.

O `CheckoutCubit` atua como camada de coordenação entre o aplicativo e o domínio. Ele consulta os repositórios, converte resultados esperados do negócio em eventos de falha permanente, transforma falhas técnicas de criação e confirmação em falhas recuperáveis e delega a evolução da sessão à `CheckoutStateMachine`. A etapa interrompida e o identificador remoto são preservados para permitir retry sem recriar o pagamento. Depois de cada operação assíncrona, o Cubit verifica `isClosed` antes de emitir outro estado.

`Navigator.push` adiciona uma `MaterialPageRoute<void>` à pilha para abrir `PharmacyModePage`. A seta criada automaticamente pela `AppBar` executa o retorno, remove essa rota e descarta seu objeto `State`. Como o `BlocProvider` pertence à composição dessa rota, o `CheckoutCubit` criado por ele também é encerrado. Ao abrir o fluxo novamente, outra sessão local é criada em `collectingMedication`, sem medicamentos.

O formulário agrupa dois `TextFormField`s. A referência da receita é obrigatória. O EAN também é obrigatório, aceita somente dígitos, limita a entrada a 13 caracteres e exige exatamente esse comprimento para concluir a leitura. O botão “Usar EAN de demonstração” preenche um valor sintético conhecido para exercitar o fluxo sem câmera ou código de barras real.

Quando `FormState.validate` rejeita a entrada, a sessão e a confirmação permanecem inalteradas. Em uma leitura válida, `scanMedication()` apenas solicita a inclusão à máquina de estados. O `listenWhen` compara as sessões anterior e atual e libera o `listener` somente quando a quantidade de medicamentos aumenta. Depois que esse novo snapshot confirma a inclusão, o EAN é limpo para o próximo medicamento, o foco é removido e um `SnackBar` apresenta a confirmação. A referência da receita permanece no formulário como contexto da mesma compra. Os dois `TextEditingController`s são descartados junto com o estado da página.

O progresso inicial representa a etapa 1 de 4: quatro marcadores oferecem uma referência visual e o `LinearProgressIndicator` recebe o valor determinístico `0.25`. O componente usa os parâmetros recebidos para poder representar outras etapas futuramente.

O conteúdo ocupa a largura disponível até o limite de 480 pixels lógicos. `SafeArea` respeita recortes e áreas de navegação do dispositivo, enquanto `SingleChildScrollView` oferece uma saída para alturas reduzidas. O comportamento foi validado em retrato e paisagem, inclusive com a fonte ampliada, sem overflow e com o contador e o botão alcançáveis.

Na camada de acessibilidade:

- o contador usa `Semantics` com rótulo estável, valor dinâmico e `liveRegion` para anunciar mudanças;
- `ExcludeSemantics` impede que o texto visual do contador seja anunciado em duplicidade;
- o indicador de progresso combina etapa, total e rótulo em um único nó `Semantics`, enquanto `ExcludeSemantics` evita anúncios duplicados de seus descendentes visuais;
- o tema define 48 por 48 pixels lógicos como tamanho mínimo dos botões elevados;
- o teste `accessibility_guidelines_test.dart` verifica alvo de toque Android, rótulos dos controles e contraste textual;
- `checkout_navigation_test.dart` verifica o estado inicial, a abertura do Modo Farmácia, o retorno e a recriação do contador;
- `medication_input_validation_test.dart` verifica formulário vazio, EAN incompleto, preenchimento demonstrativo e leitura válida sem apresentar erros;
- `medication_counter_cubit_test.dart` verifica o estado inicial do Cubit e, com `blocTest`, o estado emitido depois de uma leitura;
- `checkout_cubit_test.dart` cobre o estado inicial, leitura de medicamento, validação e rejeição da receita, elegibilidade, criação, confirmação, falhas técnicas recuperáveis, retry e preservação do checkout remoto;
- `checkout_ui_integration_test.dart` verifica que uma leitura válida atualiza `CheckoutSession.medications`, apresenta o contador derivado e que uma emissão direta do Cubit também dispara o `SnackBar` de confirmação;
- as verificações automatizadas complementam os testes manuais com tecnologias assistivas, sem substituí-los.

Os logs de `initState`, `build` e `dispose` permitem observar o ciclo de vida durante o aprendizado. Os registros manuais dos estados `0`, `1` e `2` também demonstram que as emissões reconstruíram `MedicationCounterContent` pelo `BlocConsumer`, enquanto `PharmacyModePage` não precisou ser reconstruída a cada mudança do contador. O hot reload preserva o objeto `State`, o hot restart recria a aplicação e a remoção da rota executa `dispose` no estado da página.

O fluxo permanece local e sintético. Os repositórios demonstrativos permitem compor e exercitar `CheckoutCubit` sem infraestrutura externa, mas não comprovam comunicação HTTP, serialização, persistência, cache, timeouts reais, pagamento ou integrações externas, que ainda serão introduzidos em aulas posteriores.

## Execução

Consulte os dispositivos disponíveis, entre no diretório do aplicativo e execute-o informando o identificador desejado:

```bash
flutter devices
cd apps/mobile
flutter run -d <device-id>
```

## Validação

Entre no diretório do aplicativo e execute:

```bash
cd apps/mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

cd ../..
git diff --check
git status --short
```

O resultado esperado é formatação limpa, análise estática sem problemas, 23 testes aprovados — incluindo acessibilidade, navegação, validação de entrada, Cubits, integração da sessão com a interface e o efeito reativo de confirmação — e somente alterações intencionais exibidas pelo Git. O Quality Gate completo do monorepo também executa os testes de fronteira do package `checkout_domain`.

## Referências oficiais

- [StatelessWidget](https://api.flutter.dev/flutter/widgets/StatelessWidget-class.html)
- [StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [State e ciclo de vida](https://api.flutter.dev/flutter/widgets/State-class.html)
- [`setState`](https://api.flutter.dev/flutter/widgets/State/setState.html)
- [Temas no Flutter](https://docs.flutter.dev/cookbook/design/themes)
- [Entendendo constraints](https://docs.flutter.dev/ui/layout/constraints)
- [Abordagem geral para aplicativos adaptáveis](https://docs.flutter.dev/ui/adaptive-responsive/general)
- [`SafeArea`](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)
- [`SingleChildScrollView`](https://api.flutter.dev/flutter/widgets/SingleChildScrollView-class.html)
- [Acessibilidade no Flutter](https://docs.flutter.dev/ui/accessibility)
- [Testes de acessibilidade](https://docs.flutter.dev/ui/accessibility/accessibility-testing)
- [`Semantics`](https://api.flutter.dev/flutter/widgets/Semantics-class.html)
- [`ExcludeSemantics`](https://api.flutter.dev/flutter/widgets/ExcludeSemantics-class.html)
- [Navegação e roteamento](https://docs.flutter.dev/ui/navigation)
- [Navegar para uma nova tela e voltar](https://docs.flutter.dev/cookbook/navigation/navigation-basics)
- [`MaterialPageRoute`](https://api.flutter.dev/flutter/material/MaterialPageRoute-class.html)
- [`LinearProgressIndicator`](https://api.flutter.dev/flutter/material/LinearProgressIndicator-class.html)
- [Criar um formulário com validação](https://docs.flutter.dev/cookbook/forms/validation)
- [`TextFormField`](https://api.flutter.dev/flutter/material/TextFormField-class.html)
- [`TextEditingController`](https://api.flutter.dev/flutter/widgets/TextEditingController-class.html)
- [`FilteringTextInputFormatter`](https://api.flutter.dev/flutter/services/FilteringTextInputFormatter-class.html)
- [`LengthLimitingTextInputFormatter`](https://api.flutter.dev/flutter/services/LengthLimitingTextInputFormatter-class.html)
- [`SnackBar`](https://api.flutter.dev/flutter/material/SnackBar-class.html)
- [Introdução aos testes de widget](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Localizar widgets em testes](https://docs.flutter.dev/cookbook/testing/widget/finders)
- [`flutter_bloc`](https://pub.dev/packages/flutter_bloc)
- [`bloc_test`](https://pub.dev/packages/bloc_test)
