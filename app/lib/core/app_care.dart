/// Keeping the app current and asking for a rating, the Play way.
///
/// Updates: builds below Remote Config `min_version_code` are blocked by the update screen in
/// app.dart (force update). On top of that, Play installs use Google Play's in-app update flow
/// (full-screen when forced or high priority, in the background otherwise), and APK installs get a
/// gentle "new version" sheet when Remote Config `latest_version_code` is newer.
///
/// Rating: after real use (several opens over a few days) the Play in-app review card is shown at
/// most once every few months, with no question before it, as Play's guidelines require. The
/// "Rate Devalay" buttons open the Play listing directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase.dart';
import 'i18n.dart';
import 'storage.dart';
import 'theme.dart';

const playListingId = 'com.chandrachaan.devalay';

Future<bool> _fromPlay() async {
  try {
    return (await PackageInfo.fromPlatform()).installerStore == 'com.android.vending';
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Updates
// ---------------------------------------------------------------------------

/// Runs once per app start, after the first frame.
Future<void> checkForAppUpdate(BuildContext context, WidgetRef ref) async {
  try {
    final info = await ref.read(updateProvider.future);
    if (info.required) return; // the update screen in app.dart handles it
    if (await _fromPlay()) {
      final play = await InAppUpdate.checkForUpdate();
      if (play.updateAvailability != UpdateAvailability.updateAvailable) return;
      // Priority 4-5 (set per release in the Play Console) means "update now".
      if (play.updatePriority >= 4 && play.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      if (!play.flexibleUpdateAllowed || !_shouldOffer('${play.availableVersionCode}')) return;
      if (!context.mounted) return;
      final go = await _offerSheet(context, ref);
      if (go != true) return;
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success && context.mounted) _readyToInstall(context, ref);
      return;
    }
    if (info.latest > info.build && _shouldOffer('${info.latest}') && context.mounted) {
      final go = await _offerSheet(context, ref);
      if (go == true) await launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // No Play services (emulator, sideload) or offline: try again next start.
  }
}

/// Offer each new version at most every three days.
bool _shouldOffer(String version) {
  final key = 'update_offer_$version';
  final last = Boxes.stats.get(key) as int?;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (last != null && now - last < const Duration(days: 3).inMilliseconds) return false;
  Boxes.stats.put(key, now);
  return true;
}

Future<bool?> _offerSheet(BuildContext context, WidgetRef ref) {
  final lang = ref.read(prefsProvider).language;
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: Palette.sunrise),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              t3(
                lang,
                'A new version of Devalay is ready',
                'देवालय का नया संस्करण तैयार है',
                'దేవాలయం కొత్త వెర్షన్ సిద్ధంగా ఉంది',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              t3(
                lang,
                'New features, festival dates and fixes. It downloads in the background while you keep using the app.',
                'नई सुविधाएँ, त्योहार तिथियाँ और सुधार। ऐप चलाते हुए पीछे डाउनलोड होगा।',
                'కొత్త ఫీచర్లు, పండుగ తేదీలు, సవరణలు. మీరు యాప్ వాడుతుండగానే వెనుక డౌన్‌లోడ్ అవుతుంది.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(c, true),
                icon: const Icon(Icons.download_rounded),
                label: Text(t3(lang, 'Update now', 'अभी अपडेट करें', 'ఇప్పుడే అప్‌డేట్ చేయండి')),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t3(lang, 'Later', 'बाद में', 'తర్వాత'))),
          ],
        ),
      ),
    ),
  );
}

void _readyToInstall(BuildContext context, WidgetRef ref) {
  final lang = ref.read(prefsProvider).language;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(days: 1),
      content: Text(t3(lang, 'Update downloaded', 'अपडेट डाउनलोड हो गया', 'అప్‌డేట్ డౌన్‌లోడ్ అయింది')),
      action: SnackBarAction(
        label: t3(lang, 'Restart', 'रीस्टार्ट', 'మళ్లీ ప్రారంభించు'),
        onPressed: InAppUpdate.completeFlexibleUpdate,
      ),
    ),
  );
}

/// The forced update button: Play's own full-screen update when installed from Play, else [url].
Future<void> performForcedUpdate(String url) async {
  if (await _fromPlay()) {
    try {
      final play = await InAppUpdate.checkForUpdate();
      if (play.updateAvailability == UpdateAvailability.updateAvailable && play.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
    } catch (_) {}
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// ---------------------------------------------------------------------------
// Rating
// ---------------------------------------------------------------------------

/// Counts app opens and remembers the first one, for [maybeAskForReview].
void recordAppOpen() {
  final s = Boxes.stats;
  s.put('opens', (s.get('opens', defaultValue: 0) as int) + 1);
  s.put('first_open', s.get('first_open') ?? DateTime.now().millisecondsSinceEpoch);
}

/// Shows Play's in-app review card after real use: 6+ opens over 3+ days, at most every 120 days
/// and three times in all. Play itself may still decide not to show it.
Future<void> maybeAskForReview() async {
  try {
    final s = Boxes.stats;
    final opens = s.get('opens', defaultValue: 0) as int;
    final first = s.get('first_open') as int?;
    final last = s.get('review_asked') as int?;
    final times = s.get('review_count', defaultValue: 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (opens < 6 || first == null || now - first < const Duration(days: 3).inMilliseconds) return;
    if (times >= 3 || (last != null && now - last < const Duration(days: 120).inMilliseconds)) return;
    if (!await _fromPlay()) return;
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;
    await s.put('review_asked', now);
    await s.put('review_count', times + 1);
    await review.requestReview();
  } catch (_) {}
}

/// The "Rate Devalay" button: opens the Play listing, where the stars and review box are.
Future<void> rateApp() async {
  try {
    await InAppReview.instance.openStoreListing(appStoreId: playListingId);
  } catch (_) {
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$playListingId'),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Feedback goes to the public issue tracker, so nothing personal is sent from the app.
Future<void> sendFeedback() => launchUrl(
  Uri.parse('https://github.com/ChandraChaan/devalay/issues/new/choose'),
  mode: LaunchMode.externalApplication,
);
