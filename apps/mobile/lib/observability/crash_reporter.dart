/// Registra falhas não fatais.
///
/// Separado de [AnalyticsSink] porque são dois destinos diferentes com dois
/// contratos diferentes: um conta o que aconteceu, o outro conta o que deu
/// errado. Juntá-los faria um fake ter de imitar os dois para testar um.
abstract interface class CrashReporter {
  void recordError(Object error, StackTrace stackTrace);
}
