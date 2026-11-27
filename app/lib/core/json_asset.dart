import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;

/// A bundled JSON file as a map. Since Flutter 3.29, Dart runs on Android's main thread, so
/// parsing a large file there holds up touches and drawing: thoughts.json (690 KB) is read for
/// Home on every launch. Files over [_inline] bytes are parsed on a short-lived background
/// isolate instead, and the result is handed back without a copy.
Future<Map> loadJsonAsset(String path) async {
  final text = await rootBundle.loadString(path);
  if (text.length < _inline) return jsonDecode(text) as Map;
  return Isolate.run(() => jsonDecode(text) as Map);
}

const _inline = 32 * 1024;
