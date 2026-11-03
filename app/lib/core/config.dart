/// Build-time configuration. Override with
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // 10.0.2.2 is the host machine as seen from the Android emulator.
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Serverless build: reads pre-rendered JSON (backend/scripts/export_static.py)
  /// from GitHub Pages instead of the live API. No accounts, sync or Premium.
  static const staticApi = bool.fromEnvironment('STATIC_API');
  static const privacyUrl = staticApi ? '$apiBaseUrl/privacy.html' : '$apiBaseUrl/privacy';
  static const appName = 'Devalay';
  static const freeDownloadLimit = staticApi ? 1000 : 20; // static builds cannot sell Premium
  static const premiumProductIds = {'devalay_premium_monthly', 'devalay_premium_yearly'};
  static const sourceUrl = 'https://github.com/ChandraChaan/devalay';
}
