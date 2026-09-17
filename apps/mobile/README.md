# Mobile

Aplicativo Flutter Android principal do MediFlow Learning.

## Estado atual

Até a Aula 28, a aplicação passou a iniciar em uma tela de benefícios com saldo fictício e a navegar para o “Modo Farmácia”, que apresenta o progresso do checkout com identidade visual própria, responsividade e acessibilidade. A primeira etapa recebe uma referência de receita e um EAN fictícios, valida os dados e somente então permite simular a leitura do medicamento. `CheckoutCubit` é a fonte de verdade do fluxo em execução: ele mantém a `CheckoutSession`, coordena os contratos de repositório e delega as transições à máquina de estados do domínio. A confirmação visual é um efeito reativo da sessão atualizada, seletores derivados apresentam progresso e feedback contextual, e a interface oferece somente a ação compatível com a etapa atual até apresentar a conclusão acessível do pagamento demonstrativo. A camada `data` fornece a representação serializável da sessão completa, um contrato assíncrono de armazenamento e implementações substituíveis em memória e SQLite com Drift, sem acoplar o domínio a JSON ou persistência.

A composição atual separa estado, apresentação e design system:

- `main.dart` ficou restrito ao composition root: `main()` e `MainApp`. As telas vivem em `features/*/presentation/` desde a Aula 50;
- `MainApp` configura o `MaterialApp`, aplica o tema global e define `BenefitsHomePage` como tela inicial;
- `BenefitsHomePage` apresenta o saldo fictício, cria a sessão inicial e fornece `CheckoutCubit` ao Modo Farmácia com `BlocProvider`;
- `PharmacyModePage` permanece como `StatefulWidget` para coordenar recursos ligados ao ciclo de vida da rota;
- `_PharmacyModePageState` mantém a `GlobalKey<FormState>` e os controllers da receita e do EAN durante o ciclo de vida da rota, mas não armazena mais o contador;
- `CheckoutCubit` é o ViewModel: mantém `CheckoutSession` como campo **privado**, coordena os contratos de repositório, delega todas as transições para `CheckoutStateMachine` e emite `CheckoutViewState`;
- `CheckoutViewState` carrega decisões já tomadas (`canSubmit`, `canConfirmPayment`, `medicationLabel`, `feedback`) com igualdade de valor; `CheckoutViewState.fromSession` é o único ponto que conhece o domínio;
- `CheckoutFeedback` é uma hierarquia selada — `NoFeedback`, `SuccessFeedback`, `RecoverableFailure`, `PermanentFailure` — renderizada por `switch` exaustivo;
- `CheckoutSessionSnapshot` converte a sessão entre o domínio e uma representação formada por mapas, listas e valores compatíveis com JSON;
- `CheckoutSessionStorage` define as operações assíncronas `save`, `load` e `clear`; `InMemoryCheckoutSessionStorage` e `DriftCheckoutSessionStorage` oferecem implementações substituíveis;
- `CheckoutDatabase` concentra o schema Drift e permite abrir SQLite em memória nos testes ou `mediflow_checkout.sqlite` no dispositivo;
- `DemoPrescriptionRepository`, `DemoMedicationRepository` e `DemoCheckoutRepository` fornecem respostas locais e determinísticas aos contratos exigidos pelo Cubit;
- `BlocConsumer<CheckoutCubit, CheckoutViewState>` observa as emissões, reconstrói a região de conteúdo e executa efeitos pontuais da interface;
- um `BlocSelector` seleciona somente a etapa, o total e o rótulo usados pelo indicador de progresso;
- um segundo `BlocSelector` observa somente o `feedback`, que é um objeto único com igualdade de valor;
- `MedicationCounterContent` continua como `StatelessWidget` e recebe do `builder` o rótulo e a contagem já prontos, os callbacks disponíveis para a etapa atual, os controllers e a chave do formulário;
- `CheckoutProgressIndicator` recebe do selector a etapa atual e o rótulo, além do total fixo de quatro etapas, para apresentar o progresso do checkout;
- `AppTheme` centraliza o `ThemeData`, o Material 3 e o `ColorScheme` do aplicativo;
- `AppSpacing` oferece uma escala compartilhada de espaçamentos;
- `MediFlowContentCard` encapsula largura máxima, margem, padding e rolagem vertical.

O contador não possui mais estado independente no fluxo em execução. A ação de leitura entrega o EAN digitado ao `CheckoutCubit` com `context.read<CheckoutCubit>()`; quem constrói o `Medication` é o ViewModel, porque a View não importa mais `checkout_domain`. `scanMedication` envia `MedicationScanned` à `CheckoutStateMachine`, que produz outro snapshot da sessão ainda em `collectingMedication`. Quando `emit()` publica o estado de visão derivado dessa sessão, o `builder` do `BlocConsumer` entrega o rótulo e a contagem já prontos a `MedicationCounterContent`. O `listener` reage à mesma emissão para executar os efeitos que não pertencem à árvore declarativa. Os widgets visuais recuperam cores e tipografia do tema mais próximo com `Theme.of(context)`, sem depender diretamente de valores de marca espalhados pela interface.

O `CheckoutCubit` atua como camada de coordenação entre o aplicativo e o domínio. Ele consulta os repositórios, converte resultados esperados do negócio em eventos de falha permanente, transforma falhas técnicas de criação e confirmação em falhas recuperáveis e delega a evolução da sessão à `CheckoutStateMachine`. A etapa interrompida e o identificador remoto são preservados para permitir retry sem recriar o pagamento. Depois de cada operação assíncrona, o Cubit verifica `isClosed` antes de emitir outro estado.

`CheckoutSessionSnapshot` pertence à camada `data` porque descreve o formato de transporte e futura persistência da sessão, enquanto `CheckoutSession` permanece como modelo de domínio independente desses detalhes. `fromDomain` e `toDomain` atravessam a fronteira com o domínio; `toMap` e `fromMap` atravessam a fronteira serializável. O mapa preserva saldo, receita, medicamentos, status, identificador remoto, etapa de retry e mensagem contextual. A lista recebida pelo snapshot é copiada com `List.unmodifiable`, impedindo alterações estruturais posteriores. Os estados são gravados pelos nomes do enum e reconstruídos com `byName`; portanto, uma futura renomeação exigirá versionamento ou migração dos dados já armazenados.

O teste de round-trip passa a sessão por `Map`, `jsonEncode`, `jsonDecode` e novamente pelo snapshot antes de reconstruir o domínio. Esse teste comprova que os valores usados atualmente são compatíveis com JSON e preservam o contexto completo da sessão, mas ainda não representa escrita em disco, banco de dados, tratamento de mapas corrompidos ou migração entre versões do esquema.

`CheckoutSessionStorage` separa o aplicativo da tecnologia que armazenará o snapshot. O contrato é assíncrono desde a primeira implementação para que consumidores possam receber futuramente uma versão baseada em I/O sem mudar sua própria API. `InMemoryCheckoutSessionStorage` guarda o mapa produzido por `toMap`, devolve outro snapshot reconstruído por `fromMap` e usa `null` para representar tanto o armazenamento inicial vazio quanto o estado posterior a `clear`. Como essa implementação vive somente na memória do processo, ela não restaura a sessão depois que o aplicativo é encerrado.

`CheckoutDatabase` introduz o schema SQLite com Drift. A tabela `CheckoutSessionRecords` possui um registro único identificado por `id = 1` e armazena o snapshot completo na coluna textual `payload`. `insertOnConflictUpdate` cria o registro inicial ou substitui o snapshot anterior, mantendo somente o estado mais recente.

Na Aula 25, o schema evoluiu para a versão 2 com a tabela `OutboxEvents` (`idempotencyKey` como chave primária, `operationType`, `payload` e `createdAt` com valor padrão) — a primeira migração estrutural real do projeto. `MigrationStrategy.onCreate` cria as duas tabelas para um banco novo; `onUpgrade` detecta quem ainda está na versão 1 e só adiciona `OutboxEvents`, sem tocar em `CheckoutSessionRecords`. `enqueueOutboxEvent` grava (ou atualiza, via `insertOnConflictUpdate`, se a mesma `idempotencyKey` for reenfileirada) um evento pendente; `readPendingOutboxEvents` lista tudo que ainda não foi confirmado; `removeOutboxEvent` apaga pela chave primária.

`OutboxCheckoutRepository implements CheckoutRepository` decora qualquer outra implementação (tipicamente `DioCheckoutRepository`) sem que `CheckoutCubit` precise saber que o outbox existe: antes de delegar `create()` ao repositório interno, enfileira um evento com a `idempotencyKey` da sessão; se a chamada suceder, remove o evento; se falhar, deixa o evento no outbox e relança o erro original, para o Cubit continuar tratando como já trata. `getById` só repassa para o repositório interno — o outbox modela a intenção de criar um checkout, não a consulta de um já existente.

`DriftCheckoutSessionStorage` implementa o contrato convertendo `CheckoutSessionSnapshot` em mapa e JSON antes da escrita e realizando o caminho inverso durante a leitura. `CheckoutDatabase(super.executor)` preserva a injeção de SQLite em memória nos testes, enquanto `CheckoutDatabase.defaults()` usa `driftDatabase` para abrir ou criar `mediflow_checkout.sqlite` no armazenamento do aplicativo.

`CheckoutCubit` passou a aceitar um `CheckoutSessionStorage?` opcional. Quando presente, `_emitPersisted` substitui todas as chamadas diretas a `emit` — inclusive dentro de `submitPrescription`, `checkEligibility`, `createCheckout`, `confirmPayment` e `retry` — encadeando a emissão do novo estado com `storage.save(CheckoutSessionSnapshot.fromDomain(session))`. Um teste de TDD identificou que `retry()` havia ficado de fora dessa migração: como a transição de retry é puramente local (`CheckoutStateMachine` apenas devolve o `retryTargetStatus` salvo, sem repetir a chamada de rede), era fácil esquecer que ela também precisa atualizar o storage. Sem isso, um snapshot de `recoverableFailure` permanecia persistido mesmo depois do retry mover o estado em memória adiante, e um reinício do app nesse intervalo restauraria a falha antiga em vez do estado retomado. O construtor nomeado `CheckoutCubit.restore` encapsula a leitura inicial: carrega o snapshot mais recente do storage informado e o usa como estado inicial, recorrendo à sessão de fallback somente quando não há nada persistido.

Essa capacidade de retomada está implementada e coberta por testes de unidade com `InMemoryCheckoutSessionStorage`, e agora também conectada na composição real do aplicativo: `main()` cria uma única instância de `CheckoutDatabase.defaults()`, passada por construtor até `BenefitsHomePage`. `_openPharmacyMode` monta um `DriftCheckoutSessionStorage(database)` e chama `CheckoutCubit.restore(...)` — assíncrono, então a rota usa `FutureBuilder<CheckoutCubit>` (com a `Future` calculada uma única vez fora do `builder` da rota, para não repetir a leitura do storage a cada rebuild) e `BlocProvider.value` em vez de `BlocProvider(create: ...)`. Na prática, isso significa que sair do Modo Farmácia sem finalizar a compra e reabri-lo **retoma** a sessão anterior (medicamentos já lidos incluídos) em vez de começar do zero — comportamento verificado em `checkout_navigation_test.dart`.

`OutboxCheckoutRepository` também está conectado: `main()` decora uma única instância de `DemoCheckoutRepository` com ele (`OutboxCheckoutRepository(inner: demoCheckoutRepository, database: database)`) e repassa essa mesma instância decorada até `_openPharmacyMode` — não uma nova a cada abertura do Modo Farmácia, para que a rotina de reenvio e o uso normal do app compartilhem o mesmo `DemoCheckoutRepository` (que guarda o checkout criado em memória; duas instâncias separadas seriam dois "backends" fictícios desconectados entre si).

`OutboxSynchronizer` fecha o ciclo que faltava: `drain()` lê `readPendingOutboxEvents`, filtra por `operationType`, reconstrói cada `CheckoutSession` a partir do `payload` persistido (`CheckoutSessionSnapshot.fromMap` + `.toDomain()`) e chama `checkoutRepository.create(session)` de novo — como reaproveita o próprio `OutboxCheckoutRepository`, o reenfileiramento (idempotente, mesma chave) e a remoção em sucesso acontecem automaticamente, sem lógica duplicada. Uma falha em um evento (de rede ou de dado corrompido — por isso um `catch` amplo, não só `on Exception`) não interrompe o processamento dos demais. `main()` chama `await synchronizer.drain()` antes de `runApp`, então toda inicialização do app tenta reenviar o que ficou pendente da sessão anterior.

`CheckoutApiClient` encapsula uma instância de `Dio` configurada com `baseUrl` e timeouts de connect/send/receive, expondo só `post(path, data: ...)` e `get(path)` — nenhum consumidor externo enxerga `Dio` ou `Response` diretamente. `DioPrescriptionRepository`, `DioMedicationRepository` e `DioCheckoutRepository` implementam os três contratos de repositório contra os quatro endpoints REST (`POST /prescriptions/validate`, `GET /medications/{ean}/eligibility`, `POST /checkouts`, `GET /checkouts/{id}`), reconstruindo `CheckoutSession` completa a partir do corpo da resposta em `getById`, com todo campo (incluindo `status`) validado antes do uso. As falhas de rede são classificadas por `NetworkFailure`, uma `sealed class` com cinco variantes (`TimeoutFailure`, `ServerUnavailableFailure`, `ConnectivityFailure`, `PermanentFailure`, `UnknownFailure`) construída a partir de um `switch` exaustivo sobre `DioExceptionType` — sem `default`, para que uma futura variante adicionada pelo pacote `dio` force uma decisão explícita em vez de cair silenciosamente em `UnknownFailure`. Um `statusCode` de 5xx vira `ServerUnavailableFailure`, 4xx vira `PermanentFailure` com o código preservado.

Essa infraestrutura HTTP é testada isoladamente contra um `HttpClientAdapter` fake (`FakeHttpClientAdapter`, compartilhado entre os três arquivos de teste), sem tocar rede real, e **desde a Aula 34 está na composição do aplicativo**: `main()` monta os três `Dio*Repository` sobre as Cloud Functions em `functions/`. Os repositórios de demonstração continuam existindo, mas agora servem só aos testes de widget. Não há ainda retry automático por tipo de falha; a classificação de `NetworkFailure` existe e é consumida pelo Cubit para distinguir falha recuperável de permanente, mas nada tenta de novo sozinho a não ser o outbox, na inicialização.

`CheckoutSession.idempotencyKey`, gerado uma única vez por `CheckoutStateMachine` e preservado em retry, viaja até `DioCheckoutRepository.create`, que o envia como header HTTP `Idempotency-Key` — não como campo do corpo da requisição, seguindo a convenção usada por APIs de pagamento reais. `CheckoutApiClient.post` ganhou um parâmetro `headers` opcional para isso, sem alterar o formato de retorno (continua devolvendo `Map<String, dynamic>`, nunca o `Response` do Dio). `FakeHttpClientAdapter` passou a capturar os headers de cada requisição em `capturedHeaders`, permitindo a um teste afirmar que a mesma chave é enviada em requisições que representam a mesma tentativa lógica.

Depois que ao menos um medicamento foi lido, `Validar compra` submete a referência da receita por `CheckoutCubit.submitPrescription()`. A ação permanece indisponível fora de `collectingMedication` ou quando a sessão ainda não contém medicamentos, e a validação do formulário impede referências vazias. Nas etapas seguintes, a tela apresenta apenas o botão pertinente ao estado: `Verificar elegibilidade` em `checkingEligibility`, `Criar pagamento` em `creatingPayment` e `Confirmar pagamento` em `awaitingConfirmation` com identificador remoto disponível. Cada callback solicita a operação ao Cubit, que coordena o repositório correspondente e entrega o resultado à máquina de estados.

`DemoCheckoutRepository` mantém em memória o checkout criado e devolve `demo-checkout-001` como identificador determinístico. A confirmação consulta esse mesmo registro pela mesma instância do repositório e devolve um snapshot `paid`. O identificador isolado não recria o registro em memória; por isso a composição e os testes preservam a instância entre `createCheckout()` e `confirmPayment()`.

Quando a sessão chega a `paid`, o selector apresenta `Pagamento confirmado` e o `remoteCheckoutId` do checkout concluído. O título é uma região semântica dinâmica para que a mudança possa ser anunciada automaticamente pelas tecnologias assistivas. Como `paid` é terminal, as ações de avanço deixam de ser exibidas e a interface permanece coerente com a conclusão registrada no snapshot do Cubit.

`Navigator.push` adiciona uma `MaterialPageRoute<void>` à pilha para abrir `PharmacyModePage`. A seta criada automaticamente pela `AppBar` executa o retorno, remove essa rota e descarta seu objeto `State`. Como o `BlocProvider` pertence à composição dessa rota, o `CheckoutCubit` criado por ele também é encerrado — mas a sessão que ele mantinha já foi persistida a cada emissão, então abrir o fluxo novamente restaura essa sessão via `CheckoutCubit.restore` em vez de começar do zero. Só uma sessão nunca antes persistida (`readCheckoutSession` retornando `null`) recorre à sessão de fallback em `collectingMedication`, sem medicamentos.

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
- `checkout_navigation_test.dart` verifica o estado inicial, a abertura do Modo Farmácia, o retorno e a retomada do contador ao reabrir (a sessão persistida é restaurada, não recriada do zero);
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
- `checkout_database_test.dart` verifica banco vazio, substituição do registro único e remoção do snapshot usando SQLite em memória, além do ciclo do outbox (começa vazio, enfileira e lê, atualiza um evento reenfileirado com a mesma `idempotencyKey`, remove após confirmação);
- `outbox_checkout_repository_test.dart` verifica que uma criação bem-sucedida remove o evento do outbox, que uma falha o mantém (com a `idempotencyKey` certa), e que uma sessão sem `idempotencyKey` é rejeitada antes de qualquer chamada ao repositório interno;
- `outbox_synchronizer_test.dart` verifica que um evento de tipo desconhecido é ignorado, que um evento pendente é reenviado e removido em sucesso, que permanece no outbox quando o reenvio falha, e que a falha de um evento não impede o processamento dos demais;
- `resilience_test.dart` verifica o cenário crítico completo — resposta perdida, reinício simulado, reenvio — confirmando que o checkout é confirmado sem duplicidade;
- `drift_checkout_session_storage_test.dart` verifica o ciclo de `save`, `load` e `clear` pelo adapter Drift;
- `checkout_cubit_persistence_test.dart` verifica a restauração de uma sessão persistida via `CheckoutCubit.restore`, a persistência do snapshot após leitura de medicamento e validação de receita, e a consistência do storage com o estado em memória depois de um retry a partir de falha recuperável;
- `dio_prescription_repository_test.dart`, `dio_medication_repository_test.dart` e `dio_checkout_repository_test.dart` verificam cada repositório HTTP contra um `HttpClientAdapter` fake — resposta de sucesso, negativa de negócio, corpo malformado, para cada tipo de falha coberto por `NetworkFailure` que a exceção lançada tem o tipo específico esperado (`ServerUnavailableFailure`, `PermanentFailure`), não só `Exception` genérica, e que `create()` envia `idempotencyKey` como header `Idempotency-Key`;
- `maintenance_mode_test.dart` verifica que `maintenanceMode: true` exibe a mensagem configurada e desabilita o botão do Modo Farmácia sem permitir a navegação, e que `StaticOperationalSettings()` padrão mantém o botão habilitado, a navegação funcionando e a mensagem ausente;
- as verificações automatizadas complementam os testes manuais com tecnologias assistivas, sem substituí-los.

Os logs de `initState`, `build` e `dispose` permitem observar o ciclo de vida durante o aprendizado. Os registros manuais dos estados `0`, `1` e `2` também demonstram que as emissões reconstruíram `MedicationCounterContent` pelo `BlocConsumer`, enquanto `PharmacyModePage` não precisou ser reconstruída a cada mudança do contador. O hot reload preserva o objeto `State`, o hot restart recria a aplicação e a remoção da rota executa `dispose` no estado da página.

O fluxo em execução no app permanece sintético, mas a persistência que o sustenta não é mais só teórica. `BenefitsHomePage` compõe `CheckoutCubit.restore` com `DriftCheckoutSessionStorage` (SQLite real, via `CheckoutDatabase.defaults()`) e `OutboxCheckoutRepository` real — a sessão sobrevive a sair e reabrir o Modo Farmácia, toda criação de checkout passa pelo ciclo de outbox, e `main()` reenvia eventos pendentes via `OutboxSynchronizer` antes mesmo do primeiro frame do app. Desde a Aula 34 nada mais é fake nesse caminho: `DioPrescriptionRepository`, `DioMedicationRepository` e `DioCheckoutRepository` substituíram os repositórios de demonstração na composição, e conversam com as Cloud Functions construídas na Aula 33. Também não há cache nem retry automático por tipo de falha — isso continua para aulas posteriores.

`resilience_test.dart` comprova o cenário crítico de ponta a ponta: um `ResilientFakeCheckoutServer` (fake de teste, não parte do app) deduplica por `idempotencyKey` e conta quantas vezes processou uma criação de verdade, independente de a resposta ter chegado ao cliente. O teste cria um checkout com a resposta programada para se perder (`dropNextResponse = true`), confirma que a exceção chega ao chamador enquanto o servidor já processou (`creationCount == 1`) e o evento permanece no outbox, simula o reinício do app com novas instâncias de `OutboxCheckoutRepository`/`OutboxSynchronizer` sobre o mesmo `CheckoutDatabase`, e confirma que o reenvio conclui sem criar um segundo checkout (`creationCount` continua `1`) e sem deixar nada pendente no outbox — a garantia que a Aula 23 (idempotência), a Aula 25 (outbox) e o reenvio construído nesta sessão prometiam, agora provada junta.

Na Aula 29, o app passou a inicializar o Firebase de verdade — um projeto de demonstração (`mediflow-learning`, sem dados reais), configurado via FlutterFire CLI (`flutterfire configure --project=mediflow-learning`), que gerou `lib/firebase_options.dart`, `android/app/google-services.json` e `firebase.json`, além de aplicar o plugin `com.google.gms.google-services` nos arquivos Gradle. `main()` chama `WidgetsFlutterBinding.ensureInitialized()` antes de `await Firebase.initializeApp(...)` — o binding é a ponte entre o Dart e os platform channels que o SDK nativo do Firebase usa, então precisa existir primeiro. Em seguida, o app autentica anonimamente (`FirebaseAuth.instance.signInAnonymously()`, só quando `currentUser` ainda é `null`, evitando uma chamada de rede redundante em toda abertura já que o Firebase Auth persiste a sessão anônima no dispositivo). Uma falha nesse login é capturada especificamente por `on FirebaseAuthException` — registrada, não silenciada — e o app segue a inicialização mesmo assim, consistente com a filosofia de resiliência das aulas anteriores: a ausência de um usuário autenticado não deveria impedir o uso do que não depende de identidade. Nenhum dado do Firebase (`apiKey` incluída) é segredo — a proteção de um projeto Firebase vem das Security Rules e do App Check, não de esconder esses valores, por isso os arquivos de configuração gerados são versionados normalmente.

Na Aula 30, `CheckoutAnalyticsObserver` (um `BlocObserver` do `flutter_bloc`, registrado globalmente via `Bloc.observer =` em `main()`) passou a observar toda emissão de `CheckoutCubit` sem que o Cubit precise saber que Analytics existe. `onChange` compara `change.currentState.status` (o estado antes da mudança, apesar do nome) com `change.nextState.status` (o estado depois) e só dispara `FirebaseAnalytics.logEvent(name: 'checkout_step', parameters: {'step': ...})` quando a etapa realmente muda — escanear um segundo medicamento na mesma etapa não gera um evento novo. O parâmetro do evento é só o nome do enum (`CheckoutStatus.name`); nenhum `id` de sessão, EAN de medicamento ou referência de receita é enviado ao Analytics. `onError` encaminha qualquer exceção lançada por um `CheckoutCubit` para `FirebaseCrashlytics.instance.recordError(..., fatal: false)` — reportado como não fatal, já que o app trata e segue adiante, não trava. O funil (5 eventos `checkout_step`, um por transição de `collectingMedication` até `paid`) foi confirmado no DebugView do console contra o app rodando de verdade; a parte do Crashlytics não foi forçada manualmente — é uma chamada única e direta à API do SDK, de baixo risco, e só será exercitada de fato quando (se) um erro real acontecer em produção.

Na Aula 31, três decorators de repositório (`PerformanceTracingPrescriptionRepository`, `PerformanceTracingMedicationRepository`, `PerformanceTracingCheckoutRepository`) passaram a medir a duração de `validate`, `checkEligibility` e `create` com `FirebasePerformance.newTrace(...)`/`.start()`/`.stop()` — seguindo o mesmo padrão de decorator que `OutboxCheckoutRepository` já usava, não uma instrumentação dentro do `CheckoutCubit`. `PerformanceTracingCheckoutRepository` decora o `OutboxCheckoutRepository` (não o repositório fake por baixo dele), então o trace mede a operação inteira — enfileirar, tentar a rede, confirmar — do ponto de vista de quem está esperando, não só a chamada de rede isolada; `getById` só repassa, sem trace, já que o roteiro pede trace só para a criação. `trace.stop()` roda dentro de um `finally`, garantindo que ele pare mesmo quando a chamada decorada lança uma exceção. Em `main()`, `MainApp`/`BenefitsHomePage` recebem `prescriptionRepository`/`medicationRepository`/`checkoutRepository` tipados pelas interfaces do domínio (`PrescriptionRepository`, `MedicationRepository`, `CheckoutRepository`), não pelos decorators concretos — decisão necessária, não só estilística: os decorators de performance chamam `FirebasePerformance.instance` na construção, que lança `[core/no-app]` se `Firebase.initializeApp()` nunca rodou (como acontece nos testes de widget, que constroem `MainApp` direto via `pumpWidget`, sem passar por `main()`); tipar os campos pela interface permite que os testes continuem passando os repositórios fake simples, sem tocar em Firebase Performance. Diferente do Analytics, o Performance Monitoring não tem uma visualização em tempo real equivalente ao DebugView — os primeiros traces podem demorar horas para aparecer no console, então essa peça foi validada por revisão de código, não por observação ao vivo.

Na Aula 32, uma interface pura em `lib/config/operational_settings.dart` (`OperationalSettings`, sem nenhum import de Firebase) desacopla o app de qualquer fonte concreta de configuração operacional: `maintenanceMode`, `maintenanceMessage` e `checkoutTimeout`. `StaticOperationalSettings` implementa esse contrato com valores `const` opcionais, cujos defaults (`maintenanceMode: false`, a mensagem padrão e `checkoutTimeout: Duration(milliseconds: 8000)`) são a mesma fonte de verdade usada depois como fallback do Remote Config — evitando dois lugares divergentes definindo "o que fazer quando não há configuração nenhuma". `BenefitsHomePage` recebe `settings: OperationalSettings` por construtor: quando `maintenanceMode` é `true`, exibe `maintenanceMessage` acima do botão e desabilita `Iniciar Modo Farmácia` (`onPressed: null`, a forma nativa do Flutter de desabilitar um `ElevatedButton`); quando é `false`, o fluxo normal permanece intacto. `RemoteConfigOperationalSettings implements OperationalSettings`, em `lib/config/remote_config_operational_settings.dart`, é a implementação real: seu `load()` estático chama `setConfigSettings` (intervalo mínimo de fetch zero só em `kDebugMode`, 12 horas em produção — o padrão recomendado pela documentação oficial), depois `setDefaults` com os mesmos três valores de `StaticOperationalSettings`, e só então tenta `fetchAndActivate()` dentro de um `try`/`on FirebaseException` que registra a falha sem relançá-la. Essa ordem é o que garante que o app nunca fique bloqueado esperando rede: os defaults já estão aplicados antes de qualquer tentativa de fetch, e uma falha de conectividade (verificada manualmente em modo avião, inclusive após `pm clear` para eliminar qualquer cache de fetch anterior) deixa o app operando exatamente como se a configuração remota nunca tivesse existido. `checkout_timeout_ms` era exposto pela interface sem ninguém consumi-lo, e passou a alimentar os timeouts do `CheckoutApiClient` na Aula 34. Uma mudança de `maintenance_mode` ou `maintenance_message` publicada no console Firebase só é refletida no próximo início do app (`fetchAndActivate`, não um listener de atualização em tempo real) — comportamento documentado, não uma limitação a ser corrigida nesta aula.

Na Aula 34, o aplicativo passou a falar com um backend de verdade. `CheckoutApiClient` deixou de embutir um `baseUrl` fictício e ganhou dois construtores de responsabilidade única: o principal recebe `baseUrl` e `timeout` e monta o `Dio` de produção; `CheckoutApiClient.withDio` recebe um `Dio` pronto e serve aos testes. O getter que expunha o `Dio` interno foi removido — com ele, qualquer consumidor poderia contornar a tradução de `DioException` em `NetworkFailure`, e uma fronteira que pode ser contornada não é uma fronteira.

A URL vem de `String.fromEnvironment('CHECKOUT_API_BASE_URL')`, avaliada em tempo de compilação e informada por `--dart-define`. Ela não pode vir do Remote Config, que seria a escolha aparentemente natural depois da Aula 32: o Remote Config precisa de rede para responder, e é justamente o endereço de rede que estaríamos tentando descobrir. Quando a variável não é informada, `main()` lança um `StateError` como primeira instrução, antes de qualquer inicialização, com a mensagem contendo o comando exato a executar. É deliberadamente um `Error` e não uma `Exception`, pela convenção do Dart: configuração ausente é defeito de build, não condição de runtime da qual alguém deva se recuperar. Também não é um `assert`, que seria removido do build de release — exatamente onde a proteção mais importa. Um valor padrão apontando para o emulador foi descartado pelo mesmo motivo: uma URL de desenvolvimento embutida no código não incomoda ninguém até o dia em que chega à produção despercebida.

A composição do checkout ficou com três camadas, e a ordem é significativa: `PerformanceTracingCheckoutRepository` envolve `OutboxCheckoutRepository`, que envolve `DioCheckoutRepository`. O outbox precisa ficar **por dentro** do trace, para que a medição cubra a operação inteira do ponto de vista de quem espera, e **por fora** do Dio, porque o evento só pode ser removido da fila depois que a chamada de rede confirmar. Uma versão intermediária desta aula chegou a ligar o trace direto ao Dio, deixando o outbox fora do caminho do app e ainda apontando para o repositório de demonstração — o app pararia de registrar intenções antes de tentar, e o `drain()` da inicialização "confirmaria" eventos reais contra um objeto em memória, descartando-os sem nunca contatar o backend. Nenhum teste pegaria isso, porque nada cobre a composição do `main()`.

No Android, duas particularidades foram necessárias. O emulador enxerga a máquina hospedeira em `10.0.2.2`, não em `localhost`, que dentro dele se refere ao próprio dispositivo. E o sistema bloqueia tráfego sem TLS desde a API 28, então `android:usesCleartextTraffic="true"` foi adicionado ao `android/app/src/debug/AndroidManifest.xml` — apenas no manifesto de depuração, para que a build de release continue recusando HTTP puro.

A validação foi feita com o app rodando contra os emuladores de Functions e Firestore. O fluxo completo produziu quatro requisições e um documento no Firestore cujo identificador é a `idempotencyKey` gerada pela máquina de estados. Em seguida, o backend foi derrubado entre a confirmação de elegibilidade e a criação do pagamento: a sessão foi para `recoverableFailure` com `retryTargetStatus` preservado, e o evento permaneceu no outbox. Com o backend de volta, o `OutboxSynchronizer` reenviou sozinho na inicialização seguinte, sem intervenção. Uma retentativa manual posterior, com a mesma chave, devolveu o checkout existente em vez de criar outro — o Firestore terminou com exatamente um documento. É o ciclo das Aulas 23 a 27 demonstrado no aplicativo real, e não mais só em teste.

Na Aula 35, as rotas do backend passaram a exigir identidade, e o aplicativo passou a enviá-la. O aplicativo autentica anonimamente desde a Aula 29, mas nunca usava esse token para nada.

A decisão de desenho está em **onde** o token é obtido. A solução ingênua seria capturá-lo ao montar a requisição, ou pior, ao enfileirar o evento no outbox. Isso criaria uma bomba-relógio: tokens do Firebase expiram em uma hora, e o outbox existe precisamente para reenviar horas depois, então um evento carregaria um token morto e seria rejeitado com `401` para sempre. Por isso `CheckoutApiClient` recebe um `AuthTokenProvider` — uma função `Future<String?> Function()` — e a chama **dentro de um interceptor do Dio, no instante de cada requisição**. O evento persistido guarda a intenção, nunca a credencial.

Injetar uma função em vez de importar `firebase_auth` no cliente HTTP também mantém a camada de rede ignorante sobre quem provê identidade, e permite que os testes forneçam um token fixo sem inicializar Firebase — o mesmo problema que os decorators de performance causaram na Aula 31. Quando o provedor devolve `null`, nenhum header é enviado: a requisição sai mesmo assim e o servidor recusa com `401`. Quem decide é o servidor, não o cliente deixando de tentar.

Um detalhe da API vale conhecer: `CheckoutApiClient.withDio` **adiciona** um interceptor ao `Dio` recebido. Criar dois clientes sobre a mesma instância empilha interceptors em vez de substituí-los, e o primeiro continua injetando seu header — foi assim que um teste de token ausente passou a receber o token do teste anterior.

Na Aula 36, o aplicativo passou a se recuperar sozinho quando a credencial deixa de valer. O `onError` do interceptor trata `401` como sinal de que a identidade precisa ser renovada: pede uma credencial nova ao `AuthTokenProvider`, agora com o parâmetro `forceRefresh`, refaz a requisição uma única vez e entrega o resultado ao chamador como se a primeira tentativa tivesse funcionado. Qualquer outro erro passa direto, sem renovação — renovar credencial por causa de um `500` seria desperdício e mascararia o problema real.

A trava contra laço infinito fica em `RequestOptions.extra`, que viaja junto com a requisição: uma retentativa que também receba `401` é repassada adiante em vez de disparar outra. O `onRequest` reconhece essa marcação e não reescreve o header, porque `_dio.fetch` percorre a cadeia de interceptors de novo e, sem essa checagem, o token velho sobrescreveria o renovado. Os dois handlers estavam corretos isoladamente e errados juntos — um efeito que só apareceu quando o teste da retentativa passou a comparar os tokens das duas tentativas.

A política de renovação vive no `main()`, e a validação contra os emuladores derrubou duas premissas antes de ela funcionar. A primeira era que `getIdToken(true)` falharia para um usuário excluído, revelando identidade inválida; ele devolveu um token normalmente. A segunda, mais sutil, é que `signInAnonymously()` **devolve o usuário anônimo já autenticado em vez de criar outro** — comportamento documentado que fazia a renovação retornar exatamente a credencial recusada. O `signOut()` antes do login é o que torna a recuperação real, e está comentado no código como obrigatório justamente por parecer supérfluo. O relato completo está no ADR 0001.

Na Aula 37, a política de identidade saiu de dentro do `main()` e ganhou endereço próprio em `lib/config/firebase_auth_token_provider.dart`. O `FirebaseAuth` chega por construtor, e não por `FirebaseAuth.instance` interno — é isso que permite ao teste apontar a classe para o emulador em vez de depender do estado global configurado na inicialização. A classe expõe um método nomeado `token`, passado por tear-off (`FirebaseAuthTokenProvider(FirebaseAuth.instance).token`), em vez de um `call` que a tornaria invocável: no teste, `provider.token(forceRefresh: true)` se lê sozinho, enquanto `provider(...)` obrigaria quem lê a saber que existe um `call` escondido.

O motivo da extração é um teste que os 87 anteriores não conseguiam escrever. Toda a suíte ficou verde durante a Aula 36 enquanto a correção **não funcionava**, porque nenhum teste tocava o Firebase de verdade — todos usavam um provedor falso que, por construção, devolvia uma credencial nova quando solicitado. `integration_test/identity_recovery_test.dart` autentica anonimamente contra o emulador de Authentication, guarda o `uid`, apaga as contas pela API do emulador, pede renovação e exige que o `uid` resultante seja **diferente**.

A invalidação precisa vir de fora do SDK, e a escolha do endpoint importa mais do que parece. `accounts:delete` responde `HTTP 200` **sem apagar nada** — um teste construído sobre ele passaria em todas as etapas sem ter invalidado identidade alguma, e passaria também contra a versão errada do código. `accounts:batchDelete` recusa contas ativas. O que funciona é `DELETE /emulator/v1/projects/{projectId}/accounts`, específico do emulador, o que também elimina o risco de alguém apontá-lo para produção. O endereço usado é `10.0.2.2`, porque o teste roda no dispositivo e o emulador está na máquina hospedeira.

O valor do teste foi verificado por experimento, não por raciocínio: removendo o `signOut()` do provedor, ele falha com `Expected: not '<uid>' / Actual: '<uid>'`; restaurando, volta a passar. Ele distingue a versão certa da errada, que é a única propriedade que torna um teste útil.

Na Aula 41, esse mesmo teste revelou-se falho pelo lado do oráculo. Ele lia o `uid` anterior das claims do ID token, e as claims do Firebase não têm chave `uid` — o identificador aparece como `user_id` e `sub`. O valor lido era `null`, e a asserção final comparava uma `String` contra `null`: passaria com a recuperação completamente quebrada. O `uid` passou a ser lido direto de `currentUser`, e a verificação por quebra dirigida foi refeita.

### A costura de autenticação, e o segundo gatilho da recuperação (Aula 41)

O primeiro deploy real, na Aula 40, expôs um modo de falha que sete aulas de emulador esconderam: com uma credencial emitida pelo emulador em cache e o Firebase real do outro lado, `getIdToken()` lança **antes** de qualquer requisição sair. Sem requisição não há resposta, sem resposta não há `401`, e a recuperação da Aula 36 — acionada exclusivamente por esse status — nunca disparava. Falha silenciosa, permanente e sem registro no servidor.

A correção tem duas partes. A primeira é uma costura: `lib/config/auth_gateway.dart` declara `AuthGateway`, que na época tinha três operações falando apenas `String?` (a Aula 53 o ampliou), e `AuthGatewayException`, o tipo do projeto para falhas de autenticação. O arquivo não tem import nenhum. `lib/config/firebase_auth_gateway.dart` implementa a interface e traduz `FirebaseAuthException` para o tipo do projeto, tornando-se o único arquivo do aplicativo, fora do `main.dart`, que conhece `firebase_auth` — propriedade verificável com um `grep`.

Nenhum método da interface devolve `User`. Se devolvesse, o fake precisaria imitar uma classe do plugin e a costura não cortaria nada. É por isso que `currentUserToken()` absorve o `currentUser == null` e devolve `null`: "não há usuário" é detalhe do SDK, não decisão de política.

A segunda parte é a política em si. `FirebaseAuthTokenProvider` passou a depender de `AuthGateway`, o caminho normal ganhou proteção, e os dois gatilhos — o `401` do servidor e a falha ao obter o token — convergem para um único `_recoverIdentity()`. Um detalhe do Dart decide se isso funciona: dentro do `try`, é obrigatório `return await`. Sem o `await`, o método devolve o future pendente e sai do bloco antes de a falha acontecer, e o `catch` nunca dispara.

Com a costura pronta, `FirebaseAuthTokenProvider` ganhou testes de unidade pela primeira vez, em `test/config/`, com um fake escrito à mão e sem Firebase nenhum. O fake registra quantas vezes `signOut` e `signInAnonymously` foram chamados, e esse contador é o que torna verdadeiro o nome de `does not recover when the current token is obtained successfully`: uma correção que recuperasse por precaução devolveria o token certo e passaria numa asserção de valor, criando uma conta anônima nova a cada requisição de rede — defeito que só apareceria no console do Firebase ou na fatura.

Os três testes foram validados por quebra dirigida, e a atribuição foi conferida uma a uma: cada quebra derruba exatamente o teste que lhe corresponde, e nenhum outro.

Na Aula 39, a classificação de falhas criada na Aula 27 ganhou o primeiro consumidor de produção. Até então, `TimeoutFailure`, `ServerUnavailableFailure`, `ConnectivityFailure`, `PermanentFailure` e `UnknownFailure` existiam e só eram lidas por testes — o `CheckoutCubit` capturava `on Exception` e tratava tudo igual.

O `CheckoutApiClient` passou a ter um segundo interceptor, que trata `401` e falhas transitórias em camadas separadas. Um `switch` exaustivo sobre a `sealed class` decide o que merece nova tentativa imediata: timeout, servidor indisponível e falta de conectividade sim; falha permanente e não classificada não. A exaustividade é o ponto — uma variante nova de `NetworkFailure` quebra a compilação até alguém decidir de que lado ela fica, em vez de cair num `default` silencioso.

**Retentar automaticamente só é seguro por causa da Aula 33.** Um timeout não diz se o servidor processou a requisição ou apenas demorou a responder; sem a chave de idempotência, uma segunda tentativa poderia criar dois checkouts. Este é o tipo de dependência entre aulas que não aparece no código e vale registrar.

Três horizontes de retentativa convivem agora, e a distinção entre eles é o conceito da aula. O interceptor de autenticação retenta **uma vez, imediatamente**, para credencial recusada. O interceptor de falhas transitórias retenta **duas vezes, com recuo de 200 e 400 milissegundos**, para instabilidade passageira. E o outbox retenta **na próxima inicialização do aplicativo**, para quando a rede caiu de vez. Cada um cobre uma escala de tempo diferente.

As esperas são parâmetro do construtor, com padrão para produção. Isso mantém a suíte rápida — os testes passam `Duration.zero` — e permite desligar a retentativa com uma lista vazia, o que quatro testes existentes precisaram fazer: eles simulam falhas transitórias com uma única resposta programada e verificam outra coisa, então a retentativa esgotava a fila do fake e mudava o tipo do erro. Não foi defeito dos testes; foi a suíte percebendo corretamente que o comportamento mudou.

Uma armadilha vale registrar. A primeira versão do interceptor fazia as retentativas num laço dentro de uma única passagem do `onError`. Parece equivalente, mas `_dio.fetch` percorre a cadeia de interceptors de novo: cada falha abria outro `onError`, com outro laço, multiplicando as tentativas sem controle — um teste passou a levar trinta segundos. A forma correta é uma tentativa por passagem, contada em `RequestOptions.extra`, como o interceptor de autenticação já fazia.

### Inicialização não bloqueante (Aula 42)

`main()` executa `unawaited(synchronizer.drain())`: a primeira tela aparece a partir do estado local e o reenvio do outbox acontece em segundo plano.

Tirar o `await` só é seguro porque `drain()` passou a ser total. O `try/catch` do laço, da Aula 27, protegia cada evento mas deixava a leitura da fila de fora; num future descartado, o que escapa não derruba o aplicativo de forma visível, vira erro assíncrono não tratado com a interface já em uso. A captura nova inclui `Error` de propósito — o Drift lança `StateError` para banco em estado inválido, e `on Exception` não o pegaria.

A regra `unawaited_futures` foi ligada no `analysis_options.yaml` no mesmo movimento. Ela não vem no `flutter_lints`, então até então apagar um `await` passava limpo pela análise. Na primeira execução apontou dois pontos, ambos em teste e ambos legítimos, incluindo uma corrida em que a asserção lia o snapshot que o `retry()` não-esperado deveria ter gravado.

A sobreposição criada pela mudança — usuário criando um pagamento enquanto o mesmo evento é reenviado — só não duplica cobrança por causa da idempotência construída na Aula 33: a chave é o identificador do documento no Firestore, então a segunda requisição encontra o existente.

A verificação foi por medição, com rede lenta emulada e o mesmo evento pendente restaurado antes de cada partida a frio: mediana de ~4,1 s com `await` contra ~2,5 s sem, e — o que mais importa — variância apertada (2,2 a 2,8 s) em vez de dependente da rede (3,4 a 7,1 s). Os números completos estão na ADR 0001.

### O indicador de compra pendente (Aula 43)

A Aula 42 tirou a sincronização da frente do usuário e, com isso, deixou a falha completamente silenciosa. O indicador fecha essa lacuna pelo lado da leitura.

`CheckoutDatabase.watchHasPendingSync()` deriva um `Stream<bool>` da consulta do outbox — é o primeiro `Stream` do aplicativo, que até aqui lia dados apenas por `Future`. `PendingSyncIndicator`, na tela inicial, o consome com `StreamBuilder` e some sozinho quando a fila esvazia.

O widget recebe `Stream<bool>`, nunca o stream do Drift: `OutboxEvent` é classe gerada pela persistência, e entregá-la à interface repetiria o vazamento que a Aula 41 corrigiu na autenticação. A derivação com `map` e `distinct` vive no banco, e não no `main()`, porque as linhas de composição não são cobertas por teste algum — lá, remover o `distinct` passaria despercebido; no banco, derruba um teste.

O indicador também não vive no `CheckoutCubit`: o Cubit dura uma sessão de checkout, o outbox guarda intenções de execuções anteriores, e o aviso precisa aparecer na tela inicial, onde não há Cubit.

Dois detalhes que a escrita dos testes ensinou. O stream do Drift dispara a consulta ao ser assinado, mas entrega o resultado de forma assíncrona — mutar a tabela em seguida faz a primeira emissão já vir com a mudança, e o estado inicial nunca é observado; `pumpEventQueue` resolve sem apostar num intervalo de relógio, como `Future.delayed` faria. E um caso que emite o mesmo valor do estado inicial não pode falhar: `starts hidden before the stream emits` não emite nada, porque o que está sob teste é o `initialData`.

A verificação foi manual, contra as functions em produção: com evento pendente e sem rede, o aviso aparece e permanece; com rede lenta, aparece na abertura e desaparece **na mesma sessão**, sem navegação nem reinício. Nessa verificação apareceu um limite que era invisível até então — o `drain()` roda uma vez, na inicialização, então religar a rede com o aplicativo aberto não faz o aviso sumir. Está registrado na ADR 0001.

### Reenvio quando a conectividade volta (Aula 45)

Até aqui o `drain()` rodava uma vez, na inicialização. A Aula 43 tornou isso visível: com o aplicativo aberto e a rede voltando, o indicador ficava na tela até o usuário reabrir. Agora a volta da rede é um gatilho.

O conteúdo da aula, porém, não é o gatilho — é o que ele obrigou a construir antes.

**Reentrância.** `OutboxSynchronizer` era `const` e sem estado, seguro apenas porque havia uma única chamada. Dois gatilhos simultâneos fazem duas drenagens lerem a mesma fila e reenviarem os mesmos eventos; o servidor sobrevive pela idempotência da Aula 33, o aparelho gasta o dobro de requisições.

Um pedido que chega durante uma drenagem é **marcado**, e uma passada nova acontece ao final — em vez de ser ignorado. Ignorar descartaria o sinal mais valioso: a rede que volta no meio de uma drenagem travada em timeout é a que teria sucesso, e a janela em rede instável vai de 8 a 25 segundos, que é justamente quando o usuário mexe no wi-fi.

**A instância precisa ser única**, porque a proteção vive em campos de instância. Construir um segundo `OutboxSynchronizer` em `composeDependencies` compila e passa em quase tudo — o que o pega é `sends each event once when a trigger overlaps the startup drain`, que conta requisições com uma sobreposição deliberada.

**Construir e iniciar são separados.** `OutboxSyncScheduler` recebe o stream de gatilhos e a função de drenagem, e só assina no `start()`. É o que mantém `composeDependencies` pura, como a Aula 44 estabeleceu; o `main()` inicia, ao lado do `unawaited(drain())`.

**`ConnectivitySyncTriggers`** é o único arquivo do aplicativo que importa `connectivity_plus`, e traduz `List<ConnectivityResult>` em `Stream<void>`. Ele colapsa repetições pelo **conjunto de interfaces**, não por "há rede?": uma troca de wi-fi para dados móveis mantém o booleano em `true`, e colapsá-la perderia o gatilho de quem abandona uma rede quebrada pelo 4G. Cuidado com a armadilha que isso revelou — listas em Dart comparam por identidade, então `distinct()` sem comparador não colapsa nada e o filtro parece existir sem existir.

Conectividade não é conexão: um wi-fi com portal cativo reporta conectado. O gatilho é uma dica para tentar, e quem lida com a falha continua sendo a retentativa da Aula 39.

Verificado manualmente contra as functions em produção: aplicativo em primeiro plano, sem rede, indicador visível; rede religada sem nenhum toque no aparelho; cerca de catorze segundos depois o outbox esvaziou e o aviso sumiu sozinho.

### A retomada do aplicativo como terceira fonte (Aula 46)

`LifecycleSyncTriggers`, em `lib/lifecycle/`, embrulha `AppLifecycleListener` e emite em `onResume`. É o mesmo formato de `ConnectivitySyncTriggers`: um adaptador que traduz uma API de plataforma em `Stream<void>`, e o único arquivo do aplicativo que conhece essa API.

`composeDependencies` passou a receber `Iterable<Stream<void>>` e funde com `StreamGroup.merge`, do `package:async`. A fusão é preguiçosa — só assina as fontes quando alguém assina o resultado —, então montar o grafo continua sem efeito colateral, que é a regra estabelecida na Aula 44.

Fundir na composição, e não no `main()`, é o que torna a fusão verificável: `drains on a trigger from any source` passa dois controllers e afirma **entre** as emissões que cada fonte, sozinha, dispara a drenagem. A asserção conta requisições em vez de checar a fila vazia — com só a segunda fonte ligada, a drenagem tardia pegaria os dois eventos de uma vez e a fila esvaziaria mesmo com metade da fusão quebrada.

Duas armadilhas apareceram no caminho. O Flutter **valida transições de ciclo de vida**: `resumed` só pode vir de `inactive` ou `detached`, e saltar estados dispara asserção — a falha aparece como "não emitiu", que é o sintoma. E `AppLifecycleListener.dispose` **não é idempotente**, ao contrário de `StreamController.close`; um `addTearDown` somado a um descarte explícito no teste basta para encontrar isso.

Nenhum dos dois adaptadores é descartado em produção: eles vivem o processo, como o agendador que alimentam. Os `dispose()` existem para os testes.

**O que a medição mostrou.** Com as duas fontes ativas, a fila esvaziou com o aplicativo em segundo plano, antes de ser trazido de volta — neste emulador o Android entregou a mudança de conectividade ao processo em background, e o gatilho da Aula 45 bastou. Só um build temporário com apenas a fonte de ciclo de vida isolou o comportamento: rede religada em segundo plano não moveu a fila em quatro verificações; a retomada a esvaziou. Nas condições reproduzíveis aqui, portanto, a retomada é **redundante** — ela cobre Doze, restrições de fabricante e permanência longa em segundo plano, que o emulador não reproduz.

### Testes de golden (Aula 48)

`test/benefits_home_golden_test.dart` compara a renderização da tela de benefícios, em dois estados, com imagens versionadas em `test/goldens/`. Eles cobrem a única categoria de defeito que os outros testes não enxergam: **posição e distribuição de espaço**.

O motivo é concreto. Na Aula 43, envolver o cartão numa `Column` fez o `Center` do `MediFlowContentCard` perder o espaço para centralizar, e o cartão subiu 82 px — com 101 testes verdes, porque todos verificam presença e nenhum verifica posição.

A tela foi escolhida por ser estável: não muda há dez aulas. O `PharmacyModePage` ficou de fora porque ganhou botão novo em quatro das últimas dez — um golden que se regrava toda aula ensina o reflexo de apertar `--update-goldens` sem olhar, e aí ele deixa de testar qualquer coisa.

A superfície é fixada em 390×844 no próprio teste. O padrão do `flutter test` é 800×600, e depender dele faria todos os goldens falharem de uma vez no dia em que esse padrão mudasse.

#### O que eles não cobrem

**Texto.** O `flutter test` não carrega fontes reais, então todo texto renderiza como retângulo. Trocar "Saldo disponível" por outra frase do mesmo comprimento passa despercebido.

**Mudanças visuais abaixo de 3%.** `test/flutter_test_config.dart` instala um comparador com tolerância, porque goldens gerados no macOS não batem exatamente com o Linux da CI — antialiasing de bordas arredondadas e sombras diverge. Os números medidos neste projeto:

| Origem da diferença | Percentual |
| --- | --- |
| Ruído de plataforma (macOS → Linux) | 1,25% e 1,72% |
| Regressão real (o cartão subindo 82 px) | 46,34% e 43,43% |

A tolerância de 3% fica bem acima do ruído e muito abaixo do sinal. Ela só é defensável por causa dessa distância de uma ordem de grandeza — com ruído de 20% e sinal de 40%, a resposta teria sido outra, e as alternativas seriam gerar os goldens na CI ou rodá-los apenas lá. As duas quebram o ciclo local: a primeira deixa vermelhos permanentes no Mac, a segunda impede gerar e inspecionar a imagem antes de versionar.

#### Quando um golden falhar

O Flutter escreve as imagens de comparação em `test/failures/` — a gerada, a de referência e o diff isolado. **Olhe o diff antes de decidir.** Regravar com `flutter test --update-goldens` é para mudança intencional; para regressão, o certo é consertar o código.

`test/failures/` está no `.gitignore`: é artefato de depuração, não histórico.

### A camada de apresentação (Aulas 50 e 51)

A Aula 50 moveu as quatro telas de `main.dart` para `features/*/presentation/`, sem alterar comportamento — o diff dos nove testes afetados conteve exclusivamente linhas de `import`, e a contagem de testes foi a mesma antes e depois.

A Aula 51 fez o `CheckoutCubit` parar de expor `CheckoutSession`. A decisão, as alternativas recusadas e os limites estão em [`docs/adr/0002-presentation-layer-boundary.md`](../../docs/adr/0002-presentation-layer-boundary.md). O resumo operacional:

- a View não importa `checkout_domain`, e por isso `scanMedication` recebe `String`, `submitPrescription` recebe `String` e `checkEligibility` não recebe nada;
- as cinco regras de habilitação, a pluralização e os três ramos de feedback saíram de `build()` e viraram campos de `CheckoutViewState`;
- `CheckoutViewState` tem igualdade de valor, então a supressão de emissões repetidas do `Cubit` passou a atuar — antes nunca atuava, porque `CheckoutSession` não declara `==`.

#### Como isso é verificado

Substituindo o `==` de `CheckoutViewState` por identidade, um único teste fica vermelho: `does not emit again when a transition produces an identical view state`. Os outros treze do arquivo continuam verdes. Isso é o que torna esse teste o único que mede a decisão — e o que impede que ela seja desfeita por engano.

Com `CheckoutSession` privada, os testes deixaram de espiar estado interno. O EAN informado e a referência da receita são verificados pelo que chegou aos repositórios, usando fakes que registram o argumento recebido.

### O dono do Cubit e a ação inválida (Aula 52)

`BlocProvider.value` não fecha o bloc que recebe — ele existe para o caso em que outra pessoa é dona. Não havia outra pessoa: o `CheckoutCubit` nascia num callback de navegação e cada abertura do Modo Farmácia deixava um para trás, com um `DriftCheckoutSessionStorage` dentro.

`BenefitsHomePage._openPharmacyMode` agora resolve o `restore()` antes de navegar, empurra a rota com `await`, e fecha o cubit quando ela é desempilhada. Quem cria, fecha, no mesmo método. Um `context.mounted` cobre o caso em que a tela sai antes de o `restore()` resolver.

`canScan` deixou de ser constante `true`: `MedicationScanned` só tem transição a partir de `collectingMedication`, e o botão habilitado fora dela levava a `InvalidCheckoutTransitionException`.

Os dois têm teste, e os dois foram verificados por quebra: removendo o `close()`, só `fecha o CheckoutCubit ao sair do Modo Farmácia` fica vermelho; devolvendo `canScan: true`, só `blocks scanning once the checkout left medication collection`.

### A identidade atravessa a costura (Aula 53)

`AuthGateway` sabia obter token e não sabia dizer quem era o usuário: nenhum `uid` cruzava a fronteira. Enquanto toda sessão era anônima isso bastava. Com contas, deixa de bastar — e não por conveniência, mas porque a política de recuperação de identidade **depende** de quem era o usuário.

O contrato ganhou `currentUser`, `authStateChanges()`, `signInWithEmail` e `registerWithEmail`, e um tipo próprio:

```dart
final class AuthUser {
  final String uid;
  final String? email;
  final bool isAnonymous;
}
```

`AuthUser` não é o `User` do `firebase_auth`, pelo mesmo motivo de sempre: se fosse, o fake precisaria imitar uma classe do plugin e a costura não cortaria nada. `isAnonymous` é campo explícito em vez de derivado de `email == null`, porque autenticação por telefone produz conta real sem e-mail — e é essa flag que decide a política.

`currentUser` é **síncrono** de propósito. A política precisa saber quem era o usuário antes de encerrar a sessão, e uma leitura assíncrona abriria janela para o estado mudar entre decidir e agir.

#### A política deixou de ser universal

`_recoverIdentity()` ramifica: sessão anônima cria outra; conta encerra a sessão e devolve `null`, sem inventar identidade.

A ordem no código é obrigatória e não é evidente — `currentUser` é lido **antes** do `signOut()`, porque depois dele é sempre `null`, o que cairia no ramo anônimo e restauraria a política antiga em silêncio.

#### Como isso é verificado

Três sabotagens, um único vermelho em cada, sempre o mesmo teste:

| Sabotagem | Vermelho |
| --- | --- |
| `isAnonymous` sempre verdadeiro | `ends the session without a new identity when a real account is rejected` |
| ler `currentUser` depois do `signOut` | idem |
| remover o ramo (conta volta a criar anônimo) | idem |

A asserção que carrega o teste é `expect(fake.signInCalls, 0)`. `token == null` sozinho não serve: `null` é também o que sai quando a recuperação falha, e só a contagem separa "encerrou a sessão de propósito" de "tentou criar identidade nova e não conseguiu".

O `FakeAuthGateway` cresceu junto — `currentUserValue` público para montar os dois ramos, um `StreamController.broadcast` de verdade para `authStateChanges`, e erro e contador nos métodos novos. `signInAnonymously` e `signOut` passaram a atualizar o usuário atual, como o Firebase real faz: um fake que diverge do real deixa passar teste verde sobre comportamento que não existiria.

#### Dívida conhecida

Devolver `null` para conta rejeitada faz a requisição sair sem `Authorization` (`checkout_api_client.dart:81-86`), o que garante `401` e, com os gatilhos do outbox, um laço. Está registrado na [ADR 0001](../../docs/adr/0001-offline-first-scope-and-limits.md) e é o assunto da Aula 56.

### Entrar e cadastrar, e o portão (Aula 54)

O aplicativo deixou de criar sessão anônima. `main.dart` não chama mais `signInAnonymously`, e a primeira tela passou a depender de quem está autenticado.

`features/auth/presentation/` tem cinco arquivos: `AuthViewState` e `AuthCubit` (o ViewModel do formulário), `SignInPage` e `RegisterPage`, `AuthGate` e `auth_validators.dart`.

#### O portão

```dart
StreamBuilder<AuthUser?>(
  stream: _authState,                                  // assinado uma vez, num campo
  initialData: widget.authGateway.currentUser,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) { ... }
```

Três estados, e o discriminador é `connectionState` — **não** `hasData`. `hasData` é `data != null`, então num `Stream<AuthUser?>` ele confunde "ainda não sei" com "ninguém autenticado", e a tela de entrada apareceria por um quadro em toda abertura de quem já entrou. O `initialData` elimina até esse quadro quando já existe sessão: é o uso do `currentUser` síncrono que justificou a assinatura na Aula 53.

`authenticatedHome` chega pronto, então o portão não conhece a tela de benefícios — e é testado com um `Placeholder`.

#### A tradução dos códigos

`AuthCubit` mapeia `AuthGatewayException.code` para a mensagem que a pessoa lê. `invalid-credential`, `user-not-found` e `wrong-password` colapsam numa frase só — com a proteção contra enumeração de e-mails ligada, o Firebase já devolve o mesmo código para conta inexistente e senha errada, e distinguir na mensagem desfaria a proteção do lado do cliente. É a mesma decisão do `404` em vez de `403` nas functions.

Códigos não mapeados vão para `debugPrint` e produzem mensagem genérica: o código cru não significa nada para quem lê, mas some do diagnóstico se ninguém o registrar.

#### O que as quebras dirigidas mostraram

| Sabotagem | Único vermelho |
| --- | --- |
| `connectionState == waiting` → `!snapshot.hasData` | `shows the sign in page when nobody is authenticated` |
| rota de cadastro sem `BlocProvider` | `opens the register screen from the sign in page` |
| remover o `initialData` | `shows the authenticated home when a user is signed in` |
| portão ignora o fluxo | `swaps to the authenticated home when the user signs in` |
| remover a guarda de reentrância do Cubit | `ignores a second attempt while the first is still running` |

A primeira contrariou a previsão: o teste do estado de espera **não** a pega, porque antes do primeiro evento os dois discriminadores concordam. Eles só divergem quando chega um evento explícito de ausência de usuário.

#### Três defeitos que o analisador não pegava

Um `context.read<SignInPage>()` procurando um `Provider` de um widget, que nunca existe. Uma rota empurrada sem provedor, porque o da tela de entrada é descendente do `Navigator` e não ancestral. E o mínimo de senha divergindo entre duas cópias do mesmo validador, uma exigindo seis caracteres e a outra oito.

Os dois primeiros só apareceram com sondas descartáveis. O terceiro levou os validadores para `auth_validators.dart`: privacidade em Dart é por biblioteca, então validadores privados em cada tela não podem ser compartilhados — só copiados.

#### A costura fechou

```
grep -rln "package:firebase_auth" apps/mobile/lib
  lib/main.dart                         ← composition root
  lib/config/firebase_auth_gateway.dart ← adaptador
```

`composeDependencies` continua pura: ela **recebe** o `AuthGateway`, e quem constrói o `FirebaseAuthGateway` é o `main()`. Uma instância só, compartilhada entre o provedor de token e o portão.

## Execução

O aplicativo exige a URL do backend em tempo de compilação e falha imediatamente se ela não for informada. Suba os emuladores do Firebase em um terminal:

```bash
cd functions
npm install
npm run build
cd ..
firebase emulators:start --only auth,functions,firestore
```

E execute o aplicativo em outro, apontando para eles:

```bash
flutter devices
cd apps/mobile
flutter run -d <device-id> \
  --dart-define=CHECKOUT_API_BASE_URL=http://10.0.2.2:5001/mediflow-learning/us-central1/api \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

A segunda variável faz o aplicativo chamar `useAuthEmulator` logo após `Firebase.initializeApp` e antes do login anônimo. Sem ela, o aplicativo autenticaria contra o Firebase real enquanto as functions validam contra o emulador — dois mundos diferentes, e todo pedido voltaria `401` por um motivo que não é o aparente.

O endereço `10.0.2.2` vale para o emulador Android, que o usa como alias da máquina hospedeira. Em um dispositivo físico na mesma rede, troque pelo IP da máquina. O emulador do Firestore exige Java instalado; consulte o README de `functions/` para os detalhes.

### Contra o backend publicado

Para falar com as Cloud Functions em produção, troque a URL e **omita** a segunda variável:

```bash
flutter run -d <device-id> \
  --dart-define=CHECKOUT_API_BASE_URL=https://us-central1-mediflow-learning.cloudfunctions.net/api
```

Omitir é o correto: `bool.fromEnvironment` já devolve `false` por padrão, e passar `=false` explicitamente só existiria para desfazer um valor que ninguém definiu. O `10.0.2.2` também some, porque o destino deixa de ser a máquina hospedeira, e o `usesCleartextTraffic` do manifesto de debug fica irrelevante, porque a URL é `https`.

**Ao alternar entre os dois modos, limpe os dados do aplicativo.** A credencial do Firebase Auth fica em cache no dispositivo, e uma credencial emitida pelo emulador não vale contra o Firebase real — nem o contrário. O sintoma é descrito na ADR 0001 e não se parece nem um pouco com a causa: falha silenciosa, permanente, sem requisição chegando ao servidor.

```bash
adb shell pm clear com.leomoraesitu.mediflow_mobile
```

## Validação

Estes comandos rodam automaticamente a cada pull request, no job `dart` do workflow `Quality Gate` — que é check obrigatório para mesclar no `main`. O README da raiz descreve a configuração e as decisões por trás dela. Rodar localmente antes de abrir o PR evita o ciclo de esperar o runner.

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

O resultado esperado é formatação limpa, análise estática sem problemas, 124 testes aprovados — incluindo acessibilidade, navegação, validação de entrada, Cubits, integração da sessão com a interface, efeito reativo de confirmação, progresso selecionado, feedback de falhas, feedback acessível de checkout concluído, submissão da receita, ações de avanço do checkout, o round-trip JSON do snapshot, o armazenamento assíncrono em memória, as operações do banco Drift, o adapter SQLite, a restauração/persistência de sessão pelo `CheckoutCubit`, os três repositórios HTTP com Dio, sua classificação de falhas, o envio da chave de idempotência, o ciclo completo do outbox local (registro, remoção e reenvio) o modo de manutenção controlado por configuração operacional o envio do token de autenticação como header `Bearer` a renovação automática de credencial após um `401`, a retentativa de falhas transitórias com recuo exponencial a recuperação de identidade quando o token não chega a ser obtido a tolerância do `drain()` a uma falha de leitura do outbox, a consulta reativa do outbox, o indicador de compra pendente a montagem do grafo de dependências, a proteção contra drenagens concorrentes, o agendador de sincronização, a tradução de conectividade em gatilhos a retomada do aplicativo como fonte os dois goldens da tela de benefícios e os decorators de performance envolvendo cada repositório — e somente alterações intencionais exibidas pelo Git. O Quality Gate completo do monorepo também executa os testes de fronteira do package `checkout_domain`, agora incluindo a geração e preservação da `idempotencyKey`. `test/flutter_test_config.dart` desativa o aviso do Drift sobre múltiplas instâncias de `CheckoutDatabase` — inofensivo aqui, já que cada teste de widget abre seu próprio banco isolado em memória, mas o Drift não distingue isso de um erro real de compartilhamento de `QueryExecutor`.

### Teste de integração

Existe um segundo tipo de teste no projeto, com pré-requisito de ambiente e por isso fora do `flutter test` comum — e também **fora da CI**, que não tem emulador de Authentication nem dispositivo. Rodá-lo lá daria verde sem exercitar nada. Ele exige o emulador de Authentication no ar e um dispositivo conectado:

```bash
firebase emulators:start --only auth
cd apps/mobile
flutter test integration_test/identity_recovery_test.dart -d <device-id>
```

`identity_recovery_test.dart` verifica que a política de renovação de identidade produz de fato uma credencial nova depois que a conta deixa de existir. É cobertura estreita e profunda, deliberadamente: ela não percorre o fluxo de checkout nem valida a composição inteira, mas é o único teste do projeto que exercita o `FirebaseAuth` real, e teria pego as duas premissas erradas da Aula 36 que passaram por toda a suíte de unidade.

### Limite conhecido

**A composição do `main()` é coberta em parte, e vale saber qual parte.** A Aula 44 extraiu a montagem do grafo para `composeDependencies`, em `lib/app_dependencies.dart`. Ela recebe as quatro peças de plataforma — banco, cliente HTTP, configurações e tracer — em vez de construí-las, e é síncrona e sem efeitos colaterais. É isso, e não o arquivo em que mora, que a torna testável: o `main()` passa o banco real e um cliente com rede; o teste passa um banco em memória e um `CheckoutApiClient.withDio` sobre um adapter falso.

`test/app_dependencies_test.dart` cobre três ligações, cada uma validada por quebra dirigida com atribuição conferida:

| Ligação | Quebra que a derruba |
| --- | --- |
| A criação de checkout passa pelo outbox | trocar o `inner` do decorator pelo repositório Dio cru |
| `hasPendingSync` vem do banco recebido | devolver `const Stream<bool>.empty()` |
| O sincronizador recebe o repositório sem o decorator de performance | envolvê-lo no decorator |

A primeira é **literalmente o erro da Aula 34**, quando o outbox saiu do caminho do aplicativo e 82 testes seguiram verdes. Hoje ela custa um teste vermelho com nome explicável.

O teste do outbox faz o adapter responder erro de propósito. Numa criação bem-sucedida o evento é enfileirado e removido, e a tabela termina vazia — indistinguível de uma cadeia montada **sem** outbox. Falhando, o evento permanece, e só há evento se o outbox estiver no caminho.

O que destravou isso foi o `PerformanceTracer`, em `lib/observability/`. Enquanto os três decorators dependessem de `FirebasePerformance` — classe concreta do plugin, sem substituto em teste —, nenhuma composição podia ser montada fora de um dispositivo. A interface colapsa `newTrace`/`start`/`stop` numa operação, o que também eliminou o `try/finally` repetido nos três. É a mesma costura de `AuthGateway`, na Aula 41.

**O que continua sem cobertura:** os decorators de performance envolvendo os repositórios certos; a ligação do `tokenProvider` ao `FirebaseAuthGateway`, que ficou no `main()` como consequência de o cliente HTTP entrar por parâmetro; e o bootstrap de plataforma — binding, Firebase, emulador, login anônimo e Remote Config —, que não deve ser testado aqui. O teste de integração da Aula 37 cobre a política de identidade contra o emulador de Authentication.

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
- [Configuração oficial Firebase/Flutter](https://firebase.google.com/docs/flutter/setup)
- [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup?platform=android#configure-firebase)
- [Autenticação anônima](https://firebase.google.com/docs/auth/flutter/anonymous-auth)
- [`WidgetsFlutterBinding.ensureInitialized`](https://api.flutter.dev/flutter/widgets/WidgetsFlutterBinding/ensureInitialized.html)
- [Google Analytics para Firebase](https://firebase.google.com/docs/analytics/get-started?platform=flutter)
- [DebugView](https://firebase.google.com/docs/analytics/debugview)
- [Firebase Crashlytics para Flutter](https://firebase.google.com/docs/crashlytics/get-started?platform=flutter)
- [`BlocObserver`](https://pub.dev/documentation/bloc/latest/bloc/BlocObserver-class.html)
- [Firebase Performance Monitoring para Flutter](https://firebase.google.com/docs/perf-mon/get-started-flutter)
- [Traces personalizados](https://firebase.google.com/docs/perf-mon/custom-code-traces?platform=flutter)
- [Firebase Remote Config para Flutter](https://firebase.google.com/docs/remote-config/get-started?platform=flutter)
- [Estratégias de carregamento do Remote Config](https://firebase.google.com/docs/remote-config/loading)
- [`kDebugMode`](https://api.flutter.dev/flutter/foundation/kDebugMode-constant.html)
- [Rede do emulador Android](https://developer.android.com/studio/run/emulator-networking)
- [Configuração de segurança de rede no Android](https://developer.android.com/privacy-and-security/security-config)
- [`String.fromEnvironment`](https://api.dart.dev/dart-core/String/String.fromEnvironment.html)
- [`Error` e `Exception` em Dart](https://dart.dev/language/error-handling)
- [Testes de integração no Flutter](https://docs.flutter.dev/testing/integration-tests)
- [Estratégias de retry e backoff](https://cloud.google.com/storage/docs/retry-strategy)
- [Emulador de Authentication](https://firebase.google.com/docs/emulator-suite/connect_auth)
