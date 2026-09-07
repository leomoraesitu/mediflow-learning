import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:mediflow_mobile/config/operational_settings.dart';

class RemoteConfigOperationalSettings implements OperationalSettings {
  RemoteConfigOperationalSettings(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  static const String _maintenanceModeKey = 'maintenance_mode';
  static const String _maintenanceMessageKey = 'maintenance_message';
  static const String _checkoutTimeoutMsKey = 'checkout_timeout_ms';

  static Future<RemoteConfigOperationalSettings> load(
    FirebaseRemoteConfig remoteConfig,
  ) async {
    final settings = RemoteConfigOperationalSettings(remoteConfig);

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 12),
      ),
    );

    await remoteConfig.setDefaults(const <String, Object>{
      _maintenanceModeKey: false,
      _maintenanceMessageKey:
          'O Modo Farmácia está temporariamente indisponível.',
      _checkoutTimeoutMsKey: 8000,
    });

    try {
      await remoteConfig.fetchAndActivate();
    } on FirebaseException catch (e) {
      debugPrint(
        'Falha ao carregar Firebase Remote Config: '
        '${e.code} - ${e.message}',
      );
    }

    return settings;
  }

  @override
  bool get maintenanceMode => _remoteConfig.getBool(_maintenanceModeKey);

  @override
  String get maintenanceMessage =>
      _remoteConfig.getString(_maintenanceMessageKey);

  @override
  Duration get checkoutTimeout =>
      Duration(milliseconds: _remoteConfig.getInt(_checkoutTimeoutMsKey));
}
