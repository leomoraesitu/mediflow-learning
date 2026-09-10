# Functions

Backend sintético do MediFlow, em TypeScript sobre Cloud Functions (2ª geração). Não participa do Pub Workspace: é um projeto Node isolado, com suas próprias dependências e ciclo de build.

## Estado atual

Uma única function HTTP (`api`) expõe um app Express com as quatro rotas que os repositórios Dio do aplicativo (`DioPrescriptionRepository`, `DioMedicationRepository`, `DioCheckoutRepository`) já esperavam desde a Aula 22:

| Rota | Corpo / parâmetro | Resposta |
| --- | --- | --- |
| `POST /prescriptions/validate` | `{ reference }` | `{ isValid: true }` |
| `GET /medications/:ean/eligibility` | — | `{ isEligible: true }` |
| `POST /checkouts` | sessão + header `Idempotency-Key` | `{ id }`, ou `404` se a chave pertence a outro usuário |
| `GET /checkouts/:remoteCheckoutId` | — | sessão completa com `status`, ou `404` se o checkout é de outro usuário |

Agrupar as quatro rotas em uma única function com Express, em vez de quatro functions separadas, é o padrão recomendado pela documentação oficial para APIs HTTP com várias rotas e parâmetros de caminho.

As duas primeiras rotas replicam exatamente o comportamento determinístico de `DemoPrescriptionRepository` e `DemoMedicationRepository`: sempre aprovam. A validação de `reference` existe apenas para que uma requisição malformada receba `400` em vez de um falso positivo.

### Idempotência e persistência

`DemoCheckoutRepository`, no app, guarda o checkout criado em uma variável de instância. Uma Cloud Function não pode fazer o mesmo: cada invocação pode cair em uma instância diferente, e instâncias são recicladas sem aviso. Por isso o estado vive no Firestore, na coleção `checkouts`.

O ponto central desta aula está em `POST /checkouts`: **o `Idempotency-Key` recebido é usado como identificador do documento**, não como um campo qualquer gravado dentro dele. Uma retentativa com a mesma chave encontra o documento existente e devolve o mesmo `id` com `200`, em vez de criar um segundo checkout com `201`. Sem isso, o ciclo de outbox construído nas Aulas 23 a 27 (que reenvia a mesma chave quando a resposta se perde) duplicaria a cobrança justamente no cenário que ele existe para evitar.

Usar a chave como identificador do documento, em vez de consultar por um campo indexado, também elimina a janela de corrida entre a consulta e a escrita: no Firestore, a escrita em um documento identificado é atômica.

`GET /checkouts/:id` devolve a sessão gravada, mas sempre com `status: "paid"` — espelhando `DemoCheckoutRepository.getById`, que confirma o pagamento na consulta. É ficção determinística: não há gateway de pagamento. O literal precisa corresponder exatamente a um nome do enum `CheckoutStatus` do pacote `checkout_domain`, porque `_parseCheckoutSession`, no app, rejeita qualquer valor fora dele.

O Admin SDK ignora as regras de segurança do Firestore, então `firestore.rules` (na raiz do repositório) nega todo acesso direto de clientes: nenhum app fala com o Firestore sem passar por estas functions.

### Autenticação

Desde a Aula 35, um middleware `requireAuth` protege **todas** as rotas. Ele exige o header `Authorization` no formato `Bearer <token>`, valida o token com `admin.auth().verifyIdToken(...)` e devolve `401` quando ele falta, está malformado ou é rejeitado. O resultado decodificado vai para `res.locals.user`, e não para `req.body`, que pertence aos dados enviados pelo cliente.

O posicionamento é o que define o alcance: `app.use(requireAuth)` vem depois de `express.json()` e antes da primeira rota, então tudo registrado a seguir fica protegido automaticamente. Registrar a verificação como um `app.get(caminho, ...)` adicional não funcionaria — o Express casa a primeira rota correspondente, que responde e nunca chega no segundo handler.

Proteger também `validate` e `eligibility`, que hoje sempre respondem `true`, é deliberado. A aparente inocuidade é um acidente da implementação fictícia: numa versão real elas consultam dados de benefício de uma pessoa, e um endpoint aberto que responde sobre elegibilidade é um vazamento. Deixar exceções abertas também cria uma pendência que alguém precisa lembrar de fechar depois.

Quando as functions rodam sob o emulador, o Admin SDK detecta a variável `FIREBASE_AUTH_EMULATOR_HOST` e valida contra o emulador de Authentication em vez do Firebase real, sem configuração adicional. Por isso o aplicativo também precisa apontar para esse emulador, ou os dois estarão validando identidades de mundos diferentes.

### Autorização

Autenticar responde "quem é você"; autorizar responde "o que você pode". Até a Aula 38 o backend só fazia a primeira: o `res.locals.user` preenchido pelo middleware nunca era lido por rota alguma, e qualquer usuário anônimo válido acessava o checkout de qualquer outro.

`POST /checkouts` passou a gravar o `uid` do criador no documento, e `GET /checkouts/:id` só entrega a quem gravou. A resposta **não** inclui esse campo: quem pede já sabe quem é, e expor o identificador interno sem que ninguém precise dele é custo sem ganho. O teste `keeps the request body intact after authentication` funciona como guardião permanente disso, porque compara a resposta com o payload enviado usando igualdade estrita.

Duas decisões merecem registro por não serem óbvias.

**`404` em vez de `403` para recurso alheio.** Responder `403` confirmaria que aquele checkout existe, permitindo a alguém enumerar identificadores e descobrir quais são válidos. `404` esconde a existência. É a escolha certa para segurança e ruim para depuração — quem investiga um problema legítimo recebe a mesma resposta de quem tenta acesso indevido.

**O atalho de idempotência também precisa autorizar.** Este é o furo menos evidente. A otimização construída na Aula 33 devolve `200` com o identificador existente quando a chave já foi usada; sem verificação de dono, enviar a chave de outra pessoa entregaria o `remoteCheckoutId` dela, e o remetente passaria a operar sobre um recurso que não é seu. A verificação vive nos dois caminhos: na leitura e na deduplicação.

O comportamento para documentos sem dono é **falhar fechado**: um documento sem dados, ou gravado antes desta aula e portanto sem `userId`, é tratado como inexistente. Isso torna inacessíveis os checkouts fictícios das aulas anteriores, o que aqui é irrelevante, mas num sistema real exigiria migração antes da mudança.

A autorização é por propriedade e nada mais. Não há papéis, permissões nem hierarquia — um operador de farmácia não tem acesso diferenciado, porque esse conceito ainda não existe no projeto.

### Escala e custo

`setGlobalOptions({maxInstances: 5})`, no topo de `src/index.ts`, limita quantas instâncias podem existir ao mesmo tempo. Com a `concurrency` padrão da 2ª geração (80 requisições por instância), o teto cobre a demanda real deste projeto com folga de várias ordens de grandeza — ele não existe para dimensionar capacidade, e sim para limitar o alcance de um defeito. Um laço acidental esbarra numa parede em vez de escalar livremente.

O valor não foi escolhido por cálculo de tráfego, mas pelo menor número que nunca é atingido em operação legítima. Mais de uma instância pode coexistir durante um deploy (a revisão nova sobe enquanto a antiga drena), durante a reciclagem que a plataforma faz sem aviso, e num cold start sob rajada. São poucas, não dezenas. Um teto de 1 seria apertado demais: ele passaria a ser atingido nessas transições normais, e a retentativa automática do cliente absorveria o resultado em silêncio — um defeito de configuração mascarado por uma política de resiliência.

`minInstances` é deliberadamente **omitido**. Ele elimina cold start mantendo instâncias vivas, e a documentação do pacote é explícita: instâncias ociosas são cobradas por memória alocada e 10% da CPU. É a única forma de este projeto gerar custo sem tráfego nenhum.

`setGlobalOptions` devolve `void` — ela age por efeito colateral sobre um estado global do SDK que `onRequest` consulta depois. Atribuir seu retorno a uma constante compila, mas quebra o lint, e o `predeploy` interrompe o deploy antes do upload.

## Requisitos

- Node 24 ou superior (`engines` do `package.json` declara `24`; o emulador avisa se a versão global diferir, mas funciona).
- **Java** — obrigatório para o emulador do Firestore, que roda sobre a JVM. Sem ele, `firebase emulators:start` falha com `Process 'java -version' has exited with code 1`.

Atenção a uma armadilha do macOS: existe um stub em `/usr/bin/java` que apenas informa não encontrar um runtime. Como o `path_helper` do sistema coloca `/usr/bin` à frente do PATH em shells de login, um JDK instalado via Homebrew precisa ser exportado no `.zprofile` (não só no `.zshrc`) para vencer o stub.

## Execução

```bash
cd functions
npm install
npm run build

cd ..
firebase emulators:start --only auth,functions,firestore
```

A function fica em `http://127.0.0.1:5001/mediflow-learning/us-central1/api` e a interface dos emuladores em `http://127.0.0.1:4000`.

## Deploy

Requer o plano Blaze. Três coisas que o emulador oferecia de graça precisam existir no projeto real, e a ausência de qualquer uma delas produz um sintoma que parece defeito de código:

| Pré-requisito | O que acontece sem ele |
| --- | --- |
| Cloud Firestore API habilitada e banco provisionado | O deploy conclui, e a primeira escrita falha |
| Provedor de login **Anônimo** ativado | `signInAnonymously()` falha, o token não é enviado e tudo responde `401` |
| Política de limpeza do Artifact Registry | Imagens de container acumulam cobrando armazenamento |

O banco padrão deste projeto é regional em `us-central1`, mesma região das functions — operações do Admin SDK acontecem dentro do datacenter em vez de atravessar rede. A escolha é permanente e foi feita contra o padrão do console, que oferece a multirregião `nam5`: replicação por várias regiões dos EUA, com preço e latência de escrita maiores, para uma garantia de disponibilidade que este projeto não precisa.

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
```

Nesta ordem: as regras primeiro, para que não exista janela em que o banco responde com uma configuração que não é a versionada.

Os hooks `predeploy` do `firebase.json` executam `npm run lint` e `npm run build` antes do upload. É o portão que impede que código que não compila — ou que não passa no lint — chegue a produção.

Antes de publicar, vale apagar `lib/` e reconstruir. A lista `ignore` do `firebase.json` exclui `node_modules` e logs, mas **não** exclui `lib/`, que é justamente o que precisa subir. Qualquer arquivo esquecido ali embarca no pacote, e `lib/` está no `.gitignore` — um `lib/index.test.js` órfão de uma compilação antiga não apareceria em nenhum `git diff`.

As dependências **não** sobem. O que é enviado é o código compilado mais o `package.json`, e o build container executa `npm install` no ambiente de produção. Isso resolve pacotes com binários nativos para a arquitetura certa, mas significa que o servidor resolve os ranges `^` do `package.json` no momento do build, e não as versões exatas que os testes locais aprovaram. Não há `package-lock.json` versionado; adicioná-lo fecharia essa fresta.

A URL da function publicada é `https://us-central1-mediflow-learning.cloudfunctions.net/api`.

## Validação

```bash
cd functions
npm run build
npm run lint
npm test
```

O resultado esperado é compilação limpa, análise estática sem problemas e 15 testes aprovados.

Os testes usam `supertest` para chamar o app Express diretamente em memória, com um fake do Firestore substituindo `firebase-admin` via `jest.mock`. Não dependem de nenhum emulador em execução, o que os mantém rápidos e reproduzíveis em qualquer máquina. Dois casos concentram o valor da suíte. O da retentativa: duas chamadas a `POST /checkouts` com a mesma `Idempotency-Key` devem devolver `201` e depois `200`, com o mesmo `id`. E o que dispara uma requisição sem token para **cada uma das quatro rotas** e exige `401` em todas — foi ele que teria pego a primeira versão do middleware, que protegia apenas uma rota. Um terceiro caso verifica que o corpo da requisição sobrevive à autenticação, protegendo contra uma versão anterior que sobrescrevia `req.body` com as claims do token.

O comportamento também foi verificado manualmente contra o emulador real, com Firestore de verdade, confirmando que a segunda tentativa não cria um segundo documento na coleção.

## Separação entre os dois `tsconfig`

`tsconfig.json` descreve o que vai para produção: compila apenas `src/`, emite para `lib/` e **exclui os arquivos `*.test.ts`**, para que o build de deploy não tente compilar testes nem exija `jest` e `supertest`, que são dependências de desenvolvimento.

`tsconfig.dev.json` cobre o que existe só para ferramental — `.eslintrc.js`, `jest.config.js` e os próprios testes. O ESLint aponta para os dois (`parserOptions.project`), então cada arquivo do projeto pertence a exatamente um deles. O Jest ignora essa divisão: ele decide o que testar pela própria configuração, não pelo `include` do TypeScript.

## Referências oficiais

- [Cloud Functions para Firebase (2ª geração)](https://firebase.google.com/docs/functions/get-started?gen=2nd)
- [Functions HTTP](https://firebase.google.com/docs/functions/http-events?gen=2nd)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Testar functions localmente](https://firebase.google.com/docs/functions/local-emulator?gen=2nd)
- [Admin SDK e Firestore](https://firebase.google.com/docs/firestore/quickstart#node.js)
- [Regras de segurança do Firestore](https://firebase.google.com/docs/firestore/security/get-started)
- [Verificar tokens de ID no backend](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [OWASP: Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control/)
- [Emulador de Authentication](https://firebase.google.com/docs/emulator-suite/connect_auth)
