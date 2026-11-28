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

  /// Opens WhatsApp (or WhatsApp Business) with the file at [path]; false when neither is installed.
  static Future<bool> shareToWhatsApp(String path, {required String mime, String? text}) async =>
      await _ch.invokeMethod<bool>('shareToWhatsApp', {'path': path, 'mime': mime, 'text': text}) ?? false;

  static Future<int> sdkInt() async => await _ch.invokeMethod<int>('sdkInt') ?? 0;

  /// The phone's approximate position for "Use my location", asking for coarse location permission
  /// first. Throws a [PlatformException] with code DENIED, OFF or UNAVAILABLE.
  static Future<({double lat, double lon})?> approxLocation() async {
    final m = await _ch.invokeMapMethod<String, double>('approxLocation');
    if (m == null || m['lat'] == null || m['lon'] == null) return null;
    return (lat: m['lat']!, lon: m['lon']!);
  }

  /// Phone model, Android API level and memory, for usage statistics. Null off Android.
  static Future<({String model, int sdk, int ramMb})?> deviceInfo() async {
    try {
      final m = await _ch.invokeMapMethod<String, Object>('deviceInfo');
      if (m == null) return null;
      return (
        model: '${m['model'] ?? ''}',
        sdk: (m['sdk'] as num?)?.toInt() ?? 0,
        ramMb: (m['ramMb'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
