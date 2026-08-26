/// A class representing the remote flags used in the checkout process.
final class RemoteFlags {
  final Duration checkoutTimeout;
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final bool fallbackEnabled;

  const RemoteFlags({
    required this.checkoutTimeout,
    required this.maintenanceEnabled,
    required this.maintenanceMessage,
    required this.fallbackEnabled,
  });
}
