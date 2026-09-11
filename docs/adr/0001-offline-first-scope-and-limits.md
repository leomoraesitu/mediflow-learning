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

### Limite conhecido e aceito: inicialização bloqueada pelo outbox

`main()` chama `await synchronizer.drain()` antes de `runApp()` — a primeira tela do app espera a tentativa de reenvio do outbox resolver (ou falhar) antes de aparecer. Isso contradiz o espírito offline-first (mostrar a UI imediatamente a partir do estado local, sincronizar em segundo plano sem bloquear). Foi assim que o `OutboxSynchronizer` foi conectado nesta sessão de estudo, e a inconsistência foi identificada nesta discussão, não corrigida — decisão explícita de manter o escopo da Aula 28 em discussão, não em implementação.

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


## Consequências

- O sistema **não** deve ser descrito como "offline-first" sem qualificação — é local-first na leitura, misto na escrita (query vs. command), e bloqueante na inicialização por causa do `drain()`.
- A ausência de versionamento/resolução de conflitos é uma dívida técnica latente, não visível hoje porque nenhuma das condições que a exporiam (multi-escritor, multi-dispositivo) existe no projeto atual. Qualquer trabalho futuro de sincronização multi-dispositivo precisa revisitar este ADR antes de reutilizar `insertOnConflictUpdate` como está.
- O bloqueio de `main()` no `drain()` é uma dívida técnica reconhecida e registrada aqui deliberadamente, para não ser esquecida nem redescoberta do zero numa aula futura. Corrigi-la (ex.: chamar `drain()` sem `await` antes de `runApp`, deixando-a rodar em segundo plano) fica fora do escopo desta aula.
- A garantia do outbox — "nenhuma intenção de compra se perde" — passou a valer contra invalidação de identidade nas duas formas: a rejeição pelo servidor (`401`, desde a Aula 36) e a impossibilidade de obter o token (desde a Aula 41). Ela continua **não** valendo se a própria recuperação falhar de forma persistente, por exemplo com o serviço de autenticação fora do ar. Nesse caso o provedor devolve `null`, a requisição sai sem header, o servidor recusa e o evento permanece na fila — comportamento desejado — mas sem nenhum sinal ao usuário de que algo está pendente.
- Nenhuma dessas garantias é verificada por teste automatizado de ponta a ponta. Os testes do interceptor usam um provedor fake, que por construção devolve uma credencial nova quando solicitado — provam que o cliente pede renovação e usa o que recebe, não que a política real funciona ponta a ponta. Desde a Aula 41 a política tem cobertura de unidade própria, com um fake de `AuthGateway`, e a Aula 37 mantém um teste de integração contra o emulador de Authentication; o que continua sem cobertura é a composição do `main()`. As premissas erradas descritas acima passaram por toda a suíte em seu tempo, e cada uma só apareceu ao rodar contra um ambiente real — duas contra os emuladores, uma contra o Firebase de produção.
