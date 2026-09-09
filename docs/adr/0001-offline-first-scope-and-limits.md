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

### Limite descoberto na Aula 35: identidade inválida trava o outbox para sempre

Com a autenticação das rotas do backend, o outbox ganhou uma forma nova de falhar permanentemente. `main()` só autentica quando não há usuário:

```dart
if (FirebaseAuth.instance.currentUser == null) {
  await FirebaseAuth.instance.signInAnonymously();
}
```

A guarda evita uma chamada de rede redundante a cada abertura, já que o Firebase Auth persiste a sessão anônima no dispositivo. Mas ela também significa que **o aplicativo nunca se reautentica quando a credencial guardada deixa de valer**. Isso acontece quando a conta anônima é excluída ou desativada no console, ou quando o refresh token é revogado.

Nesse estado, todas as chamadas ao backend recebem `401`, que o `NetworkFailure` classifica como `PermanentFailure`. O efeito sobre o outbox é o pior possível: o evento pendente é reenviado a cada inicialização, rejeitado a cada vez, e permanece na fila indefinidamente. Diferente de uma falha de rede, essa não se resolve sozinha com o tempo — o app fica em loop silencioso, sem sinal na interface, e o checkout do usuário nunca chega ao servidor.

O comportamento foi observado durante a validação da Aula 35, quando o emulador de Authentication foi reiniciado (ele guarda usuários em memória) enquanto o aplicativo mantinha a credencial em cache. Removendo apenas a credencial persistida e preservando o outbox, o aplicativo criou um usuário novo na inicialização seguinte, o reenvio passou e a fila esvaziou — confirmando o diagnóstico.

A correção não foi feita nesta aula. O caminho seria tratar `401` como sinal de que a identidade precisa ser renovada, e não como recusa definitiva: reautenticar e tentar de novo, em vez de contabilizar como falha permanente.

## Consequências

- O sistema **não** deve ser descrito como "offline-first" sem qualificação — é local-first na leitura, misto na escrita (query vs. command), e bloqueante na inicialização por causa do `drain()`.
- A ausência de versionamento/resolução de conflitos é uma dívida técnica latente, não visível hoje porque nenhuma das condições que a exporiam (multi-escritor, multi-dispositivo) existe no projeto atual. Qualquer trabalho futuro de sincronização multi-dispositivo precisa revisitar este ADR antes de reutilizar `insertOnConflictUpdate` como está.
- O bloqueio de `main()` no `drain()` é uma dívida técnica reconhecida e registrada aqui deliberadamente, para não ser esquecida nem redescoberta do zero numa aula futura. Corrigi-la (ex.: chamar `drain()` sem `await` antes de `runApp`, deixando-a rodar em segundo plano) fica fora do escopo desta aula.
- A garantia do outbox — "nenhuma intenção de compra se perde" — vale contra falhas de rede, mas **não** contra invalidação de identidade. Enquanto `401` for tratado como falha permanente e o aplicativo não se reautenticar, existe um caminho em que o evento fica preso para sempre. Esta é a dívida mais séria registrada neste ADR, porque as demais degradam a experiência enquanto esta perde silenciosamente um checkout.
