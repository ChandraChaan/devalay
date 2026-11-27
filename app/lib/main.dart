import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/api.dart';
import 'core/app_care.dart';
import 'core/config.dart';
import 'core/firebase.dart';
import 'core/names.dart';
import 'core/notifications.dart';
import 'core/storage.dart';
import 'core/usage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Boxes.init();
  await initDates();
  recordAppOpen();
  // Accounts exist only with a server; the public (static) build never stores a token, so it skips
  // the Keystore read.
  if (!AppConfig.staticApi) await TokenStore.load();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.chandrachaan.devalay.audio',
    androidNotificationChannelName: 'Bhakti playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notification',
  );
  await FirebaseServices.init();
  unawaited(Usage.init());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: DevalayApp()));
  // Since Flutter 3.29 Dart runs on Android's main thread, so work done before runApp keeps the
  // splash up and touches unanswered. What the first screen doesn't need waits for its first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(Notifications.init().catchError((Object e) => debugPrint('Notifications not ready: $e')));
    unawaited(FirebaseServices.subscribe(Prefs.load(Boxes.prefs).language, force: false));
    unawaited(pruneHttpCache());
  });
}
