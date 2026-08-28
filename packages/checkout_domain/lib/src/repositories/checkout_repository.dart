import '../checkout_session.dart';

abstract interface class CheckoutRepository {
  Future<String> create(CheckoutSession session);

  Future<CheckoutSession> getById(String remoteCheckoutId);
}
