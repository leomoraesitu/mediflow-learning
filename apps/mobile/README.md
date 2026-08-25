# Mobile

Aplicativo Flutter Android principal do MediFlow Learning.

## Estado atual

Na Aula 9, a aplicação passou a apresentar o “Modo Farmácia” com uma identidade visual própria e responsiva. O botão “Simular leitura” continua incrementando a quantidade de medicamentos lidos e atualizando a mensagem exibida na tela.

A composição atual separa estado, apresentação e design system:

- `MainApp` configura o `MaterialApp` e aplica o tema global;
- `PharmacyModePage` é um `StatefulWidget`;
- `_PharmacyModePageState` possui o contador e executa `setState`;
- `MedicationCounterContent` é um `StatelessWidget` que recebe `count` e `onScan`;
- `AppTheme` centraliza o `ThemeData`, o Material 3 e o `ColorScheme` do aplicativo;
- `AppSpacing` oferece uma escala compartilhada de espaçamentos;
- `MediFlowContentCard` encapsula largura máxima, margem, padding e rolagem vertical.

O pai mantém o estado, envia o valor para o filho e recebe a interação por callback. Os widgets visuais recuperam cores e tipografia do tema mais próximo com `Theme.of(context)`, sem depender diretamente de valores de marca espalhados pela interface.

O conteúdo ocupa a largura disponível até o limite de 480 pixels lógicos. `SafeArea` respeita recortes e áreas de navegação do dispositivo, enquanto `SingleChildScrollView` oferece uma saída para alturas reduzidas. O comportamento foi validado em retrato e paisagem sem overflow.

Os logs de `initState`, `build` e `dispose` permitem observar o ciclo de vida durante o aprendizado. O hot reload preserva o objeto `State`, enquanto o hot restart recria a aplicação e reinicia o contador.

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
dart format --output=none --set-exit-if-changed apps/mobile/lib
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
- [Temas no Flutter](https://docs.flutter.dev/cookbook/design/themes)
- [Entendendo constraints](https://docs.flutter.dev/ui/layout/constraints)
- [Abordagem geral para aplicativos adaptáveis](https://docs.flutter.dev/ui/adaptive-responsive/general)
- [`SafeArea`](https://api.flutter.dev/flutter/widgets/SafeArea-class.html)
- [`SingleChildScrollView`](https://api.flutter.dev/flutter/widgets/SingleChildScrollView-class.html)
