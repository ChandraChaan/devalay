import 'dart:io';

import 'package:devalay/core/storage.dart';
import 'package:hive_ce/hive.dart';

/// Opens the app's Hive boxes in a temporary directory for tests.
Future<void> initTestStorage() async {
  final dir = await Directory.systemTemp.createTemp('devalay-test');
  Hive.init(dir.path);
  Boxes.prefs = await Hive.openBox('prefs');
  Boxes.cache = await Hive.openBox('http_cache');
  Boxes.favorites = await Hive.openBox('favorites');
  Boxes.downloads = await Hive.openBox('downloads');
  Boxes.stats = await Hive.openBox('stats');
  Boxes.events = await Hive.openBox('events');
  await Boxes.prefs.put('device_id', 'test-device-123456');
}
