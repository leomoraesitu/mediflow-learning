# Mobile

Aplicativo Flutter Android principal do MediFlow Learning.

## Estado atual

Na Aula 8, a aplicação passou a apresentar o “Modo Farmácia” com uma interação de estado local. O botão “Simular leitura” incrementa a quantidade de medicamentos lidos e atualiza a mensagem exibida na tela.

A composição atual separa responsabilidade e apresentação:

- `MainApp` configura o `MaterialApp`;
- `PharmacyModePage` é um `StatefulWidget`;
- `_PharmacyModePageState` possui o contador e executa `setState`;
- `MedicationCounterContent` é um `StatelessWidget` que recebe `count` e `onScan`.

O pai mantém o estado, envia o valor para o filho e recebe a interação por callback. Os logs de `initState`, `build` e `dispose` permitem observar o ciclo de vida durante o aprendizado. O hot reload preserva o objeto `State`, enquanto o hot restart recria a aplicação e reinicia o contador.

O fluxo de negócio do Modo Farmácia ainda não foi implementado.

## Execução

Consulte os dispositivos disponíveis, entre no diretório do aplicativo e execute-o informando o identificador desejado:

```bash
flutter devices
cd apps/mobile
flutter run -d <device-id>
```

## Validação

Na raiz do repositório, execute:

```bash
dart format --output=none --set-exit-if-changed apps/mobile/lib/main.dart
flutter analyze apps/mobile
git diff --check
git status --short
```

Os testes de widgets do aplicativo serão introduzidos em uma aula futura. O Quality Gate atual também executa os testes de fronteira do package `checkout_domain`.

## Referências oficiais

- [StatelessWidget](https://api.flutter.dev/flutter/widgets/StatelessWidget-class.html)
- [StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [State e ciclo de vida](https://api.flutter.dev/flutter/widgets/State-class.html)
- [`setState`](https://api.flutter.dev/flutter/widgets/State/setState.html)
