import 'package:flutter/services.dart';

/// Android-only system integrations implemented in MainActivity.kt.
class NativeBridge {
  static const _ch = MethodChannel('devalay/system');

  /// [target]: 1 = home screen, 2 = lock screen, 3 = both.
  static Future<void> setWallpaper(String path, int target) =>
      _ch.invokeMethod('setWallpaper', {'path': path, 'target': target});

  /// Saves an image into Pictures/Devalay so it appears in the gallery.
  static Future<String?> saveImage(String path, String name) =>
      _ch.invokeMethod<String>('saveImage', {'path': path, 'name': name});

  /// Android requires the "Modify system settings" special permission to change ringtones.
  static Future<bool> canWriteSettings() async => await _ch.invokeMethod<bool>('canWriteSettings') ?? false;
  static Future<void> openWriteSettings() => _ch.invokeMethod('openWriteSettings');

  /// [type]: "ringtone", "notification" or "alarm".
  static Future<void> setRingtone(String path, String title, String type) =>
      _ch.invokeMethod('setRingtone', {'path': path, 'title': title, 'type': type});

  static Future<int> sdkInt() async => await _ch.invokeMethod<int>('sdkInt') ?? 0;
}
