import 'dart:convert';

import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_database.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_snapshot.dart';
import 'package:mediflow_mobile/features/pharmacy_mode/data/checkout_session_storage.dart';

/// Recebe o `userId` pronto, e não um `AuthGateway`.
///
/// Esta instância nasce numa navegação, dentro da parte autenticada do
/// aplicativo: quem a constrói já sabe de quem é a sessão, e ela não
/// sobrevive a uma troca de usuário. É o oposto das peças do outbox, que
/// vivem o processo inteiro e precisam perguntar "quem é agora?" a cada uso.
final class DriftCheckoutSessionStorage implements CheckoutSessionStorage {
  final CheckoutDatabase _database;
  final String _userId;

  DriftCheckoutSessionStorage(this._database, this._userId);

  @override
  Future<void> save(CheckoutSessionSnapshot snapshot) {
    return _database.writeCheckoutSession(userId: _userId, payload: jsonEncode(snapshot.toMap()));
  }

  @override
  Future<CheckoutSessionSnapshot?> load() async {
    final record = await _database.readCheckoutSession(_userId);

    if (record == null) {
      return null;
    }

    final storedMap = jsonDecode(record.payload) as Map<String, Object?>;

    return CheckoutSessionSnapshot.fromMap(storedMap);
  }

  @override
  Future<void> clear() {
    return _database.clearCheckoutSession(_userId);
  }
}
