# 0001 — Escopo e limites do offline-first no checkout

## Status

Aceito (Aula 28).

## Contexto

As Aulas 21-27 construíram, em camadas: persistência local do snapshot da sessão (`CheckoutSessionStorage` / `DriftCheckoutSessionStorage`), classificação de falhas de rede (`NetworkFailure`), uma chave de idempotência gerada uma vez por tentativa de criação de pagamento (`CheckoutSession.idempotencyKey`), um outbox local que registra a intenção de criar um checkout antes de tentar a rede e só remove após confirmação (`OutboxCheckoutRepository`, `OutboxEvents`), e uma rotina que reenvia eventos pendentes na inicialização do app (`OutboxSynchronizer`). Um teste de ponta a ponta (`resilience_test.dart`) comprova que essas peças juntas evitam duplicar um checkout quando a resposta do servidor se perde e o app reinicia.

Nenhuma dessas peças foi construída citando explicitamente "offline-first" como objetivo — surgiram como resposta a problemas pontuais (retomar sessão após reinício, não duplicar uma cobrança). A Aula 28 revisita esse trabalho e pergunta: no vocabulário do [padrão offline-first do Flutter](https://docs.flutter.dev/app-architecture/design-patterns/offline-first), o que exatamente vocês construíram, e onde ficam os limites reais dessa garantia?

## Decisão

Registramos, sem alterar código, a classificação do sistema atual:

### Leitura local

`CheckoutCubit.restore()` sempre lê o `CheckoutSessionStorage` antes de qualquer chamada de rede — a UI nunca espera o servidor para mostrar uma sessão já existente. Isso é leitura local-first de verdade.

### Escrita: dois modelos coexistindo, por design

O `CheckoutCubit` **não** é write-local-first: em todo método que fala com um repositório (`checkEligibility`, `createCheckout`, `confirmPayment`), a chamada de rede acontece primeiro e `_emitPersisted` só grava o resultado (sucesso ou falha) depois. Já `OutboxCheckoutRepository.create()` grava **antes** de tentar — enfileira o evento no outbox, então chama o repositório interno.

Essa diferença é intencional, não uma inconsistência a corrigir: `checkEligibility` é uma **consulta** (sem efeito colateral no servidor; repetir não tem custo), enquanto `createCheckout` é um **comando** com efeito colateral caro de duplicar (uma segunda cobrança). O outbox e a idempotência existem especificamente para comandos não-idempotentes por natureza — não para toda escrita do sistema.

### Conflitos: evitados por construção, não resolvidos por design

`CheckoutSessionRecords` é uma tabela de registro único (`id = 1`), sobrescrita via `insertOnConflictUpdate` — last-write-wins silencioso, sem campo de versão, sem detecção de escrita concorrente. Isso é seguro hoje porque duas condições seguram o sistema: (1) uma única instância de `CheckoutCubit` processa mutações sequencialmente (cada método é `async`/`await` até o fim antes do próximo poder rodar); (2) não existe sincronização entre dispositivos — a tabela é local a um único SQLite, sem contraparte remota que também escreva nela.

Essas duas condições não são garantias arquiteturais permanentes — são o estado atual do projeto. Se um dia o app ganhar sincronização multi-dispositivo (mesma conta, dois aparelhos), esse desenho sobrescreverá dados silenciosamente, sem aviso.

### Limite descoberto na Aula 28 e resolvido na Aula 42: inicialização bloqueada pelo outbox

> **Resolvido.** `main()` executa `unawaited(synchronizer.drain())`. O relato abaixo permanece porque descreve o problema, e a subseção seguinte registra o que a correção exigiu.

`main()` chamava `await synchronizer.drain()` antes de `runApp()` — a primeira tela do app esperava a tentativa de reenvio do outbox resolver (ou falhar) antes de aparecer. Isso contradiz o espírito offline-first (mostrar a UI imediatamente a partir do estado local, sincronizar em segundo plano sem bloquear). Foi assim que o `OutboxSynchronizer` foi conectado na Aula 28, e a inconsistência foi identificada em discussão, não corrigida — decisão explícita de manter o escopo daquela aula em discussão, não em implementação.

#### O que a correção exigiu, e o que ela mediu

Remover o `await` não é uma edição, é uma mudança de contrato. Com ele, uma falha de `drain()` subia em `main()` antes do `runApp` e derrubava o aplicativo de forma visível. Sem ele, a mesma falha vira **erro assíncrono não tratado**, com a interface já em uso.

Por isso a primeira mudança foi tornar `drain()` total. O `try/catch` do laço, criado na Aula 27, protegia cada evento mas deixava `readPendingOutboxEvents()` de fora. A captura nova é deliberadamente larga e inclui `Error`: o Drift lança `StateError` para banco em estado inválido, que `on Exception` não pegaria. Capturar largo numa fronteira é diferente de capturar largo no meio do código — aqui a alternativa é o erro não tratado. O preço aceito é que um defeito de programação dentro do `drain()` desaparece em silêncio; registrá-lo no Crashlytics fecharia essa lacuna e ficou fora do escopo.

A regra de lint `unawaited_futures` foi ligada no mesmo movimento. Ela não vem no `flutter_lints`, então até então apagar um `await` passava limpo pela análise estática. Na primeira execução ela apontou dois pontos, ambos em teste e ambos legítimos — um deles uma corrida real, em que a asserção lia o snapshot que o `retry()` não-esperado era responsável por gravar.

**A sobreposição que a mudança cria só é segura por causa da Aula 33.** Com a interface no ar antes do reenvio terminar, o usuário pode criar um pagamento enquanto o mesmo evento pendente é reenviado, e as duas requisições saem com a mesma `Idempotency-Key`. O backend usa essa chave como identificador do documento no Firestore, então a segunda encontra o existente e devolve o mesmo `id`. Sem essa garantia no servidor, remover o `await` trocaria uma splash lenta por cobrança duplicada. É uma dependência entre duas aulas distantes que não se reconstrói lendo o código.

A verificação foi por medição, com o mesmo evento pendente restaurado antes de cada partida a frio e rede lenta emulada (EDGE):

| Versão | Medições | Mediana |
| --- | --- | --- |
| Com `await` | 7,14 s · 4,08 s · 3,37 s | ~4,1 s |
| Sem `await` | 2,52 s · 2,42 s · 2,78 s · 2,16 s | ~2,5 s |

O ganho relevante não é a mediana, é a variância: sem `await` a inicialização fica entre 2,2 e 2,8 s; com `await` ela herda a variabilidade da rede e do cold start da function. A inicialização deixou de ser função da rede. O outbox ficou vazio ao final das execuções sem `await`, confirmando que a sincronização aconteceu — apenas não na frente do usuário.

Uma medição contrariou a expectativa e merece registro: **sem rede alguma**, a versão com `await` era rápida e consistente (~1,95 s), porque sem rota a conexão falha imediatamente. O caso caro nunca foi "offline", e sim "rede lenta". Um teste feito apenas em modo avião teria concluído que o `await` não custava nada.

### Limite descoberto na Aula 35, corrigido em duas etapas: identidade inválida travava o outbox

> **Resolvido na Aula 41.** A Aula 36 cobriu a rejeição — servidor respondendo `401`. A Aula 40 mostrou que faltava a outra metade: a falha ao **obter** o token não produz resposta alguma, logo não produz `401`, logo não acionava recuperação nenhuma. A Aula 41 fez os dois gatilhos convergirem. O relato abaixo permanece porque descreve os mecanismos e as três premissas que caíram no caminho.

Com a autenticação das rotas do backend, o outbox ganhou uma forma nova de falhar permanentemente. `main()` só autentica quando não há usuário:

```dart
if (FirebaseAuth.instance.currentUser == null) {
  await FirebaseAuth.instance.signInAnonymously();
}
```

A guarda evita uma chamada de rede redundante a cada abertura, já que o Firebase Auth persiste a sessão anônima no dispositivo. Mas ela também significa que **o aplicativo nunca se reautentica quando a credencial guardada deixa de valer**. Isso acontece quando a conta anônima é excluída ou desativada no console, ou quando o refresh token é revogado.

Nesse estado, todas as chamadas ao backend recebem `401`, que o `NetworkFailure` classifica como `PermanentFailure`. O efeito sobre o outbox é o pior possível: o evento pendente é reenviado a cada inicialização, rejeitado a cada vez, e permanece na fila indefinidamente. Diferente de uma falha de rede, essa não se resolve sozinha com o tempo — o app fica em loop silencioso, sem sinal na interface, e o checkout do usuário nunca chega ao servidor.

O comportamento foi observado durante a validação da Aula 35, quando o emulador de Authentication foi reiniciado (ele guarda usuários em memória) enquanto o aplicativo mantinha a credencial em cache. Removendo apenas a credencial persistida e preservando o outbox, o aplicativo criou um usuário novo na inicialização seguinte, o reenvio passou e a fila esvaziou — confirmando o diagnóstico.

#### Como foi corrigido, e as duas premissas que caíram no caminho

O `onError` do interceptor do Dio passou a tratar `401` como sinal de que a identidade precisa ser renovada: ele pede uma credencial nova ao provedor, refaz a requisição uma única vez e entrega o resultado ao chamador. A marcação fica em `RequestOptions.extra`, que viaja com a requisição e impede laço infinito; qualquer outro erro, inclusive `500`, passa direto sem renovação. O `onRequest` reconhece a retentativa e não reescreve o header, senão desfaria a renovação que o `onError` acabou de aplicar.

A validação contra os emuladores derrubou duas premissas do desenho original, e nenhuma delas seria pega por teste automatizado, porque ambas dependem do comportamento real do SDK:

1. **`getIdToken(true)` não sinaliza identidade inválida.** Supunha-se que a renovação falharia para um usuário excluído, revelando o cenário. Ela não falhou: devolveu um token para um usuário que já não existia. Por isso a política deixou de tentar distinguir "token expirado" de "identidade morta" e passou a simplesmente obter uma identidade nova — decisão viável porque a autenticação é anônima e a conta não guarda nada.

2. **`signInAnonymously()` devolve o usuário anônimo já autenticado em vez de criar outro.** É comportamento documentado, e significa que, com a credencial inválida ainda em cache, a "renovação" retornava exatamente a credencial recusada. O `signOut()` antes do login é o que torna a recuperação real, e está comentado no código como obrigatório justamente porque parece supérfluo.

O cenário foi reproduzido de ponta a ponta: evento enfileirado durante uma queda do backend, identidade invalidada, aplicativo reiniciado. Antes da correção, o evento era rejeitado a cada inicialização; depois, ele chegou ao Firestore sozinho, com o outbox esvaziando sem nenhuma intervenção.

#### O que a Aula 40 falsificou: a recuperação depende de uma resposta que pode nunca existir

O primeiro deploy real expôs um terceiro modo de falha, invisível sob o emulador.

O aplicativo tinha em cache uma credencial emitida pelo **emulador de Authentication**, gravada durante as Aulas 34 a 39. Executado sem `USE_FIREBASE_EMULATORS`, ele passou a falar com o Firebase real, que não reconhece aquele refresh token. `getIdToken()` falhou — e o caminho normal de `FirebaseAuthTokenProvider.token()` não tem proteção: só o ramo `forceRefresh` captura `FirebaseAuthException`.

A exceção sobe dentro do `onRequest` do interceptor. O Dio a converte em `DioException` do tipo `unknown`, que a classificação da Aula 39 mapeia para `UnknownFailure` — deliberadamente **não** transitória e por isso não retentada, decisão correta em si: repetir uma falha não compreendida é ruído.

**O buraco está no encadeamento.** A renovação de identidade da Aula 36 é acionada por `e.response?.statusCode == 401`. Mas a requisição nunca foi enviada: não houve resposta, logo não houve `401`, logo a renovação jamais disparou. O mecanismo construído para "identidade inválida" ficou cego justamente para o caso em que o token **não chega a ser obtido**.

O resultado é o pior formato possível de falha: silenciosa, permanente, sem retentativa, sem recuperação, sem nada no log do servidor — porque nada chega ao servidor. Diagnosticá-la exigiu descartar rede, DNS, timeout, Remote Config e provedor de login antes de chegar ao interceptor.

Quatro evidências convergentes sustentam o diagnóstico, já que a exceção é engolida pelo `on Exception` de `CheckoutCubit.createCheckout`:

1. Nenhuma requisição do aplicativo apareceu nos logs da function, embora chamadas de `curl` feitas no mesmo período aparecessem.
2. O outbox continha o evento enfileirado, provando que `OutboxCheckoutRepository.create()` executou e que a falha veio depois, na camada de rede.
3. Nenhuma conta anônima foi criada no projeto naquele dia, provando que a renovação da Aula 36 não chegou a ser acionada.
4. Limpar a credencial em cache resolveu por completo, e o fluxo de checkout percorreu as quatro rotas contra produção na tentativa seguinte.

A correção fica para uma aula própria, porque a parte difícil é o teste: ele precisa reproduzir "o provedor de token lança" sem se tornar mais um teste que não pode falhar — o padrão recorrente que este projeto já encontrou em quatro ocasiões distintas.

#### Como a Aula 41 fechou: uma costura antes da correção

A correção exigiu um passo anterior. `FirebaseAuthTokenProvider` recebia `FirebaseAuth`, uma classe concreta do plugin que depende de canal de plataforma — por isso a política de identidade só tinha cobertura em `integration_test`, e por isso a Aula 36 pôde ficar verde estando errada.

A costura é `AuthGateway`: três operações (`currentUserToken`, `signOut`, `signInAnonymously`) que falam apenas `String?`. Nenhuma devolve `User` — se devolvesse, o fake precisaria imitar outra classe do plugin e a fronteira seria nominal. `FirebaseAuthGateway` implementa a interface e traduz `FirebaseAuthException` em `AuthGatewayException`, passando a ser o único arquivo do aplicativo, fora do `main.dart`, que importa `firebase_auth`.

A refatoração foi validada pelo placar: 91 testes verdes antes, 91 depois. Costura que muda comportamento não é costura.

Só então a política mudou. O caminho normal ganhou proteção, e os dois gatilhos passaram a convergir para um único `_recoverIdentity()`. Um detalhe de Dart decide se funciona: dentro do `try`, `return await` é obrigatório — sem o `await`, o método devolve o future pendente e escapa do bloco antes da falha, e o `catch` nunca dispara.

**A terceira premissa que caiu.** As duas primeiras, da Aula 36, eram sobre o comportamento do SDK. Esta é sobre o desenho da própria política: supunha-se que "identidade inválida" sempre se manifesta como resposta do servidor. Não se manifesta. Quando a credencial não pode sequer ser trocada por um token, não há interlocutor, não há status, e qualquer política ancorada em código HTTP é cega.

Os três testes de unidade foram validados por quebra dirigida, com atribuição conferida individualmente. O terceiro — `does not recover when the current token is obtained successfully` — só tem valor por causa dos contadores do fake: uma correção que recuperasse por precaução devolveria o token correto e passaria numa asserção de valor, enquanto criaria uma conta anônima nova a cada requisição de rede.

No caminho, o teste de integração da Aula 37 revelou-se falho pelo oráculo: lia o `uid` anterior das claims do ID token, que não têm chave `uid` — o identificador vem em `user_id`/`sub`. O valor era `null`, e a asserção final comparava `String` contra `null`, passando em qualquer estado do código. Corrigido para ler de `currentUser` e reverificado por quebra.


### A pendência ficou visível na Aula 43, e apareceu um limite novo

A Aula 42 tirou a sincronização da frente do usuário e, no mesmo movimento, tornou o silêncio completo: uma falha passou a acontecer enquanto ele usa o aplicativo, sem nada na tela. A Aula 43 fecha essa lacuna pelo lado da leitura.

`CheckoutDatabase.watchHasPendingSync()` deriva um `Stream<bool>` da consulta do outbox, e `PendingSyncIndicator` o consome na tela inicial. Três decisões de desenho merecem registro.

**O widget recebe `Stream<bool>`, não o stream do Drift.** `OutboxEvent` é uma classe gerada pela camada de persistência; entregá-la à interface repetiria o vazamento que a Aula 41 corrigiu na autenticação, e obrigaria o teste de widget a construir objetos do Drift. A derivação vive no banco, e não no `main()`, por um motivo concreto: as linhas 64 a 114 do `main()` não são cobertas por teste algum, e o `distinct()` é comportamento, não fiação. Com o método no banco, um teste verifica que dois eventos enfileirados em sequência produzem **uma** emissão `true`, e removê-lo derruba esse teste.

**O indicador não vive no `CheckoutCubit`.** Os dois têm tempos de vida diferentes: o Cubit existe enquanto há uma sessão de checkout aberta; o outbox guarda intenções que podem ter nascido em outra execução. O aviso precisa aparecer na tela inicial, onde não há Cubit.

**Ele não distingue "pendente" de "sincronizando".** Depois da Aula 42, um evento na fila pode estar sendo reenviado naquele instante. Distinguir exigiria o `OutboxSynchronizer` publicar o próprio estado; a mensagem atual é verdadeira nos dois casos, e a simplificação foi aceita.

**O limite que a verificação manual revelou, e que a Aula 45 fechou:** o aviso só desaparece quando o `drain()` conclui, e até então o `drain()` rodava **uma vez, na inicialização**. Com o aplicativo aberto e a rede voltando, o indicador permanecia até o próximo lançamento. Isso vinha do desenho do outbox da Aula 27, não era regressão, e era invisível até o indicador torná-lo observável. A seção seguinte descreve como foi fechado.

A verificação foi manual, no emulador, contra as functions em produção: com um evento pendente e sem rede, o aviso aparece e permanece; com rede lenta, ele aparece na abertura e **desaparece sozinho na mesma sessão**, sem navegação nem reinício, quando o reenvio conclui. É a única prova de que o `watch()` está ligado de ponta a ponta.

### A sincronização deixou de depender da inicialização (Aula 45)

Três gatilhos passaram a existir onde havia um: a inicialização, a volta da conectividade e — em aula futura — a retomada do aplicativo. A mudança de fundo não é o gatilho novo, é o que ele obrigou a construir antes dele.

**Reentrância.** `OutboxSynchronizer` era `const` e sem estado, e isso era seguro apenas porque havia uma única chamada. Com dois gatilhos podendo chegar com milissegundos de diferença, duas drenagens leem a mesma fila e reenviam os mesmos eventos: o servidor sobrevive pela idempotência da Aula 33, mas o aparelho gasta o dobro de requisições.

A estratégia escolhida **não** foi ignorar a segunda chamada. Ignorar descarta justamente o sinal mais valioso — a rede que volta no meio de uma drenagem travada em timeout é a que teria sucesso, e a janela em rede instável vai de 8 a 25 segundos, que é exatamente quando o usuário está mexendo no wi-fi. Um pedido que chega durante uma drenagem é **marcado**, e uma passada nova acontece ao final.

O `finally` que libera o sinal é obrigatório, e essa afirmação só virou garantia quando um teste passou a cobri-la: o caso que a guarda não é o exótico, é o comum — duas drenagens separadas no tempo, que é o que cada gatilho produz na vida real.

**A instância precisa ser única.** A proteção vive em campos de instância, então dois `OutboxSynchronizer` teriam sinais independentes e voltariam a drenar em paralelo. Construir um segundo em `composeDependencies` compila e passa em quase tudo; o que o pega é um teste de composição que conta requisições com uma sobreposição deliberada entre a drenagem de inicialização e um gatilho.

**Conectividade não é conexão.** `connectivity_plus` informa que existe interface de rede ativa, não que a internet responde — um wi-fi com portal cativo reporta conectado. O gatilho é uma dica para tentar, e quem lida com a falha continua sendo a retentativa da Aula 39.

O adaptador colapsa emissões repetidas pelo **conjunto de interfaces**, e não por "há rede?". A diferença importa: uma troca de wi-fi para dados móveis mantém o booleano em `true`, e colapsá-la perderia o gatilho do usuário que abandona uma rede quebrada pelo 4G. No caminho apareceu uma armadilha do Dart — listas comparam por identidade, então `distinct()` sem comparador não colapsaria nada e o filtro pareceria existir sem existir.

**Construir e iniciar são separados.** `OutboxSyncScheduler` recebe o stream e a função de drenagem, mas só assina quando alguém chama `start()`. É isso que mantém `composeDependencies` pura, como a Aula 44 estabeleceu: a composição monta o agendador, o `main()` o inicia, ao lado do `unawaited(drain())` e do `BlocObserver`.

A verificação foi manual, contra as functions em produção: aplicativo em primeiro plano, sem rede, com o indicador visível; a rede foi religada sem nenhum toque no aparelho; cerca de catorze segundos depois o outbox esvaziou e o aviso desapareceu sozinho.

### A retomada como terceira fonte, e o que a medição mostrou (Aula 46)

`LifecycleSyncTriggers` embrulha `AppLifecycleListener` e emite em `onResume`. A composição passou a receber `Iterable<Stream<void>>` e funde as fontes com `StreamGroup.merge`, que é preguiçoso — só assina quando alguém assina o resultado, e por isso montar o grafo continua sem efeito colateral.

Fundir na composição, e não no `main()`, é o que torna a fusão verificável: um teste passa dois controllers e afirma, **entre** as emissões, que cada fonte sozinha dispara a drenagem. Contar requisições em vez de checar a fila vazia é o que fecha o buraco — com só a segunda fonte ligada, a drenagem tardia pegaria os dois eventos de uma vez e a fila esvaziaria mesmo com metade da fusão quebrada.

Duas decisões merecem registro.

**Toda retomada dispara, sem filtrar.** `AppLifecycleState.resumed` também acontece ao fechar um diálogo do sistema ou uma tela de permissão. Filtrar por "veio de `paused`" seria possível, mas em algumas plataformas diálogos passam por `hidden` e a regra fica frágil. Com a fila vazia, uma drenagem extra é uma leitura de banco; com fila cheia, é uma retentativa — que é o comportamento desejado. A reentrância da Aula 45 protege contra sobreposição.

**O Flutter valida transições de ciclo de vida.** `resumed` só pode vir de `inactive` ou `detached`, então um teste que salte de `paused` direto para `resumed` dispara asserção — e a falha aparece como "não emitiu", que é o sintoma, não a causa. O caminho válido no Android passa por `inactive` e `hidden` nos dois sentidos.

**O que a verificação manual mediu, e corrige uma suposição.** Com as duas fontes ativas, a fila esvaziou com o aplicativo em **segundo plano**, antes de ser trazido de volta: neste emulador o Android entregou a mudança de conectividade ao processo em background, e o gatilho da Aula 45 bastou. A retomada não chegou a ser exercitada.

Só um build temporário contendo apenas a fonte de ciclo de vida isolou o comportamento: com a rede religada em segundo plano, a fila permaneceu em quatro verificações consecutivas; a retomada a esvaziou, com o Android confirmando `its current task has been brought to the front` — mesmo processo, sem relançamento.

Portanto, **nas condições reproduzíveis aqui a retomada é redundante**. Ela existe para o que o emulador não reproduz: Doze, restrições agressivas de fabricante e permanência longa em segundo plano, onde a entrega do aviso de conectividade não é prometida. É rede de segurança, não caminho principal.

## Consequências

- O sistema **não** deve ser descrito como "offline-first" sem qualificação — é local-first na leitura e misto na escrita (query vs. command). A inicialização deixou de ser bloqueante na Aula 42.
- A ausência de versionamento/resolução de conflitos é uma dívida técnica latente, não visível hoje porque nenhuma das condições que a exporiam (multi-escritor, multi-dispositivo) existe no projeto atual. Qualquer trabalho futuro de sincronização multi-dispositivo precisa revisitar este ADR antes de reutilizar `insertOnConflictUpdate` como está.
- O bloqueio de `main()` no `drain()` foi resolvido na Aula 42, com `unawaited` e um `drain()` total. O silêncio que isso agravou foi endereçado na Aula 43, com o indicador de compra pendente; a dependência da inicialização caiu na Aula 45, com o gatilho de conectividade e a proteção de reentrância que ele exigiu; e a Aula 46 acrescentou a retomada do aplicativo como terceira fonte. As três cobrem o ciclo do outbox — registrar, reenviar, avisar — sem depender de ação do usuário.
- A garantia do outbox — "nenhuma intenção de compra se perde" — passou a valer contra invalidação de identidade nas duas formas: a rejeição pelo servidor (`401`, desde a Aula 36) e a impossibilidade de obter o token (desde a Aula 41). Ela continua **não** valendo se a própria recuperação falhar de forma persistente, por exemplo com o serviço de autenticação fora do ar. Nesse caso o provedor devolve `null`, a requisição sai sem header, o servidor recusa e o evento permanece na fila — comportamento desejado — mas sem nenhum sinal ao usuário de que algo está pendente.
- Nenhuma dessas garantias é verificada por teste automatizado de ponta a ponta. Os testes do interceptor usam um provedor fake, que por construção devolve uma credencial nova quando solicitado — provam que o cliente pede renovação e usa o que recebe, não que a política real funciona ponta a ponta. Desde a Aula 41 a política tem cobertura de unidade própria, com um fake de `AuthGateway`, e a Aula 37 mantém um teste de integração contra o emulador de Authentication; o que continua sem cobertura é a composição do `main()`. As premissas erradas descritas acima passaram por toda a suíte em seu tempo, e cada uma só apareceu ao rodar contra um ambiente real — duas contra os emuladores, uma contra o Firebase de produção.
