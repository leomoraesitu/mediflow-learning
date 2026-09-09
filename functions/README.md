# Functions

Backend sintético do MediFlow, em TypeScript sobre Cloud Functions (2ª geração). Não participa do Pub Workspace: é um projeto Node isolado, com suas próprias dependências e ciclo de build.

## Estado atual

Uma única function HTTP (`api`) expõe um app Express com as quatro rotas que os repositórios Dio do aplicativo (`DioPrescriptionRepository`, `DioMedicationRepository`, `DioCheckoutRepository`) já esperavam desde a Aula 22:

| Rota | Corpo / parâmetro | Resposta |
| --- | --- | --- |
| `POST /prescriptions/validate` | `{ reference }` | `{ isValid: true }` |
| `GET /medications/:ean/eligibility` | — | `{ isEligible: true }` |
| `POST /checkouts` | sessão + header `Idempotency-Key` | `{ id }` |
| `GET /checkouts/:remoteCheckoutId` | — | sessão completa com `status` |

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

## Validação

```bash
cd functions
npm run build
npm run lint
npm test
```

O resultado esperado é compilação limpa, análise estática sem problemas e 13 testes aprovados.

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
- [Emulador de Authentication](https://firebase.google.com/docs/emulator-suite/connect_auth)
