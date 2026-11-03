import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'notifications.dart';

/// Crash reports, push announcements and force update, all through the Devalay
/// Firebase project. Firebase is optional: a build without google-services.json
/// (forks, tests) skips all of it and the app works as before.
class FirebaseServices {
  static bool enabled = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      enabled = true;
    } catch (e) {
      debugPrint('Firebase not configured: $e');
      return;
    }
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    // Notification messages arrive in the system tray by themselves while the app is in
    // the background; in the foreground Android shows nothing, so mirror them locally.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null) Notifications.announce(n.title ?? 'Devalay', n.body ?? '');
    });
  }

  /// Topics let the Firebase console target everyone, or one language's users.
  static Future<void> subscribe(String language) async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.subscribeToTopic('all');
      for (final lang in const ['te', 'hi', 'en']) {
        if (lang == language) {
          await messaging.subscribeToTopic('lang_$lang');
        } else {
          await messaging.unsubscribeFromTopic('lang_$lang');
        }
      }
    } catch (e) {
      debugPrint('FCM topic subscription failed: $e'); // offline; retried on next launch
    }
  }
}

class UpdateInfo {
  const UpdateInfo({required this.required, required this.url, required this.message});
  final bool required;
  final String url;
  final Map<String, String> message;
}

const _playUrl = 'https://play.google.com/store/apps/details?id=com.chandrachaan.devalay';
const _apkUrl = 'https://github.com/ChandraChaan/devalay/releases/latest/download/devalay.apk';

/// Remote Config `min_version_code`: builds below it must update before use.
final updateProvider = FutureProvider<UpdateInfo>((ref) async {
  const none = UpdateInfo(required: false, url: '', message: {});
  if (!FirebaseServices.enabled) return none;
  final rc = FirebaseRemoteConfig.instance;
  try {
    await rc.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
    );
    await rc.setDefaults(const {
      'min_version_code': 0,
      'update_message_te': '',
      'update_message_hi': '',
      'update_message_en': '',
    });
    await rc.fetchAndActivate();
  } catch (_) {
    // Offline: the last activated values (or defaults) still apply.
  }
  final info = await PackageInfo.fromPlatform();
  // Compare by version name: per-ABI APKs add 1000/2000/4000 to the build number, so it would
  // overstate the version. 1.2.3 -> 10203, matching release.yml and min_version_code.
  final build = versionCodeOf(info.version);
  final fromPlay = info.installerStore == 'com.android.vending';
  return UpdateInfo(
    required: build < rc.getInt('min_version_code'),
    url: fromPlay ? _playUrl : _apkUrl,
    message: {
      for (final l in const ['te', 'hi', 'en']) l: rc.getString('update_message_$l'),
    },
  );
});

int versionCodeOf(String version) {
  final p = version.split('+').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  while (p.length < 3) {
    p.add(0);
  }
  return p[0] * 10000 + p[1] * 100 + p[2];
}
