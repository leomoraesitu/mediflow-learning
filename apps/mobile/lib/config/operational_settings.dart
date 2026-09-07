abstract interface class OperationalSettings {
  bool get maintenanceMode;
  String get maintenanceMessage;
  Duration get checkoutTimeout;
}

final class StaticOperationalSettings implements OperationalSettings {
  @override
  final bool maintenanceMode;

  @override
  final String maintenanceMessage;

  @override
  final Duration checkoutTimeout;

  const StaticOperationalSettings({
    this.maintenanceMode = false,
    this.maintenanceMessage =
        'O Modo Farmácia está temporariamente indisponível.',
    this.checkoutTimeout = const Duration(milliseconds: 8000),
  });
}
