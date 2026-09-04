# Mobile

Aplicativo Flutter Android principal do MediFlow Learning.

## Estado atual

Até a Aula 28, a aplicação passou a iniciar em uma tela de benefícios com saldo fictício e a navegar para o “Modo Farmácia”, que apresenta o progresso do checkout com identidade visual própria, responsividade e acessibilidade. A primeira etapa recebe uma referência de receita e um EAN fictícios, valida os dados e somente então permite simular a leitura do medicamento. `CheckoutCubit` é a fonte de verdade do fluxo em execução: ele mantém a `CheckoutSession`, coordena os contratos de repositório e delega as transições à máquina de estados do domínio. A confirmação visual é um efeito reativo da sessão atualizada, seletores derivados apresentam progresso e feedback contextual, e a interface oferece somente a ação compatível com a etapa atual até apresentar a conclusão acessível do pagamento demonstrativo. A camada `data` fornece a representação serializável da sessão completa, um contrato assíncrono de armazenamento e implementações substituíveis em memória e SQLite com Drift, sem acoplar o domínio a JSON ou persistência.

A composição atual separa estado, apresentação e design system:

- `MainApp` configura o `MaterialApp`, aplica o tema global e define `BenefitsHomePage` como tela inicial;
- `BenefitsHomePage` apresenta o saldo fictício, cria a sessão inicial e fornece `CheckoutCubit` ao Modo Farmácia com `BlocProvider`;
- `PharmacyModePage` permanece como `StatefulWidget` para coordenar recursos ligados ao ciclo de vida da rota;
- `_PharmacyModePageState` mantém a `GlobalKey<FormState>` e os controllers da receita e do EAN durante o ciclo de vida da rota, mas não armazena mais o contador;
- `CheckoutCubit` mantém `CheckoutSession` como snapshot do fluxo, coordena os contratos de repositório e delega todas as transições para `CheckoutStateMachine`;
- `CheckoutSessionSnapshot` converte a sessão entre o domínio e uma representação formada por mapas, listas e valores compatíveis com JSON;
- `CheckoutSessionStorage` define as operações assíncronas `save`, `load` e `clear`; `InMemoryCheckoutSessionStorage` e `DriftCheckoutSessionStorage` oferecem implementações substituíveis;
- `CheckoutDatabase` concentra o schema Drift e permite abrir SQLite em memória nos testes ou `mediflow_checkout.sqlite` no dispositivo;
- `DemoPrescriptionRepository`, `DemoMedicationRepository` e `DemoCheckoutRepository` fornecem respostas locais e determinísticas aos contratos exigidos pelo Cubit;
- `BlocConsumer<CheckoutCubit, CheckoutSession>` observa as emissões, reconstrói a região de conteúdo e executa efeitos pontuais da interface;
- `BlocSelector<CheckoutCubit, CheckoutSession, CheckoutProgressData>` seleciona somente a etapa e o rótulo usados pelo indicador de progresso;
- um segundo `BlocSelector` observa somente o status, a mensagem e o identificador remoto necessários aos feedbacks de falha e sucesso;
- `MedicationCounterContent` continua como `StatelessWidget` e recebe do `builder` o contador, os callbacks disponíveis para o status atual, os controllers e a chave do formulário;
- `CheckoutProgressIndicator` recebe do selector a etapa atual e o rótulo, além do total fixo de quatro etapas, para apresentar o progresso do checkout;
- `AppTheme` centraliza o `ThemeData`, o Material 3 e o `ColorScheme` do aplicativo;
- `AppSpacing` oferece uma escala compartilhada de espaçamentos;
- `MediFlowContentCard` encapsula largura máxima, margem, padding e rolagem vertical.

O contador não possui mais estado independente no fluxo em execução. A ação de leitura cria um `Medication` sintético e usa `context.read<CheckoutCubit>()` para solicitar a transição sem assinar a página inteira às mudanças. `scanMedication` envia `MedicationScanned` à `CheckoutStateMachine`, que produz outro snapshot da sessão ainda em `collectingMedication`. Quando `emit()` publica essa sessão, o `builder` do `BlocConsumer` deriva o contador de `session.medications.length` e entrega o valor atualizado a `MedicationCounterContent`. O `listener` reage à mesma emissão para executar os efeitos que não pertencem à árvore declarativa. Os widgets visuais recuperam cores e tipografia do tema mais próximo com `Theme.of(context)`, sem depender diretamente de valores de marca espalhados pela interface.

O `CheckoutCubit` atua como camada de coordenação entre o aplicativo e o domínio. Ele consulta os repositórios, converte resultados esperados do negócio em eventos de falha permanente, transforma falhas técnicas de criação e confirmação em falhas recuperáveis e delega a evolução da sessão à `CheckoutStateMachine`. A etapa interrompida e o identificador remoto são preservados para permitir retry sem recriar o pagamento. Depois de cada operação assíncrona, o Cubit verifica `isClosed` antes de emitir outro estado.

`CheckoutSessionSnapshot` pertence à camada `data` porque descreve o formato de transporte e futura persistência da sessão, enquanto `CheckoutSession` permanece como modelo de domínio independente desses detalhes. `fromDomain` e `toDomain` atravessam a fronteira com o domínio; `toMap` e `fromMap` atravessam a fronteira serializável. O mapa preserva saldo, receita, medicamentos, status, identificador remoto, etapa de retry e mensagem contextual. A lista recebida pelo snapshot é copiada com `List.unmodifiable`, impedindo alterações estruturais posteriores. Os estados são gravados pelos nomes do enum e reconstruídos com `byName`; portanto, uma futura renomeação exigirá versionamento ou migração dos dados já armazenados.

O teste de round-trip passa a sessão por `Map`, `jsonEncode`, `jsonDecode` e novamente pelo snapshot antes de reconstruir o domínio. Esse teste comprova que os valores usados atualmente são compatíveis com JSON e preservam o contexto completo da sessão, mas ainda não representa escrita em disco, banco de dados, tratamento de mapas corrompidos ou migração entre versões do esquema.

`CheckoutSessionStorage` separa o aplicativo da tecnologia que armazenará o snapshot. O contrato é assíncrono desde a primeira implementação para que consumidores possam receber futuramente uma versão baseada em I/O sem mudar sua própria API. `InMemoryCheckoutSessionStorage` guarda o mapa produzido por `toMap`, devolve outro snapshot reconstruído por `fromMap` e usa `null` para representar tanto o armazenamento inicial vazio quanto o estado posterior a `clear`. Como essa implementação vive somente na memória do processo, ela não restaura a sessão depois que o aplicativo é encerrado.

`CheckoutDatabase` introduz o schema SQLite com Drift. A tabela `CheckoutSessionRecords` possui um registro único identificado por `id = 1` e armazena o snapshot completo na coluna textual `payload`. `insertOnConflictUpdate` cria o registro inicial ou substitui o snapshot anterior, mantendo somente o estado mais recente. O schema começa na versão 1; alterações estruturais futuras deverão incrementar `schemaVersion` e definir a migração correspondente.

`DriftCheckoutSessionStorage` implementa o contrato convertendo `CheckoutSessionSnapshot` em mapa e JSON antes da escrita e realizando o caminho inverso durante a leitura. `CheckoutDatabase(super.executor)` preserva a injeção de SQLite em memória nos testes, enquanto `CheckoutDatabase.defaults()` usa `driftDatabase` para abrir ou criar `mediflow_checkout.sqlite` no armazenamento do aplicativo.

`CheckoutCubit` passou a aceitar um `CheckoutSessionStorage?` opcional. Quando presente, `_emitPersisted` substitui todas as chamadas diretas a `emit` — inclusive dentro de `submitPrescription`, `checkEligibility`, `createCheckout`, `confirmPayment` e `retry` — encadeando a emissão do novo estado com `storage.save(CheckoutSessionSnapshot.fromDomain(session))`. Um teste de TDD identificou que `retry()` havia ficado de fora dessa migração: como a transição de retry é puramente local (`CheckoutStateMachine` apenas devolve o `retryTargetStatus` salvo, sem repetir a chamada de rede), era fácil esquecer que ela também precisa atualizar o storage. Sem isso, um snapshot de `recoverableFailure` permanecia persistido mesmo depois do retry mover o estado em memória adiante, e um reinício do app nesse intervalo restauraria a falha antiga em vez do estado retomado. O construtor nomeado `CheckoutCubit.restore` encapsula a leitura inicial: carrega o snapshot mais recente do storage informado e o usa como estado inicial, recorrendo à sessão de fallback somente quando não há nada persistido.

Essa capacidade de retomada está implementada e coberta por testes de unidade com `InMemoryCheckoutSessionStorage`, mas ainda não faz parte da composição do aplicativo: `BenefitsHomePage._openPharmacyMode` continua criando o `CheckoutCubit` pelo construtor direto, sem informar nenhum `CheckoutSessionStorage`, então o app real ainda não persiste nem restaura sessões ao abrir o Modo Farmácia. Conectar `CheckoutCubit.restore` a uma instância de `DriftCheckoutSessionStorage` na composição, de forma que o app sobreviva a um reinício no meio do checkout, é um próximo passo pendente.

`CheckoutApiClient` encapsula uma instância de `Dio` configurada com `baseUrl` e timeouts de connect/send/receive, expondo só `post(path, data: ...)` e `get(path)` — nenhum consumidor externo enxerga `Dio` ou `Response` diretamente. `DioPrescriptionRepository`, `DioMedicationRepository` e `DioCheckoutRepository` implementam os três contratos de repositório contra os quatro endpoints REST (`POST /prescriptions/validate`, `GET /medications/{ean}/eligibility`, `POST /checkouts`, `GET /checkouts/{id}`), reconstruindo `CheckoutSession` completa a partir do corpo da resposta em `getById`, com todo campo (incluindo `status`) validado antes do uso. As falhas de rede são classificadas por `NetworkFailure`, uma `sealed class` com cinco variantes (`TimeoutFailure`, `ServerUnavailableFailure`, `ConnectivityFailure`, `PermanentFailure`, `UnknownFailure`) construída a partir de um `switch` exaustivo sobre `DioExceptionType` — sem `default`, para que uma futura variante adicionada pelo pacote `dio` force uma decisão explícita em vez de cair silenciosamente em `UnknownFailure`. Um `statusCode` de 5xx vira `ServerUnavailableFailure`, 4xx vira `PermanentFailure` com o código preservado.

Assim como a persistência com Drift, essa infraestrutura HTTP está implementada e testada isoladamente, contra um `HttpClientAdapter` fake (`FakeHttpClientAdapter`, compartilhado entre os três arquivos de teste), sem tocar rede real — mas também não está conectada à composição do aplicativo: `BenefitsHomePage._openPharmacyMode` continua usando `DemoPrescriptionRepository`, `DemoMedicationRepository` e `DemoCheckoutRepository`. Não há ainda retry automático por tipo de falha; a classificação existe, mas quem a consome hoje são só os testes.

`CheckoutSession.idempotencyKey`, gerado uma única vez por `CheckoutStateMachine` e preservado em retry, viaja até `DioCheckoutRepository.create`, que o envia como header HTTP `Idempotency-Key` — não como campo do corpo da requisição, seguindo a convenção usada por APIs de pagamento reais. `CheckoutApiClient.post` ganhou um parâmetro `headers` opcional para isso, sem alterar o formato de retorno (continua devolvendo `Map<String, dynamic>`, nunca o `Response` do Dio). `FakeHttpClientAdapter` passou a capturar os headers de cada requisição em `capturedHeaders`, permitindo a um teste afirmar que a mesma chave é enviada em requisições que representam a mesma tentativa lógica.

Depois que ao menos um medicamento foi lido, `Validar compra` submete a referência da receita por `CheckoutCubit.submitPrescription()`. A ação permanece indisponível fora de `collectingMedication` ou quando a sessão ainda não contém medicamentos, e a validação do formulário impede referências vazias. Nas etapas seguintes, a tela apresenta apenas o botão pertinente ao estado: `Verificar elegibilidade` em `checkingEligibility`, `Criar pagamento` em `creatingPayment` e `Confirmar pagamento` em `awaitingConfirmation` com identificador remoto disponível. Cada callback solicita a operação ao Cubit, que coordena o repositório correspondente e entrega o resultado à máquina de estados.

`DemoCheckoutRepository` mantém em memória o checkout criado e devolve `demo-checkout-001` como identificador determinístico. A confirmação consulta esse mesmo registro pela mesma instância do repositório e devolve um snapshot `paid`. O identificador isolado não recria o registro em memória; por isso a composição e os testes preservam a instância entre `createCheckout()` e `confirmPayment()`.

Quando a sessão chega a `paid`, o selector apresenta `Pagamento confirmado` e o `remoteCheckoutId` do checkout concluído. O título é uma região semântica dinâmica para que a mudança possa ser anunciada automaticamente pelas tecnologias assistivas. Como `paid` é terminal, as ações de avanço deixam de ser exibidas e a interface permanece coerente com a conclusão registrada no snapshot do Cubit.

`Navigator.push` adiciona uma `MaterialPageRoute<void>` à pilha para abrir `PharmacyModePage`. A seta criada automaticamente pela `AppBar` executa o retorno, remove essa rota e descarta seu objeto `State`. Como o `BlocProvider` pertence à composição dessa rota, o `CheckoutCubit` criado por ele também é encerrado. Ao abrir o fluxo novamente, outra sessão local é criada em `collectingMedication`, sem medicamentos.

O formulário agrupa dois `TextFormField`s. A referência da receita é obrigatória. O EAN também é obrigatório, aceita somente dígitos, limita a entrada a 13 caracteres e exige exatamente esse comprimento para concluir a leitura. O botão “Usar EAN de demonstração” preenche um valor sintético conhecido para exercitar o fluxo sem câmera ou código de barras real.

Quando `FormState.validate` rejeita a entrada, a sessão e a confirmação permanecem inalteradas. Em uma leitura válida, `scanMedication()` apenas solicita a inclusão à máquina de estados. O `listenWhen` compara as sessões anterior e atual e libera o `listener` somente quando a quantidade de medicamentos aumenta. Depois que esse novo snapshot confirma a inclusão, o EAN é limpo para o próximo medicamento, o foco é removido e um `SnackBar` apresenta a confirmação. A referência da receita permanece no formulário como contexto da mesma compra. Os dois `TextEditingController`s são descartados junto com o estado da página.

`selectCheckoutProgress` converte a `CheckoutSession` em um record `CheckoutProgressData` com `currentStep` e `label`. Coleta permanece na etapa 1; validação da receita e elegibilidade usam a etapa 2; criação do pagamento usa a etapa 3; confirmação pendente e pagamento concluído usam a etapa 4. Em `recoverableFailure`, o selector consulta `retryTargetStatus` para manter visível a etapa que deverá ser retomada. Como records possuem igualdade estrutural, o `BlocSelector` não reconstrói o indicador quando outra parte da sessão muda sem alterar esses dois valores.

Quatro marcadores oferecem a referência visual, enquanto o `LinearProgressIndicator` calcula a fração a partir da etapa selecionada. O componente visual continua recebendo parâmetros e permanece independente das regras que convertem estados do domínio em apresentação.

O conteúdo ocupa a largura disponível até o limite de 480 pixels lógicos. `SafeArea` respeita recortes e áreas de navegação do dispositivo, enquanto `SingleChildScrollView` oferece uma saída para alturas reduzidas. O comportamento foi validado em retrato e paisagem, inclusive com a fonte ampliada, sem overflow e com o contador e o botão alcançáveis.

Na camada de acessibilidade:

- o contador usa `Semantics` com rótulo estável, valor dinâmico e `liveRegion` para anunciar mudanças;
- `ExcludeSemantics` impede que o texto visual do contador seja anunciado em duplicidade;
- o indicador de progresso combina etapa, total e rótulo em um único nó `Semantics`, enquanto `ExcludeSemantics` evita anúncios duplicados de seus descendentes visuais;
- o título de pagamento confirmado usa `Semantics(liveRegion: true)` para anunciar a conclusão quando a sessão chega a `paid`;
- o tema define 48 por 48 pixels lógicos como tamanho mínimo dos botões elevados;
- o teste `accessibility_guidelines_test.dart` verifica alvo de toque Android, rótulos dos controles e contraste textual;
- `checkout_navigation_test.dart` verifica o estado inicial, a abertura do Modo Farmácia, o retorno e a recriação do contador;
- `medication_input_validation_test.dart` verifica formulário vazio, EAN incompleto, preenchimento demonstrativo e leitura válida sem apresentar erros;
- `medication_counter_cubit_test.dart` verifica o estado inicial do Cubit e, com `blocTest`, o estado emitido depois de uma leitura;
- `checkout_cubit_test.dart` cobre o estado inicial, leitura de medicamento, validação e rejeição da receita, elegibilidade, criação, confirmação, falhas técnicas recuperáveis, retry e preservação do checkout remoto;
- `checkout_ui_integration_test.dart` verifica que uma leitura válida atualiza `CheckoutSession.medications`, apresenta o contador derivado e que uma emissão direta do Cubit também dispara o `SnackBar` de confirmação;
- `checkout_progress_selector_test.dart` cobre os mapeamentos das etapas 2, 3 e 4, o contexto de uma falha recuperável e a apresentação da seleção na interface;
- `checkout_failure_feedback_test.dart` cobre o anúncio acessível de falhas, o retry recuperável e a ausência dessa ação em falhas permanentes;
- `checkout_submission_ui_test.dart` verifica a submissão da receita pela interface e a indisponibilidade da ação enquanto o fluxo está incompleto;
- `checkout_flow_actions_test.dart` verifica as ações de elegibilidade, criação do checkout remoto e confirmação do pagamento, incluindo as mudanças de etapa e a preservação do identificador remoto;
- `checkout_success_feedback_test.dart` verifica o título e o identificador do checkout concluído, a ausência da ação de confirmação e o anúncio semântico dinâmico do sucesso;
- `checkout_session_snapshot_test.dart` verifica a serialização para mapa, a reconstrução da sessão e o round-trip completo por JSON;
- `checkout_session_storage_test.dart` verifica armazenamento vazio, preservação do snapshot entre `save` e `load` e remoção dos dados por `clear`;
- `checkout_database_test.dart` verifica banco vazio, substituição do registro único e remoção do snapshot usando SQLite em memória;
- `drift_checkout_session_storage_test.dart` verifica o ciclo de `save`, `load` e `clear` pelo adapter Drift;
- `checkout_cubit_persistence_test.dart` verifica a restauração de uma sessão persistida via `CheckoutCubit.restore`, a persistência do snapshot após leitura de medicamento e validação de receita, e a consistência do storage com o estado em memória depois de um retry a partir de falha recuperável;
- `dio_prescription_repository_test.dart`, `dio_medication_repository_test.dart` e `dio_checkout_repository_test.dart` verificam cada repositório HTTP contra um `HttpClientAdapter` fake — resposta de sucesso, negativa de negócio, corpo malformado, para cada tipo de falha coberto por `NetworkFailure` que a exceção lançada tem o tipo específico esperado (`ServerUnavailableFailure`, `PermanentFailure`), não só `Exception` genérica, e que `create()` envia `idempotencyKey` como header `Idempotency-Key`;
- as verificações automatizadas complementam os testes manuais com tecnologias assistivas, sem substituí-los.

Os logs de `initState`, `build` e `dispose` permitem observar o ciclo de vida durante o aprendizado. Os registros manuais dos estados `0`, `1` e `2` também demonstram que as emissões reconstruíram `MedicationCounterContent` pelo `BlocConsumer`, enquanto `PharmacyModePage` não precisou ser reconstruída a cada mudança do contador. O hot reload preserva o objeto `State`, o hot restart recria a aplicação e a remoção da rota executa `dispose` no estado da página.

O fluxo em execução no app permanece local e sintético. Os repositórios demonstrativos (`Demo*`) continuam sendo o que `BenefitsHomePage` de fato compõe, permitindo exercitar `CheckoutCubit` sem infraestrutura externa. Duas peças de infraestrutura real já existem e estão testadas isoladamente, mas nenhuma delas participa da composição do app ainda: a persistência com Drift (`DriftCheckoutSessionStorage` + `CheckoutCubit.restore`) e os três repositórios HTTP com Dio (`DioPrescriptionRepository`, `DioMedicationRepository`, `DioCheckoutRepository`) com classificação de falhas por `NetworkFailure`. Não há `Idempotency-Key`, cache, migrações de esquema além da versão inicial, retry automático por tipo de falha, pagamento real ou integrações externas — isso e a conexão dessas duas peças ao app real serão introduzidos em aulas posteriores.

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

O resultado esperado é formatação limpa, análise estática sem problemas, 68 testes aprovados — incluindo acessibilidade, navegação, validação de entrada, Cubits, integração da sessão com a interface, efeito reativo de confirmação, progresso selecionado, feedback de falhas, feedback acessível de checkout concluído, submissão da receita, ações de avanço do checkout, o round-trip JSON do snapshot, o armazenamento assíncrono em memória, as operações do banco Drift, o adapter SQLite, a restauração/persistência de sessão pelo `CheckoutCubit`, os três repositórios HTTP com Dio, sua classificação de falhas e o envio da chave de idempotência — e somente alterações intencionais exibidas pelo Git. O Quality Gate completo do monorepo também executa os testes de fronteira do package `checkout_domain`, agora incluindo a geração e preservação da `idempotencyKey`.

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
- [`BlocSelector`](https://pub.dev/documentation/flutter_bloc/latest/flutter_bloc/BlocSelector-class.html)
- [`bloc_test`](https://pub.dev/packages/bloc_test)
- [Records em Dart](https://dart.dev/language/records)
- [`dart:convert`](https://api.dart.dev/dart-convert/)
- [`List.unmodifiable`](https://api.dart.dev/dart-core/List/List.unmodifiable.html)
- [Documentação do Drift](https://drift.simonbinder.eu/)
- [`drift_flutter`](https://pub.dev/packages/drift_flutter)
- [`dio`](https://pub.dev/packages/dio)
- [Records em Dart — pattern matching e `sealed class`](https://dart.dev/language/branches#exhaustiveness-checking)
