import 'package:checkout_domain/checkout_domain.dart';

final class ResilientFakeCheckoutServer implements CheckoutRepository {
  final Map<String, String> _createdByIdempotencyKey = {};
  int creationCount = 0;
  bool dropNextResponse = false;

  @override
  Future<String> create(CheckoutSession session) async {
    final key = session.idempotencyKey!;
    final existing = _createdByIdempotencyKey[key];
    final String remoteCheckoutId;

    if (existing != null) {
      remoteCheckoutId = existing; // já processado antes, não recria
    } else {
      creationCount++; // primeira vez de verdade para esta chave
      remoteCheckoutId = 'remote-$creationCount';
      _createdByIdempotencyKey[key] = remoteCheckoutId;
    }

    if (dropNextResponse) {
      dropNextResponse = false;
      throw Exception('Conexão perdida antes da confirmação.');
    }

    return remoteCheckoutId;
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) =>
      throw UnimplementedError();
}
