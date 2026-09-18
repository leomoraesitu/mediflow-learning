import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/design_system/app_sizes.dart';
import 'package:mediflow_mobile/design_system/app_theme.dart';

void main() {
  test('derives a distinct palette for each brightness', () {
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);

    // A asserção que importa. As duas paletas saem da mesma semente, mas o
    // algoritmo do Material 3 reescolhe a luminância de cada papel — o tema
    // escuro não é o claro invertido. Sem isto, o teste continuaria verde se
    // `dark` fosse uma cópia de `light` ou um `ColorScheme.dark()` genérico.
    expect(AppTheme.light.colorScheme.primary, isNot(AppTheme.dark.colorScheme.primary));
  });

  test('applies the minimum touch target to every button type', () {
    const expected = Size(AppSizes.minimumButtonSize, AppSizes.minimumButtonSize);

    final styles = <ButtonStyle?>[
      for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) ...[
        theme.elevatedButtonTheme.style,
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
      ],
    ];

    // Só `minimumSize`, e não o `ButtonStyle` inteiro: um teste que falha por
    // um motivo que não está no próprio nome é um teste que será silenciado no
    // primeiro incômodo.
    for (final style in styles) {
      expect(style?.minimumSize?.resolve(<WidgetState>{}), expected);
    }
  });
}
