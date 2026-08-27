# Checkout Domain

Package Dart puro que concentra os modelos fundamentais do checkout do MediFlow e será compartilhado entre os clientes mobile e Web.

## Regra de dependência

Este package não poderá depender de Flutter, Firebase, Dio ou Drift.

Essa fronteira mantém as regras independentes de interface, rede, persistência e infraestrutura, permitindo testes Dart rápidos e reutilização dos tipos.

## API pública

- `Prescription`: referência fictícia da receita;
- `Medication`: EAN, nome e preço unitário em centavos;
- `CheckoutSession`: snapshot da sessão, com medicamentos protegidos por cópia defensiva e contexto para pagamento e recuperação;
- `CheckoutStatus`: conjunto fechado de estados da sessão, acompanhado da classificação de estados terminais;
- `CheckoutEvent`: hierarquia fechada de acontecimentos, com dados específicos por subtipo;
- `RemoteFlags`: configuração remota já carregada e disponível para o domínio;
- `DemoScenario`: cenários fictícios usados somente na demonstração.

Os consumidores importam `package:checkout_domain/checkout_domain.dart`. Os arquivos em `lib/src` permanecem como detalhes internos do package.

## Garantias atuais

- valores monetários são representados em centavos com `int`;
- os modelos expõem campos finais;
- `CheckoutSession` cria uma lista não modificável de medicamentos com `List.unmodifiable`;
- `CheckoutSession` pode preservar o identificador do checkout remoto, a etapa interrompida e uma mensagem contextual;
- eventos formam uma hierarquia `sealed`;
- falhas recuperáveis e permanentes possuem estados distintos;
- `maintenance`, `failed` e `paid` são estados terminais;
- `CheckoutStatusProperties.isTerminal` usa um `switch` exaustivo, sem caso curinga;
- o `pubspec.yaml` usa a resolução compartilhada do Pub Workspace;
- testes verificam os modelos, o contexto de recuperação, a classificação dos estados e as fronteiras do package.

## Validação

Na raiz do monorepo:

```bash
dart analyze packages/checkout_domain
dart test packages/checkout_domain
```

## Status

A estrutura inicial foi criada na Aula 6, e os modelos fundamentais foram implementados e testados na Aula 13. Na Aula 14, foram definidos os estados, os estados terminais e os dados que a sessão precisa preservar para permitir retomadas seguras. As transições ainda não são executadas por uma máquina: sua implementação começará por testes vermelhos na Aula 15.
