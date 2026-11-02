/// Build-time configuration. Override with
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // 10.0.2.2 is the host machine as seen from the Android emulator.
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const appName = 'Devalay';
  static const freeDownloadLimit = 20;
  static const premiumProductIds = {'devalay_premium_monthly', 'devalay_premium_yearly'};
  static const sourceUrl = 'https://github.com/ChandraChaan/devalay';
}
