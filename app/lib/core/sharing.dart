/// Sharing Devalay: every share carries a Play link, so a forwarded Panchang or festival card can
/// bring the next install.
///
/// The link's install referrer (utm_source=devalay_app, utm_medium=share, utm_campaign=<what was
/// shared>) shows up in Play Console's acquisition reports, which show which shares bring installs.
library;

import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_care.dart';
import 'native.dart';
import 'i18n.dart';
import 'storage.dart';
import 'usage.dart';

/// The Play listing with an install referrer naming what was shared ('panchang', 'wish', ...).
String playLink(String campaign) {
  final referrer = 'utm_source=devalay_app&utm_medium=share&utm_campaign=$campaign';
  return 'https://play.google.com/store/apps/details?id=$playListingId'
      '&referrer=${Uri.encodeComponent(referrer)}';
}

/// The last lines of every shared text: the app's name and its Play link.
String shareFooter(String campaign) => '🪔 Devalay\n${playLink(campaign)}';

/// The invitation text for "Share Devalay", in the reader's language.
String inviteText(String lang) =>
    '${t3(lang, 'Devalay: Panchang, festival calendar, aartis and bhakti in your language.', 'देवालय: आपकी भाषा में पंचांग, त्योहार कैलेंडर, आरती और भक्ति।', 'దేవాలయం: మీ భాషలో పంచాంగం, పండుగల క్యాలెండర్, హారతులు, భక్తి.')}\n'
    '${playLink('invite')}';

/// Opens WhatsApp with [text] ready to send; falls back to the system share sheet when WhatsApp
/// is not installed or cannot be opened.
Future<void> shareOnWhatsApp(String text) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalNonBrowserApplication,
    );
  } catch (_) {}
  if (!opened) await SharePlus.instance.share(ShareParams(text: text));
  markShared();
}

/// "Share Devalay": WhatsApp first, since that is where Panchang and festival wishes travel.
Future<void> shareApp(String lang) {
  Usage.record('share_app');
  return shareOnWhatsApp(inviteText(lang));
}

/// Shares [text] (and [files]) through the system share sheet; a completed share counts as a
/// happy moment for [markShared].
///
/// [what] names the thing shared ("status", "wish", "song") in the usage log.
Future<void> shareContent(String text, {List<XFile>? files, String? what}) async {
  if (what != null) Usage.record('share_open', item: what);
  final result = await SharePlus.instance.share(ShareParams(text: text, files: files));
  if (result.status == ShareResultStatus.success) markShared(what);
}

/// Remembers that the user shared something; a share is a good moment for the review card.
void markShared([String? what]) {
  Usage.record('share', item: what);
  Boxes.stats.put('shares', (Boxes.stats.get('shares', defaultValue: 0) as int) + 1);
  Future.delayed(const Duration(seconds: 2), () => maybeAskForReview(happy: true));
}

/// Whether the home screen's "Share Devalay" card should show: from the second day of use, until
/// the user has shared the app or closed the card.
bool get showShareAppCard {
  final s = Boxes.stats;
  if (s.get('share_card_closed') == true || (s.get('shares', defaultValue: 0) as int) > 0) return false;
  final first = s.get('first_open') as int?;
  if (first == null) return false;
  return DateTime.now().millisecondsSinceEpoch - first >= const Duration(hours: 20).inMilliseconds &&
      (s.get('opens', defaultValue: 0) as int) >= 2;
}

void closeShareAppCard() => Boxes.stats.put('share_card_closed', true);

/// One tap to WhatsApp: hands [file] straight to WhatsApp, where "My status" is the first choice, and
/// falls back to the system share sheet when WhatsApp is not installed. [what] names the item in the
/// usage log ('status_video:monday-shiva', 'wallpaper:lakshmi-1930').
Future<void> shareFileToWhatsApp(File file, {required String mime, String? text, required String what}) async {
  Usage.record('share_whatsapp', item: what);
  var opened = false;
  if (Platform.isAndroid) {
    try {
      opened = await NativeBridge.shareToWhatsApp(file.path, mime: mime, text: text);
    } catch (_) {}
  }
  if (opened) {
    markShared(what);
  } else {
    await shareContent(
      text ?? '',
      files: [XFile(file.path, mimeType: mime)],
      what: what,
    );
  }
}
