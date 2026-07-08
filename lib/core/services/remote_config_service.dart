import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kPaywallEnabled = 'paywall_enabled';

class RemoteConfigService {
  RemoteConfigService._(this._rc);

  final FirebaseRemoteConfig _rc;

  static Future<RemoteConfigService> init() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults({_kPaywallEnabled: true});
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ),
    );
    try {
      await rc.fetchAndActivate();
    } catch (e) {
      debugPrint(
        'RemoteConfig: fetch failed, using cached/default values — $e',
      );
    }
    return RemoteConfigService._(rc);
  }

  static Future<RemoteConfigService> initSafe() async {
    try {
      return await init();
    } catch (e) {
      debugPrint('RemoteConfig: init failed, using instance defaults - $e');
      return RemoteConfigService._(FirebaseRemoteConfig.instance);
    }
  }

  bool get paywallEnabled => _rc.getBool(_kPaywallEnabled);
}

final remoteConfigProvider = Provider<RemoteConfigService>(
  (_) => throw UnimplementedError('Call initRemoteConfig() in main'),
);
