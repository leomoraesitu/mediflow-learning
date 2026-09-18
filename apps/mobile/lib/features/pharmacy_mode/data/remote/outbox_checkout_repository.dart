import 'dart:convert';

import 'package:checkout_domain/checkout_domain.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';

final class OutboxCheckoutRepository implements CheckoutRepository {
  final CheckoutRepository _inner;
  final CheckoutDatabase _database;

  /// O dono é lido a cada chamada, e não guardado.
  ///
  /// Esta instância vive o processo inteiro e atravessa trocas de usuário;
  /// guardar o `uid` da composição a deixaria enfileirando no dono errado
  /// depois do primeiro logout.
  final AuthGateway _authGateway;

  const OutboxCheckoutRepository({
    required this._inner,
    required this._database,
    required this._authGateway,
  });

  @override
  Future<String> create(CheckoutSession session) async {
    final idempotencyKey = session.idempotencyKey;

    if (idempotencyKey == null) {
      throw StateError('CheckoutSession must have an idempotencyKey before create().');
    }

    final userId = _authGateway.currentUser?.uid;

    // Inalcançável pelo fluxo normal desde a Aula 56: o interceptor do Dio
    // rejeita antes de sair, e a tela de checkout só existe atrás do portão.
    // Fica como defesa em profundidade, porque `create` grava no banco *antes*
    // de tentar a rede — um chamador fora do portão enfileiraria um evento sem
    // dono, que nenhum drenador leria e nenhuma tela mostraria.
    //
    // Se um dia isto for removido, o interceptor passa a ser a única barreira.
    if (userId == null) {
      throw StateError('Não há usuário autenticado para registrar o checkout.');
    }

    final snapshot = CheckoutSessionSnapshot.fromDomain(session);

    final payload = jsonEncode(snapshot.toMap());

    await _database.enqueueOutboxEvent(
      userId: userId,
      idempotencyKey: idempotencyKey,
      operationType: 'createCheckout',
      payload: payload,
    );

    try {
      final remoteCheckoutId = await _inner.create(session);

      await _database.removeOutboxEvent(userId: userId, idempotencyKey: idempotencyKey);

      return remoteCheckoutId;
    } catch (_) {
      // Mantém o evento no outbox para retry posterior.
      rethrow;
    }
  }

  @override
  Future<CheckoutSession> getById(String remoteCheckoutId) {
    return _inner.getById(remoteCheckoutId);
  }
}
