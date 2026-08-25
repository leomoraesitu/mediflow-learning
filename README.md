# MediFlow Learning

Repositório privado para a reconstrução educacional e guiada do MediFlow, um estudo independente sobre um checkout de medicamentos resiliente. O projeto será desenvolvido do zero, aula por aula, para exercitar Dart, Flutter, testes, arquitetura, resiliência e observabilidade.

Este repositório não copia a identidade visual da Omni Saúde, não representa uma parceria com a empresa e não deve ser interpretado como um produto clínico ou financeiro real.

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

Até a Aula 9, a infraestrutura inicial do monorepo, a primeira interação com estado local e a base visual do aplicativo foram criadas:

- repositório e branch de trabalho configurados;
- diretórios de mobile, painel, domínio, backend e documentação definidos;
- Pub Workspace configurado para o aplicativo mobile e o package de domínio;
- fronteira de dependências do domínio protegida por testes;
- resolução e lockfile compartilhados na raiz;
- scaffold Flutter Android criado em `apps/mobile`;
- primeira árvore de widgets executada e validada em um emulador Android;
- `PharmacyModePage` implementada como `StatefulWidget`, com o contador mantido em seu objeto `State`;
- apresentação extraída para o `StatelessWidget` `MedicationCounterContent`;
- fluxo de dados unidirecional exercitado com `count` descendo para o filho e `onScan` retornando como callback;
- reconstruções e métodos `initState`, `build` e `dispose` instrumentados com logs;
- hot reload e hot restart verificados durante o desenvolvimento.
- tema Material 3 centralizado em `AppTheme`, com um `ColorScheme` derivado da cor-base própria do MediFlow;
- cores e estilos tipográficos consumidos pela árvore por meio de `Theme.of(context)`;
- escala de espaçamento definida em `AppSpacing`, evitando valores de layout dispersos;
- componente reutilizável `MediFlowContentCard` criado para padronizar margem, padding e apresentação;
- largura do conteúdo limitada a 480 pixels lógicos, preservando o aproveitamento de telas estreitas e evitando expansão excessiva em telas largas;
- rolagem vertical de segurança e respeito às áreas ocupadas por recortes, barras e gestos do sistema;
- layout validado no emulador Android nas orientações retrato e paisagem, sem overflow.

O aplicativo exibe o “Modo Farmácia”, permite simular leituras de medicamentos e atualiza um contador local em uma interface responsiva com identidade própria. O fluxo ainda é exclusivamente educacional e não contém regras de negócio, persistência ou integrações externas.

## Limites do projeto

- Todos os saldos, receitas, medicamentos, pagamentos, eventos e métricas serão fictícios.
- Não haverá Pix real, dados pessoais, dados médicos reais ou OCR clínico.
- O projeto terá marca própria e não alegará vínculo com a Omni Saúde.
- O backend e as integrações externas existirão apenas para demonstração e aprendizado.

## Validação local

Na raiz do repositório, execute:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze apps/mobile
dart pub workspace list

cd packages/checkout_domain
dart test
cd ../..

git diff --check
git status --short
```

O resultado esperado é análise estática sem problemas, os testes do package aprovados e apenas alterações intencionais exibidas pelo Git.

## Referências oficiais

- [Dart](https://dart.dev/)
- [Flutter](https://docs.flutter.dev/)
- [Pub.dev](https://pub.dev/)
- [Pub Workspaces](https://dart.dev/tools/pub/workspaces)
- [Guia de arquitetura do Flutter](https://docs.flutter.dev/app-architecture/guide)
- [Temas no Flutter](https://docs.flutter.dev/cookbook/design/themes)
- [Entendendo constraints](https://docs.flutter.dev/ui/layout/constraints)
- [Abordagem geral para aplicativos adaptáveis](https://docs.flutter.dev/ui/adaptive-responsive/general)
- [`SafeArea`](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)
