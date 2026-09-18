/// Registra eventos de uso.
///
/// Existe para que o observador de Bloc não dependa de `FirebaseAnalytics`,
/// classe concreta do plugin que exige `Firebase` inicializado e não tem
/// substituto em teste. É a mesma costura que `AuthGateway` e
/// `PerformanceTracer` fazem, e a razão é a mesma: sem ela o observador é
/// impossível de instanciar num teste — que foi como um defeito sobreviveu
/// sete aulas.
abstract interface class AnalyticsSink {
  void logEvent(String name, Map<String, Object> parameters);
}
