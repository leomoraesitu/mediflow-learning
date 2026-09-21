<p align="left">
  <img src="docs/assets/logo.svg" alt="" width="80" height="80">
</p>

# MediFlow Learning

Repositório público do MediFlow Learning, um projeto educacional independente sobre um checkout de medicamentos resiliente. O desenvolvimento acontece de forma incremental, aula por aula, para exercitar Dart, Flutter, testes, arquitetura, resiliência e observabilidade e permitir o acompanhamento público dessa evolução.

Este repositório utiliza identidade visual própria, não representa uma parceria comercial e não deve ser interpretado como um produto clínico ou financeiro real.

Como todo o conteúdo é público, exemplos, fixtures, logs e configurações devem utilizar somente dados fictícios. Credenciais, tokens, chaves, dados pessoais, informações médicas reais e outros segredos não devem ser adicionados ao repositório.

## Baseline do curso

- Flutter 3.47.1, canal `stable`
- Dart 3.13.1

As versões formam a baseline atual do curso. Atualizações serão feitas de maneira intencional e registradas, sem mudanças silenciosas durante um módulo.

## Estrutura do monorepo

```text
mediflow-learning/
├── apps/
│   ├── mobile/
│   └── ops_web/
├── packages/
│   └── checkout_domain/
├── functions/
├── docs/
├── pubspec.yaml
└── pubspec.lock
```

| Diretório | Responsabilidade |
| --- | --- |
| `apps/mobile` | Aplicativo Flutter Android e futuro fluxo principal do Modo Farmácia. |
| `apps/ops_web` | Painel operacional Flutter Web somente leitura. **Ainda não construído** — existe apenas como diretório e README. |
| `packages/checkout_domain` | Modelos, regras e transições do checkout em Dart puro, compartilháveis entre os clientes. |
| `functions` | Backend sintético e contratos REST. Possui ciclo de ferramentas próprio e não participa do Pub Workspace. |
| `docs` | Decisões arquiteturais, contratos, diagramas e documentação do projeto. |

## Pub Workspace

O monorepo usa [Pub Workspaces](https://dart.dev/tools/pub/workspaces) para manter uma única resolução compartilhada de dependências, um único `pubspec.lock` na raiz e um único `package_config.json` gerado em `.dart_tool`.

Neste momento, `apps/mobile` e `packages/checkout_domain` participam do workspace. Cada novo aplicativo Dart ou Flutter será incluído explicitamente quando for criado e deverá declarar `resolution: workspace` em seu próprio `pubspec.yaml`.

O package `checkout_domain` permanecerá independente de Flutter, Firebase, Dio e Drift. Essa fronteira permite testar as regras do checkout rapidamente e reutilizá-las em mais de um cliente, seguindo a separação de responsabilidades discutida no [guia oficial de arquitetura do Flutter](https://docs.flutter.dev/app-architecture/guide).

## Estado atual

> Esta seção descreve o repositório **até a Aula 59**. O registro aula a aula — com o raciocínio, as medições e os defeitos encontrados no caminho — fica no README de cada pacote: [`apps/mobile`](apps/mobile/README.md), [`packages/checkout_domain`](packages/checkout_domain/README.md), [`functions`](functions/README.md). As decisões de arquitetura ficam em [`docs/adr`](docs/README.md).

O aplicativo abre num portão de autenticação. Com conta, mostra uma tela de benefícios com saldo fictício e dá entrada no “Modo Farmácia”, um checkout de quatro etapas: ler o medicamento, validar a receita, verificar elegibilidade e confirmar o pagamento. O fluxo funciona sem rede — uma compra iniciada offline fica registrada e é reenviada sozinha quando a conexão volta, sem cobrar duas vezes.

### Domínio

`packages/checkout_domain` é Dart puro, sem Flutter, Firebase, Dio ou Drift — e um teste de fronteira impede que isso mude. Dentro dele, uma máquina de estados transforma uma sessão e um evento num novo snapshot imutável; transições inválidas são rejeitadas por exceção em vez de produzirem estado inconsistente. Os estados terminais são classificados por `switch` exaustivo, então acrescentar um status novo quebra a compilação em vez de cair num caso silencioso.

### Backend

`functions/` é um backend próprio em Cloud Functions, publicado, que grava `userId` em cada checkout e verifica propriedade na leitura. Um checkout de outra pessoa responde **404, não 403** — quem não é dono não descobre sequer que o recurso existe. A criação é idempotente pela `Idempotency-Key`: a mesma chave encontra o documento existente e devolve o mesmo `id` em vez de cobrar de novo.

### Offline-first, com o escopo declarado

O aplicativo lê do SQLite local e escreve por um outbox: a intenção de compra é gravada antes de sair para a rede, e um sincronizador a reenvia. Três gatilhos alimentam o reenvio — inicialização, volta da conectividade e retomada do aplicativo —, e um indicador reativo mostra ao usuário que há algo pendente.

O que isso **não** é está escrito por extenso na [ADR 0001](docs/adr/0001-offline-first-scope-and-limits.md), junto com as premissas que caíram ao longo do caminho: o sistema é local-first na leitura e misto na escrita, não há versionamento nem resolução de conflitos, e a garantia do outbox tem limites conhecidos.

### Multi-usuário

Autenticação por e-mail e senha, com as mensagens do Firebase traduzidas por uma tabela própria — conta inexistente e senha errada produzem a mesma resposta, que é a proteção contra enumeração espelhando o 404 do backend.

O banco local é escopado por usuário desde a migração Drift v2 → v3: sessão e outbox carregam `userId`, e todas as consultas filtram por dono. Sair **preserva** a fila de quem saiu, e o sincronizador recusa drenar sem sessão — as duas decisões estão registradas, porque a alternativa de cada uma perde compra registrada offline ou envia evento de um usuário com o token de outro.

### Apresentação

O Cubit é o ViewModel e emite um estado de visão próprio, não o tipo de domínio: a tela recebe `canConfirmPayment`, não `status`, e não importa `checkout_domain`. O feedback é uma hierarquia `sealed` renderizada por `switch` exaustivo. A fronteira e o que ela não alcançou estão na [ADR 0002](docs/adr/0002-presentation-layer-boundary.md).

### Design system

Material 3 derivado de uma semente, nos temas claro e escuro — o escuro não inverte cores, rederiva cada papel a partir da mesma semente. Os botões têm hierarquia, e quem decide qual ação é a primária é o estado de visão, não a tela. O Android tem rótulo e ícone adaptativo próprios.

A [ADR 0003](docs/adr/0003-design-system-and-visual-verification.md) registra as decisões e, principalmente, o alcance medido de cada instrumento de verificação visual — o que um golden pega, o que uma diretriz de contraste pega, e o que nenhum dos dois pega.

### Observabilidade

Rastros de performance, eventos de analytics e relatório de falhas passam por interfaces do próprio aplicativo, com o Firebase atrás delas. É essa costura que permite montar o grafo de dependências inteiro num teste, sem dispositivo.

### Verificação

| Pacote | Testes |
| --- | --- |
| `apps/mobile` | 224 |
| `packages/checkout_domain` | 26 |
| `functions` | 15 |

Três deles são goldens, e há um teste de acessibilidade que percorre duas telas nos dois temas. Um teste de integração contra o emulador de Authentication roda à mão, fora da CI.

O método recorrente do projeto é a **quebra dirigida**: antes de confiar num teste, sabotar de propósito o código que ele deveria proteger e confirmar que ele fica vermelho — e que fica vermelho *pelo motivo do seu próprio nome*. Vários testes deste repositório mudaram de forma depois de sobreviverem a uma sabotagem que deveriam ter pegado.

### O que ainda não existe

- `apps/ops_web`, o painel operacional, existe como diretório e README. Não foi construído.
- Não há responsividade por breakpoint nem cobertura de fonte ampliada.
- O ícone legado (Android 7 e anterior) continua sendo o padrão do Flutter; as APIs 24 e 25 caem nele.

## Limites do projeto

- Todos os saldos, receitas, medicamentos, pagamentos, eventos e métricas serão fictícios.
- Não haverá Pix real, dados pessoais, dados médicos reais ou OCR clínico.
- O projeto terá marca própria e não alegará vínculo com empresas ou serviços reais.
- O backend e as integrações externas existirão apenas para demonstração e aprendizado.

## Integração contínua

`.github/workflows/quality-gate.yml` roda a cada pull request e a cada push no `main`. Dois jobs em paralelo:

| Job | Cobre | Etapas |
| --- | --- | --- |
| `dart` | `apps/mobile` + `packages/checkout_domain` | formatação, análise estática e testes dos dois pacotes |
| `functions` | `functions/` | `npm ci`, lint, compilação e testes |

Os dois são **checks obrigatórios** na proteção do `main`, junto com a exigência de pull request. Nada entra sem os dois verdes.

### As decisões que o arquivo não explica sozinho

**Dois jobs, não três.** `apps/mobile` e `packages/checkout_domain` compartilham o Pub Workspace: uma resolução de dependências serve aos dois. Separá-los custaria uma instalação do Flutter a mais para ganhar nada — os testes do domínio levam menos de um segundo. A divisão segue a toolchain, não o diretório.

**Em paralelo** porque o tempo é dominado por instalação de ferramenta, não por teste, e porque a informação útil quando algo quebra não é "algo quebrou", é "o backend quebrou e o app não".

**Sem filtros de caminho.** Um job pulado deixa o check pendente, e a exigência de status check travaria o merge indefinidamente. Com suítes que somam segundos, não há economia que justifique o risco.

**Versão do Flutter fixa** (`3.47.1`), não `stable`: uma CI que muda de comportamento sem commit quebra por um motivo que não está em lugar nenhum. É o mesmo raciocínio do `package-lock.json` das functions.

**`npm ci`, não `npm install`** — falha se o lockfile divergir do `package.json`, que é a garantia de build reprodutível descrita em `functions/README.md`.

**Sem exigência de aprovação.** O GitHub não permite que o autor aprove o próprio pull request; num repositório de uma pessoa, exigir uma aprovação bloquearia todo merge e transformaria o override de administrador em hábito — e o hábito de contornar o portão também é usado no dia em que ele está legitimamente vermelho.

### O que a CI não roda

`apps/mobile/integration_test/identity_recovery_test.dart` exige o emulador de Authentication no ar e um dispositivo conectado. Rodá-lo na CI daria verde sem exercitar nada. Ele continua sendo executado à mão, e o `apps/mobile/README.md` descreve como.

A verificação manual contra as functions em produção — emulador Android, rede desligada e religada — também continua fora, pelo mesmo motivo.

### Como o portão foi verificado

Com uma quebra deliberada, na mesma disciplina usada para os testes do projeto: um commit estragou a formatação no mobile e usou aspas simples nas functions, proibidas pelo `eslint-config-google`. O job `dart` parou na etapa de formatação e o `functions` na de lint, cada um no ponto correspondente ao defeito. O histórico da branch registra verde, vermelho e verde.

Uma CI nunca testada é uma CI que ninguém sabe se funciona.

## Validação local

A CI é o portão, mas rodar antes de abrir o PR evita o ciclo de esperar o runner. Na raiz do repositório:

```bash
dart format --output=none --set-exit-if-changed \
  apps/mobile/lib apps/mobile/test apps/mobile/integration_test \
  packages/checkout_domain/lib packages/checkout_domain/test

cd apps/mobile && flutter analyze && flutter test && cd ../..
cd packages/checkout_domain && dart analyze && dart test && cd ../..
cd functions && npm run lint && npm run build && npm test && cd ..

git diff --check
git status --short
```

O resultado esperado é formatação e análise limpas, **224 testes** em `apps/mobile`, **26** em `packages/checkout_domain`, **15** em `functions`, e somente alterações intencionais exibidas pelo Git.

Três desses testes são goldens, que comparam a renderização de uma tela com imagens versionadas — duas da tela de benefícios e uma da tela de entrada no tema escuro. Eles toleram até 3% de diferença de pixels, porque a renderização do macOS e a do Linux da CI divergem em cerca de 1,5%. Essa tolerância tem um preço medido: ela pega mudança de cor em área grande e movimento de bloco, e **não** pega borda de 1px nem texto fino. O `apps/mobile/README.md` registra os números e o que a troca custa.

Os READMEs de cada projeto detalham o que cada suíte cobre.

## Referências oficiais

- [Dart](https://dart.dev/)
- [Flutter](https://docs.flutter.dev/)
- [Pub.dev](https://pub.dev/)
- [Pub Workspaces](https://dart.dev/tools/pub/workspaces)
- [Guia de arquitetura do Flutter](https://docs.flutter.dev/app-architecture/guide)
- [Comunicação entre camadas e injeção de dependência](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [Documentação do Drift](https://drift.simonbinder.eu/)
- [`drift_flutter`](https://pub.dev/packages/drift_flutter)
- [Temas no Flutter](https://docs.flutter.dev/cookbook/design/themes)
- [Entendendo constraints](https://docs.flutter.dev/ui/layout/constraints)
- [Abordagem geral para aplicativos adaptáveis](https://docs.flutter.dev/ui/adaptive-responsive/general)
- [`SafeArea`](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)
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
- [Modificadores de classes em Dart](https://dart.dev/language/class-modifiers)
- [Enums em Dart](https://dart.dev/language/enums)
- [`dart:convert`](https://api.dart.dev/dart-convert/)
- [Branches em Dart](https://dart.dev/language/branches)
- [Patterns em Dart](https://dart.dev/language/patterns)
- [Tratamento de erros em Dart](https://dart.dev/language/error-handling)
- [Testes em Dart](https://dart.dev/libraries/testing)
- [Package `test`](https://pub.dev/packages/test)
- [`flutter_bloc`](https://pub.dev/packages/flutter_bloc)
- [`bloc_test`](https://pub.dev/packages/bloc_test)
- [`List.unmodifiable`](https://api.dart.dev/dart-core/List/List.unmodifiable.html)
- [`Isolate.resolvePackageUri`](https://api.dart.dev/dart-isolate/Isolate/resolvePackageUri.html)
