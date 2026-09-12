/// Mede a duração de uma operação assíncrona.
///
/// Existe para que os decorators de performance não dependam de
/// `FirebasePerformance`, classe concreta do plugin que exige `Firebase`
/// inicializado e não tem substituto em teste. É a mesma costura que
/// `AuthGateway` faz para a autenticação.
///
/// A interface colapsa o trio `newTrace` / `start` / `stop` numa única
/// operação: quem instrumenta não tem como esquecer de parar o trace, e o
/// `finally` fica em um lugar só.
abstract interface class PerformanceTracer {
  Future<T> trace<T>(String name, Future<T> Function() action);
}
