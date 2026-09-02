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
| `apps/ops_web` | Painel operacional Flutter Web somente leitura. Será criado na Aula 36. |
| `packages/checkout_domain` | Modelos, regras e transições do checkout em Dart puro, compartilháveis entre os clientes. |
| `functions` | Backend sintético e contratos REST. Possui ciclo de ferramentas próprio e não participa do Pub Workspace. |
| `docs` | Decisões arquiteturais, contratos, diagramas e documentação do projeto. |

## Pub Workspace

O monorepo usa [Pub Workspaces](https://dart.dev/tools/pub/workspaces) para manter uma única resolução compartilhada de dependências, um único `pubspec.lock` na raiz e um único `package_config.json` gerado em `.dart_tool`.

Neste momento, `apps/mobile` e `packages/checkout_domain` participam do workspace. Cada novo aplicativo Dart ou Flutter será incluído explicitamente quando for criado e deverá declarar `resolution: workspace` em seu próprio `pubspec.yaml`.

O package `checkout_domain` permanecerá independente de Flutter, Firebase, Dio e Drift. Essa fronteira permite testar as regras do checkout rapidamente e reutilizá-las em mais de um cliente, seguindo a separação de responsabilidades discutida no [guia oficial de arquitetura do Flutter](https://docs.flutter.dev/app-architecture/guide).

## Estado atual

Até a Aula 25, a infraestrutura inicial do monorepo, a primeira interação com estado local, a base visual, os primeiros requisitos de acessibilidade, a navegação inicial, a entrada validada, os modelos fundamentais, a máquina de estados, os contratos de repositório, a integração do estado do checkout com a interface, os primeiros efeitos reativos, o progresso derivado da sessão, os feedbacks de falha e sucesso e as ações de avanço do checkout foram criados:

- repositório e branch de trabalho configurados;
- diretórios de mobile, painel, domínio, backend e documentação definidos;
- Pub Workspace configurado para o aplicativo mobile e o package de domínio;
- fronteira de dependências do domínio protegida por testes;
- resolução e lockfile compartilhados na raiz;
- scaffold Flutter Android criado em `apps/mobile`;
- primeira árvore de widgets executada e validada em um emulador Android;
- `PharmacyModePage` mantida como `StatefulWidget` para coordenar o formulário, os controllers e o ciclo de vida da rota;
- apresentação extraída para o `StatelessWidget` `MedicationCounterContent`;
- fluxo de dados unidirecional exercitado com `count` descendo para o filho e `onScan` retornando como callback;
- reconstruções e métodos `initState`, `build` e `dispose` instrumentados com logs;
- hot reload e hot restart verificados durante o desenvolvimento;
- tema Material 3 centralizado em `AppTheme`, com um `ColorScheme` derivado da cor-base própria do MediFlow;
- cores e estilos tipográficos consumidos pela árvore por meio de `Theme.of(context)`;
- escala de espaçamento definida em `AppSpacing`, evitando valores de layout dispersos;
- componente reutilizável `MediFlowContentCard` criado para padronizar margem, padding e apresentação;
- largura do conteúdo limitada a 480 pixels lógicos, preservando o aproveitamento de telas estreitas e evitando expansão excessiva em telas largas;
- rolagem vertical de segurança e respeito às áreas ocupadas por recortes, barras e gestos do sistema;
- layout validado no emulador Android nas orientações retrato e paisagem, sem overflow;
- contador exposto às tecnologias assistivas com rótulo estável, valor dinâmico e anúncio de mudanças por meio de `Semantics`;
- semântica visual duplicada removida do contador com `ExcludeSemantics`;
- alvo mínimo de 48 por 48 pixels lógicos aplicado globalmente aos botões elevados;
- interface validada manualmente com fonte ampliada em retrato e paisagem, mantendo conteúdo, contador e botão alcançáveis;
- teste de widget verificando alvo de toque Android, rótulos dos controles e contraste textual com a Accessibility Guideline API do Flutter;
- tela inicial `BenefitsHomePage` criada com saldo fictício de R$ 250,00 e entrada explícita no Modo Farmácia;
- navegação imperativa implementada com `Navigator.push`, `MaterialPageRoute<void>` e retorno pela pilha de rotas;
- remoção de `PharmacyModePage` validada pela seta da `AppBar` e pelo retorno do Android, com descarte do estado local em `dispose`;
- indicador reutilizável `CheckoutProgressIndicator` criado com quatro marcadores e `LinearProgressIndicator` determinístico em 25% na primeira etapa;
- progresso consolidado em um único nó semântico, com rótulo e valor compreensíveis e sem anúncios duplicados dos elementos visuais;
- testes de widget cobrindo a tela inicial, a abertura do Modo Farmácia, o retorno à tela de benefícios e a recriação do contador com valor inicial;
- formulário da primeira etapa criado com referência de receita e EAN fictícios, coordenado por `Form` e `GlobalKey<FormState>`;
- `TextEditingController`s mantidos pelo estado da página e descartados em `dispose`;
- entrada do EAN restrita a dígitos e ao máximo de 13 caracteres com `FilteringTextInputFormatter` e `LengthLimitingTextInputFormatter`;
- validação impedindo leituras sem receita, sem EAN ou com EAN diferente de 13 dígitos;
- ação explícita para preencher um EAN de demonstração sem depender de câmera ou código de barras real;
- leitura válida incrementando o contador, limpando o EAN, removendo o foco do formulário e apresentando confirmação por `SnackBar`, enquanto a receita permanece disponível para novas leituras;
- testes de widget cobrindo formulário vazio, EAN incompleto e o fluxo demonstrativo válido;
- modelos `Prescription`, `Medication`, `CheckoutSession` e `RemoteFlags` implementados como tipos Dart puros com campos finais;
- valores monetários representados em centavos com `int`, evitando erros de precisão binária de `double`;
- medicamentos de `CheckoutSession` protegidos por cópia defensiva não modificável com `List.unmodifiable`;
- `CheckoutStatus` e `DemoScenario` definidos como conjuntos fechados de valores, separando o estado real da sessão dos cenários fictícios da demonstração;
- `CheckoutEvent` modelado como hierarquia `sealed`, com subtipos capazes de transportar os dados específicos de cada acontecimento;
- fachada pública do package consolidada em `checkout_domain.dart`, sem exigir imports diretos de `lib/src` pelos consumidores;
- testes Dart cobrindo preservação de valores, cópia defensiva, rejeição de mutações e pertencimento dos eventos à hierarquia;
- teste de fronteira independente do diretório de execução, localizando o `pubspec.yaml` do package por `Isolate.resolvePackageUri` e impedindo dependências de Flutter, Firebase, Dio e Drift;
- `CheckoutStatus.failed` adicionado para distinguir falhas permanentes de `recoverableFailure`;
- estados terminais definidos como `maintenance`, `failed` e `paid` pela extensão `CheckoutStatusProperties`;
- classificação terminal implementada com `switch` exaustivo, sem caso curinga, obrigando a revisão da regra quando um novo status for criado;
- `CheckoutSession` preparada para preservar `remoteCheckoutId`, a etapa interrompida em `retryTargetStatus` e uma mensagem contextual em `statusMessage`;
- testes Dart cobrindo a preservação do contexto de pagamento e recuperação e a classificação de todos os estados terminais e não terminais;
- `CheckoutStateMachine` implementada em Dart puro para transformar uma sessão e um evento em um novo snapshot imutável;
- fluxo de sucesso coberto desde a coleta do medicamento, submissão e validação da receita, elegibilidade e criação do pagamento até a confirmação final;
- transições inválidas rejeitadas explicitamente por `InvalidCheckoutTransitionException`, preservando o estado original e expondo o status e o evento envolvidos;
- manutenção tratada como estado terminal, com mensagem contextual e remoção de qualquer possibilidade de retry;
- falhas recuperáveis preservando a etapa interrompida, a mensagem e o identificador do checkout remoto para retomada segura;
- retry retornando exatamente à etapa armazenada e limpando o contexto temporário de falha sem recriar o checkout remoto;
- falhas permanentes encerrando a sessão em `failed`, preservando o identificador remoto e removendo o contexto de recuperação;
- confirmação assíncrona aceita durante `awaitingConfirmation` ou após uma falha recuperável dessa mesma etapa, sempre vinculada a um `remoteCheckoutId` existente;
- oito testes da máquina de estados desenvolvidos em ciclos RED → GREEN para sucesso, evento inválido, manutenção, timeout recuperável, retry, falha permanente e confirmação assíncrona;
- contratos `PrescriptionRepository`, `MedicationRepository` e `CheckoutRepository` definidos como `abstract interface class`, mantendo o domínio independente de interface, rede e persistência;
- validação de receita e elegibilidade representando resultados esperados do negócio com `bool`, enquanto falhas técnicas permanecem representadas por exceções;
- criação do checkout devolvendo o `remoteCheckoutId` e consulta posterior recuperando o mesmo checkout remoto sem repetir a operação de criação;
- implementações falsas exercitando substituição pelos contratos e um consumidor didático recebendo as três dependências por construtor;
- suíte completa do package validada com análise estática limpa e 24 testes aprovados;
- `MedicationCounterState` criado como snapshot imutável da quantidade de medicamentos lidos;
- `MedicationCounterCubit` assumindo a lógica do contador e emitindo um novo estado a cada leitura válida, sem depender de `setState`;
- `BlocProvider` instalado na composição da rota do Modo Farmácia para fornecer o Cubit e controlar seu ciclo de vida;
- ação de leitura acessando o Cubit com `context.read()`, sem assinar a página inteira às mudanças de estado;
- `BlocConsumer` limitando as reconstruções à região de conteúdo e separando a apresentação dos efeitos pontuais da interface;
- logs manuais confirmando os estados `0`, `1` e `2` no conteúdo sem reconstruir `PharmacyModePage` a cada emissão;
- teste unitário do estado inicial e `blocTest` da primeira emissão do Cubit adicionados à suíte mobile;
- dependências `flutter_bloc` e `bloc_test` registradas no aplicativo e resolvidas pelo lockfile compartilhado do workspace;
- `CheckoutCubit` criado como camada de coordenação entre os contratos de repositório e a máquina de estados;
- `CheckoutStateMachine` preservada como autoridade de todas as transições da sessão;
- rejeições esperadas de receita e elegibilidade convertidas em falhas permanentes, enquanto falhas técnicas de criação e confirmação produzem falhas recuperáveis;
- contexto de recuperação preservando `retryTargetStatus` e `remoteCheckoutId` para retomar a etapa correta sem recriar o pagamento remoto;
- operações assíncronas protegidas por verificação de `isClosed` antes de novas emissões;
- treze testes do `CheckoutCubit` cobrindo sucesso, leitura de medicamento, rejeições de negócio, falhas técnicas recuperáveis, retry e confirmação do mesmo checkout remoto;
- `scanMedication` adicionando o medicamento à sessão por meio de `MedicationScanned` e da `CheckoutStateMachine`, sem alterar o status `collectingMedication`;
- composição da rota migrada para um único `CheckoutCubit`, inicializado com a sessão local e implementações demonstrativas dos três contratos de repositório;
- contador da interface derivado de `CheckoutSession.medications.length`, eliminando uma segunda fonte de verdade no fluxo em execução;
- repositórios demonstrativos fornecendo respostas locais e determinísticas sem introduzir HTTP, banco de dados ou pagamento real;
- teste de integração verificando que uma leitura válida atualiza a sessão consumida pela tela e apresenta `1 medicamento lido`;
- `listenWhen` filtrando as emissões para executar a confirmação somente quando `CheckoutSession.medications.length` aumenta;
- limpeza do EAN, remoção do foco e apresentação do `SnackBar` movidas do callback do formulário para o `listener`, depois que a nova sessão confirma a inclusão;
- teste de integração comprovando que uma emissão direta do `CheckoutCubit` também apresenta a confirmação, sem depender do callback `_scanMedication`;
- `CheckoutProgressData` definido como record imutável com somente a etapa atual e o rótulo necessários ao indicador;
- `selectCheckoutProgress` extraído como função pura para converter o estado da sessão em progresso visual testável sem montar widgets;
- `BlocSelector` limitando a reconstrução do indicador às mudanças do record selecionado, sem reagir a alterações irrelevantes da sessão;
- validação e elegibilidade agrupadas na etapa 2, criação do pagamento na etapa 3 e confirmação pendente ou concluída na etapa 4;
- falhas recuperáveis mantendo visualmente a etapa interrompida por meio de `retryTargetStatus`;
- testes unitários cobrindo os mapeamentos do selector e teste de widget comprovando a apresentação da etapa selecionada;
- um segundo `BlocSelector` observando somente `CheckoutStatus`, `statusMessage` e `remoteCheckoutId`, sem reconstruir o feedback por alterações irrelevantes da sessão;
- mensagens de falha apresentadas como região semântica dinâmica com `Semantics(liveRegion: true)`, permitindo o anúncio automático por tecnologias assistivas;
- ação `Tentar novamente` restrita a `recoverableFailure`, retomando o `retryTargetStatus` por meio de `CheckoutCubit.retry()` e limpando o contexto temporário da falha;
- falhas permanentes apresentando a mensagem contextual sem oferecer uma ação de retry incompatível com o encerramento da sessão;
- testes de widget cobrindo o anúncio acessível da falha recuperável, a retomada da etapa interrompida e a ausência do botão de retry em falhas permanentes;
- ação `Validar compra` conectada a `CheckoutCubit.submitPrescription()`, disponível somente durante a coleta e depois da inclusão de ao menos um medicamento;
- validação do formulário preservada como pré-condição da submissão, impedindo o avanço quando a referência da receita está vazia;
- ações `Verificar elegibilidade`, `Criar pagamento` e `Confirmar pagamento` apresentadas apenas nos estados correspondentes e delegadas ao `CheckoutCubit`;
- mesma instância de `DemoCheckoutRepository` preservando o checkout demonstrativo entre criação e consulta, vinculada pelo `remoteCheckoutId`;
- testes de widget cobrindo a submissão da receita, a indisponibilidade da ação incompleta e o avanço visual pelas etapas de elegibilidade, criação e confirmação do pagamento;
- estado `paid` apresentando `Pagamento confirmado` e o `remoteCheckoutId` concluído diretamente a partir do snapshot da sessão;
- confirmação de sucesso exposta como região semântica dinâmica com `Semantics(liveRegion: true)` para anúncio por tecnologias assistivas;
- ações de avanço removidas depois da conclusão, mantendo a interface coerente com o estado terminal;
- teste de widget cobrindo o feedback de sucesso, o identificador remoto, a ausência da ação de confirmação e a semântica dinâmica;
- suíte mobile validada com 36 testes aprovados.

O aplicativo inicia em uma tela de benefícios com saldo fictício e navega para o “Modo Farmácia”, onde deriva o progresso do status atual do checkout, recebe uma receita e um EAN sintéticos, valida a entrada e adiciona cada leitura válida à `CheckoutSession`. `CheckoutCubit` é a fonte de verdade do fluxo em execução, coordena os contratos de repositório e delega as transições da sessão à `CheckoutStateMachine`; a interface deriva da própria sessão o contador, o progresso, o feedback contextual e a ação permitida em cada etapa. Depois da coleta, o usuário pode submeter a receita, verificar a elegibilidade, criar o checkout remoto demonstrativo e confirmar o pagamento, sempre por operações do Cubit e sem acessar diretamente a máquina de estados ou os repositórios. O `BlocConsumer` reconstrói o conteúdo e executa a confirmação somente depois que a sessão emitida registra outro medicamento, enquanto seletores distintos atualizam o progresso e o feedback apenas quando seus respectivos valores mudam. Falhas recuperáveis preservam e retomam a etapa interrompida, enquanto falhas permanentes encerram a sessão sem oferecer retry; em ambos os casos, a mensagem permanece no snapshot e é apresentada como uma região semântica dinâmica. Quando a sessão chega a `paid`, a tela apresenta uma confirmação acessível com o identificador do checkout concluído e remove as ações de avanço desse estado terminal. O package Dart puro continua concentrando os modelos, os estados, o contexto de recuperação, as transições válidas e as abstrações necessárias para acessar receita, medicamento e checkout remoto. O fluxo permanece exclusivamente educacional e não contém elegibilidade real, persistência, pagamentos ou integrações externas.

## Limites do projeto

- Todos os saldos, receitas, medicamentos, pagamentos, eventos e métricas serão fictícios.
- Não haverá Pix real, dados pessoais, dados médicos reais ou OCR clínico.
- O projeto terá marca própria e não alegará vínculo com empresas ou serviços reais.
- O backend e as integrações externas existirão apenas para demonstração e aprendizado.

## Validação local

Na raiz do repositório, execute:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze apps/mobile
dart pub workspace list

cd apps/mobile
flutter test
cd ../..

cd packages/checkout_domain
dart test
cd ../..

git diff --check
git status --short
```

O resultado esperado é análise estática sem problemas, 36 testes mobile aprovados — incluindo acessibilidade, navegação, validação de entrada, contador, integração da sessão com a interface, efeito reativo de confirmação, progresso selecionado da sessão, feedback de falhas recuperáveis e permanentes, feedback acessível de checkout concluído, submissão da receita, ações de avanço do fluxo e os testes do `CheckoutCubit` —, além dos testes de modelos, contexto de recuperação, classificação de estados, máquina de estados, contratos de repositório, injeção por construtor e fronteiras do package aprovados e somente alterações intencionais exibidas pelo Git.

## Referências oficiais

- [Dart](https://dart.dev/)
- [Flutter](https://docs.flutter.dev/)
- [Pub.dev](https://pub.dev/)
- [Pub Workspaces](https://dart.dev/tools/pub/workspaces)
- [Guia de arquitetura do Flutter](https://docs.flutter.dev/app-architecture/guide)
- [Comunicação entre camadas e injeção de dependência](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
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
- [Branches em Dart](https://dart.dev/language/branches)
- [Patterns em Dart](https://dart.dev/language/patterns)
- [Tratamento de erros em Dart](https://dart.dev/language/error-handling)
- [Testes em Dart](https://dart.dev/libraries/testing)
- [Package `test`](https://pub.dev/packages/test)
- [`flutter_bloc`](https://pub.dev/packages/flutter_bloc)
- [`bloc_test`](https://pub.dev/packages/bloc_test)
- [`List.unmodifiable`](https://api.dart.dev/dart-core/List/List.unmodifiable.html)
- [`Isolate.resolvePackageUri`](https://api.dart.dev/dart-isolate/Isolate/resolvePackageUri.html)
