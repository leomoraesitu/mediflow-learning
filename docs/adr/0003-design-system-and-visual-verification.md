# 0003 — O design system e o alcance de cada instrumento de verificação

## Status

Aceito (Aula 59).

## Contexto

Até a Aula 58 o projeto era arquiteturalmente profundo e visualmente raso. O design system inteiro eram 47 linhas em três arquivos, e `app_theme.dart` tinha 19 linhas com um único override de componente. Não havia tema escuro. Os onze botões do aplicativo eram todos `ElevatedButton`, inclusive cinco empilhados na mesma coluna do Modo Farmácia. Os campos de texto usavam o sublinhado padrão do Material. O `AndroidManifest.xml` declarava `android:label="mediflow_mobile"`, o nome do diretório do pacote, e o ícone era o pássaro padrão do Flutter.

Isso importa porque o projeto é apresentado como case: alguém abre o aplicativo antes de abrir o código.

## Decisão

### O tema deriva de uma semente, e existe nas duas luminosidades

`AppTheme._themeFrom` recebe um `ColorScheme` já resolvido e devolve o `ThemeData`. Os dois temas passam por ele, e a única diferença é o esquema que entra — nada no corpo sabe qual dos dois está sendo construído. É isso que impede as duas definições de divergirem.

`ColorScheme.fromSeed` roda duas vezes sobre a mesma semente. O tema escuro **não inverte** o claro: o algoritmo do Material 3 rederiva a luminância de cada papel, e `colorScheme.primary` continua significando "a cor da ação principal" nos dois.

### A hierarquia de botões é decidida pelo estado de visão

`CheckoutViewState` ganhou `primaryAction`, derivado dos `can*` que ele já tinha, do passo mais profundo para o mais raso. `MedicationCounterContent` recebe o valor pronto e só traduz: a ação que coincide vira `FilledButton`, as outras viram `OutlinedButton`. O widget não olha status, não conta medicamentos e não conhece a ordem dos passos — é a fronteira da [ADR 0002](0002-presentation-layer-boundary.md) aplicada a uma decisão de aparência.

A derivação não acrescenta conhecimento de domínio: é função pura de campos que o estado já tinha. Foi essa propriedade, e não a conveniência, que autorizou ela a morar do lado de apresentação.

Vale registrar o que a cadeia de cinco ramos realmente faz: os `CheckoutStatus` são mutuamente exclusivos, então o único par que pode ser verdadeiro ao mesmo tempo é `canScan` + `canSubmit`. Ela desempata **um** caso. Os outros quatro ramos são robustez para um status futuro.

### Preencher um campo de tema pode desligar o que o framework faria

Duas armadilhas do Material que o analisador não vê, ambas documentadas no próprio `app_theme.dart`:

**`AppBarTheme.titleTextStyle` é aplicado por substituição, não por mesclagem.** O `AppBar` resolve o estilo como `titleTextStyle ?? defaults.titleTextStyle?.copyWith(color: foregroundColor)`, e a cor entra apenas no último ramo. Preencher o campo — ainda que só para mudar o tamanho — apaga a cor junto. Aconteceu: o título ficou com contraste 1,25 e o teste de acessibilidade abriu vermelho. O campo ficou em branco, e o título herda `titleLarge` inteiro.

**Em `InputDecorationTheme`, o fallback das bordas por estado não é `border`.** É `_getDefaultBorder`, que toma a *forma* de `border` e resolve o *traço* por estado a partir do `ColorScheme` — foco em `primary`, erro em `error`, repouso em `outline`. Definir `enabledBorder`, `focusedBorder` ou `errorBorder` curto-circuita esse caminho e fixa o padrão do `OutlineInputBorder`: preto, 1px, em todo estado. No tema claro isso passa por escolha de estilo; no escuro a borda desaparece, e a indicação de foco e a borda vermelha de erro somem nos dois.

A regra que as duas ensinam: **um campo de tema em branco não é omissão, é delegação.** Antes de preencher um, vale saber o que o framework faria sem ele.

### A identidade do Android é XML, e os PNGs legados são dívida aceita

O ícone é adaptativo: fundo na cor da semente, frente em `<vector>`, amarrados por `mipmap-anydpi-v26/ic_launcher.xml`. Nada binário — o ícone é revisável no diff.

Os cinco `mipmap-*/ic_launcher.png` continuam sendo o pássaro do Flutter, e com `minSdk = 24` as APIs 24 e 25 caem neles. Refazê-los exigiria produzir um PNG num editor externo e trazer cinco binários, ou subir o `minSdk` para 26 — decisão de produto que não se toma por conveniência de ícone. Duas versões de Android com fatia desprezível não pagam nenhuma das duas. A dívida fica registrada em `apps/mobile/README.md`.

A cor `#3559C7` passou a viver em três arquivos — `app_theme.dart`, `values/colors.xml` e `docs/assets/logo.svg`. Nada no build os liga e não há teste comparando. É o único acoplamento por valor do projeto, e ele é inevitável: o splash e o ícone são desenhados pelo sistema antes de o motor do Flutter existir, então nada pode consultar o `ColorScheme` em tempo de execução.

### Cada instrumento de verificação tem um alcance, e presumir o alcance é como se erra

Esta é a decisão mais importante da aula, e ela não é sobre layout.

Três afirmações foram feitas com confiança durante o trabalho e **falsificadas por medição**:

| Afirmação | O que a medição mostrou |
| --- | --- |
| O golden da tela de entrada no escuro guardaria os defeitos de borda e de contraste de título | Não guarda. Borda de 1px e texto fino passam pela tolerância de 3%. O que ele guarda é a ligação `ThemeMode.system` para `AppTheme.dark` |
| `minimumSize: 48` nos temas de botão é o piso de alvo de toque | Não é. `ThemeData` resolve `materialTapTargetSize` para `padded` e todo `ButtonStyleButton` já embrulha o conteúdo em `kMinInteractiveDimension`. Derrubar o valor para 24 não move `androidTapTargetGuideline`. O que o tema fixa é tamanho visual |
| O splash produzia um flash branco no modo escuro | Não produzia. `drawable-v21/` vence `drawable/` com `minSdk = 24`, e continha `?android:colorBackground`, que já resolvia por tema |

O alcance de cada instrumento, medido:

- **Golden** compara imagens sob tolerância de 3%. Pega cor de área grande e movimento de bloco; não pega forma em detalhe pequeno. Medido: trocar `FilledButton` por `ElevatedButton` derruba; mudar o raio do cartão de 8 para 24 não.
- **`textContrastGuideline`** lê a cor computada a partir da semântica. É categórico — uma violação vale independentemente de quantos pixels ocupa — mas só enxerga **texto**.
- **Nenhum dos dois** cobre contraste do que não é texto: a borda de um campo, o traço de um indicador. Lacuna conhecida e aberta, registrada no cabeçalho de `accessibility_guidelines_test.dart`.
- **`flutter analyze` e `flutter test` não enxergam recurso Android.** Medido: `drawable-night/launch_background.xml` nasceu sem raiz e sem `xmlns`; analisador e 224 testes verdes, `assembleDebug` vermelho com `ParseError`. Compilar o aplicativo é a única validação que esses arquivos têm.

## Consequências

**A quebra dirigida passou a incluir uma segunda medição.** Antes bastava sabotar e conferir o vermelho. Uma sabotagem desta aula não compilou e foi reportada como "o teste pegou"; outra era um no-op de layout. Agora cada sabotagem é medida duas vezes: se derruba o teste, e se de fato mudou o que deveria mudar. Sem a segunda, um instrumento cego é indistinguível de um código correto.

**O tema escuro tem uma cobertura visual e nenhuma cobertura de contraste não textual.** Quem acrescentar um componente com borda, traço ou ícone desenhado precisa verificar no aparelho. O `apps/mobile/README.md` registra o que a passagem pelo emulador da Aula 59 confirmou.

**`elevatedButtonTheme` ficou sem consumidor em `lib/` e permanece de propósito**, mas pela razão certa: para que um `ElevatedButton` escrito numa tela futura nasça do mesmo tamanho visual que os outros três, em vez dos 40 padrão do Material 3. Não é piso de acessibilidade.

**Regravar goldens virou operação de fim de aula, não de fim de passo.** Eles ficaram vermelhos durante três passos, deliberadamente, e foram regravados uma vez só com as telas estabilizadas. A CI não dispara em branch de trabalho, então o vermelho ficou local.

**Continua sem existir:** responsividade por breakpoint, cobertura de fonte ampliada, e um golden do Modo Farmácia — essa tela ganhou botão novo em quatro das últimas dez aulas, e um golden regravado toda aula deixa de testar qualquer coisa.
