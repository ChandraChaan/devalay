import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/api.dart';
import 'core/app_care.dart';
import 'core/firebase.dart';
import 'core/names.dart';
import 'core/notifications.dart';
import 'core/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Boxes.init();
  await initDates();
  recordAppOpen();
  await TokenStore.load();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.chandrachaan.devalay.audio',
    androidNotificationChannelName: 'Bhakti playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notification',
  );
  await Notifications.init();
  await FirebaseServices.init();
  unawaited(FirebaseServices.subscribe(Prefs.load(Boxes.prefs).language));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: DevalayApp()));
}
