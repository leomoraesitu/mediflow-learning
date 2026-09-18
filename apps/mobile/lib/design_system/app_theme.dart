import 'package:flutter/material.dart';
import 'package:mediflow_mobile/design_system/app_radius.dart';
import 'package:mediflow_mobile/design_system/app_sizes.dart';

final class AppTheme {
  const AppTheme._();

  static const Color seedColor = Color(0xFF3559C7);

  /// Constrói um tema a partir de um esquema de cores já resolvido.
  ///
  /// Recebe o `ColorScheme` pronto, e não um `Brightness`, para que exista uma
  /// definição só dos componentes: o tema claro e o escuro passam por aqui, e
  /// a única diferença entre eles é o esquema que entra. Nada neste corpo
  /// sabe qual dos dois está sendo construído — é isso que impede as duas
  /// definições de divergirem com o tempo.
  static ThemeData _themeFrom(ColorScheme colorScheme) {
    const minimumButtonSize = Size(AppSizes.minimumButtonSize, AppSizes.minimumButtonSize);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: minimumButtonSize),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: minimumButtonSize),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: minimumButtonSize),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minimumButtonSize),
      ),
      // Só o alinhamento. `titleTextStyle` fica em branco de propósito: o
      // `AppBar` resolve o estilo do título como
      // `titleTextStyle ?? defaults.titleTextStyle?.copyWith(color: foregroundColor)`,
      // e a cor entra apenas naquele último ramo. Preencher este campo — ainda
      // que só para mudar o tamanho — apaga a cor junto, porque o estilo é
      // aplicado por substituição e não por mesclagem. Foi assim que o título
      // ficou com contraste 1,25 e o teste de acessibilidade abriu vermelho.
      appBarTheme: const AppBarThemeData(centerTitle: true),
      cardTheme: CardThemeData(
        // O padrão do Material 3 para cartão é 1. Três é o nível seguinte da
        // escala do M3, escolhido para o cartão da tela inicial se destacar do
        // fundo — no M3 a elevação também muda o tom da superfície, não só a
        // sombra. `margin` fica de fora: o único `Card` do app é o
        // `MediFlowContentCard`, que define a própria.
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      // Apenas `border`, e isso é o ponto. O `InputDecorator` usa esta borda
      // como forma e resolve o traço por estado a partir do `ColorScheme` —
      // foco em `primary`, erro em `error`, repouso em `outline`. Preencher
      // `enabledBorder`, `focusedBorder` ou `errorBorder` curto-circuita esse
      // caminho e fixa o traço padrão do `OutlineInputBorder`: preto, 1px, em
      // todo estado — invisível no tema escuro, e sem indicação de foco.
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.md))),
      ),
    );
  }

  // Campos, não getters: `ColorScheme.fromSeed` roda o algoritmo de paleta
  // tonal, e `MainApp.build` lê os dois. Estáticos finais em Dart são
  // inicializados por demanda, então nada disso acontece antes da hora.
  static final ThemeData light = _themeFrom(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
  );

  static final ThemeData dark = _themeFrom(
    ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
  );
}
