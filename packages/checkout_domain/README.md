# Checkout Domain

Package Dart puro que concentra os modelos, as regras, as transições e os contratos de dados do checkout do MediFlow e será compartilhado entre os clientes mobile e Web.

## Regra de dependência

Este package não poderá depender de Flutter, Firebase, Dio ou Drift.

Essa fronteira mantém as regras independentes de interface, rede, persistência e infraestrutura, permitindo testes Dart rápidos e reutilização dos tipos. O package pode depender de outros pacotes Dart puros quando servem diretamente uma regra de domínio — `uuid`, usado para gerar a chave de idempotência, é o primeiro caso.

## API pública

- `Prescription`: referência fictícia da receita;
- `Medication`: EAN, nome e preço unitário em centavos;
- `CheckoutSession`: snapshot da sessão, com medicamentos protegidos por cópia defensiva e contexto para pagamento e recuperação;
- `CheckoutStatus`: conjunto fechado de estados da sessão, acompanhado da classificação de estados terminais;
- `CheckoutEvent`: hierarquia fechada de acontecimentos, com dados específicos por subtipo;
- `RemoteFlags`: configuração remota já carregada e disponível para o domínio;
- `DemoScenario`: cenários fictícios usados somente na demonstração;
- `CheckoutStateMachine`: transformação validada de uma sessão e um evento em um novo snapshot imutável;
- `PrescriptionRepository`: contrato para validação de receitas sintéticas;
- `MedicationRepository`: contrato para consulta de elegibilidade de medicamentos;
- `CheckoutRepository`: contrato para criação e recuperação de checkouts remotos.

Os consumidores importam `package:checkout_domain/checkout_domain.dart`. Os arquivos em `lib/src` permanecem como detalhes internos do package.

## Garantias atuais

- valores monetários são representados em centavos com `int`;
- os modelos expõem campos finais;
- `CheckoutSession` cria uma lista não modificável de medicamentos com `List.unmodifiable`;
- `CheckoutSession` pode preservar o identificador do checkout remoto, a etapa interrompida, uma mensagem contextual e a chave de idempotência da tentativa de criação de pagamento em curso;
- eventos formam uma hierarquia `sealed`;
- falhas recuperáveis e permanentes possuem estados distintos;
- `maintenance`, `failed` e `paid` são estados terminais;
- `CheckoutStatusProperties.isTerminal` usa um `switch` exaustivo, sem caso curinga;
- `CheckoutStateMachine` rejeita transições inválidas e preserva o contexto necessário para retry e confirmação assíncrona;
- `CheckoutStateMachine` gera uma `idempotencyKey` (`uuid` v4) uma única vez, na transição de `checkingEligibility` para `creatingPayment`, e a preserva sem regenerar em toda transição posterior — inclusive um retry a partir de `recoverableFailure` — para que múltiplas tentativas HTTP da mesma criação de pagamento carreguem a mesma chave;
- contratos de repositório são definidos como `abstract interface class` e não conhecem suas implementações;
- resultados esperados de validação e elegibilidade usam `bool`, reservando exceções para falhas técnicas;
- `CheckoutRepository.create` devolve o identificador remoto, e `getById` permite consultar o checkout existente sem iniciar outra criação;
- consumidores podem receber implementações compatíveis por injeção de dependência no construtor;
- o `pubspec.yaml` usa a resolução compartilhada do Pub Workspace;
- testes verificam os modelos, o contexto de recuperação, a classificação dos estados, a máquina de estados, os contratos de repositório, a injeção por construtor e as fronteiras do package.

## Validação

Na raiz do monorepo:

```bash
dart analyze packages/checkout_domain
dart test packages/checkout_domain
```

## Status

A estrutura inicial foi criada na Aula 6, e os modelos fundamentais foram implementados e testados na Aula 13. Na Aula 14, foram definidos os estados, os estados terminais e os dados necessários para retomadas seguras. A Aula 15 implementou e testou a máquina de estados. Na Aula 16, foram adicionados os contratos de repositório, implementações falsas e uma prova de injeção por construtor. Na Aula 18, a integração do domínio com o gerenciamento de estado do aplicativo começou por meio do `CheckoutCubit`. O Cubit coordena os contratos de repositório, mas continua delegando todas as transições à `CheckoutStateMachine`, preservando o domínio como autoridade das regras do checkout. Na Aula 23, `CheckoutSession` ganhou o campo `idempotencyKey` e `CheckoutStateMachine` passou a gerá-lo com o pacote `uuid` — a primeira dependência de pub deste package — exatamente uma vez por tentativa lógica de criação de pagamento, para consumo pelos repositórios HTTP do app mobile.
