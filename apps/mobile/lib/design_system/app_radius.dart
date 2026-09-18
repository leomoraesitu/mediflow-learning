/// A escala de arredondamento.
///
/// Deliberadamente independente de `AppSpacing`: raio e espaçamento não
/// crescem juntos — dobrar a margem de um cartão não dobra o quanto os cantos
/// dele são arredondados. Por isso `AppRadius.md` (8) e `AppSpacing.md` (16)
/// são valores diferentes, e a leitura correta de `md` é sempre "o passo do
/// meio desta escala", nunca um número compartilhado entre as duas.
final class AppRadius {
  const AppRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
}
