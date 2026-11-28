import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'account.dart';
import 'firebase.dart';
import 'i18n.dart';
import 'notifications.dart';
import 'storage.dart';
import 'usage.dart';
import 'about_you.dart';

/// What follows "About you" outside the profile screen: the copy in the owner's usage statistics, ad
/// consent for under-18s, the birthday wish and the Google backup. Runs at start and on every change.
class ProfileSync {
  static bool _started = false;

  /// Registers the listener and applies the saved profile once (after the first frame).
  static void start() {
    if (_started) return;
    _started = true;
    profileListeners.add(_apply);
    unawaited(_apply(AboutYou.fromMap(Boxes.prefs.get(AboutYouNotifier.key) as Map?), backup: false));
  }

  static Future<void> _apply(AboutYou p, {bool backup = true}) async {
    final today = DateTime.now();
    if (FirebaseServices.enabled) {
      // Usage.flush writes it only while the user shares usage statistics.
      Usage.trait('profile', p.isEmpty ? FieldValue.delete() : p.toInstall(today));
      await _adConsent(p, today);
      if (backup) {
        try {
          await Account.backup(p);
        } catch (e) {
          debugPrint('Profile: backup failed, kept on the phone: $e'); // offline; sent again on the next change
        }
      }
    }
    await _birthday(p, today);
  }

  /// Under-18s: Google Analytics may not use their data for ad personalisation and Meta's automatic app
  /// events stay off. Nobody's profile is ever sent to Analytics or Meta. Unknown ages change nothing.
  static Future<void> _adConsent(AboutYou p, DateTime today) async {
    if (p.ageOn(today) == null) return;
    final adult = !p.isMinorOn(today);
    try {
      await FirebaseAnalytics.instance.setConsent(
        adPersonalizationSignalsConsentGranted: adult,
        adUserDataConsentGranted: adult,
      );
      await FacebookAppEvents().setAutoLogAppEventsEnabled(adult);
    } catch (e) {
      debugPrint('Profile: ad consent not set: $e');
    }
  }

  static Future<void> _birthday(AboutYou p, DateTime today) async {
    try {
      final on = p.nextBirthday(today);
      final lang = Prefs.load(Boxes.prefs).language;
      final (title, body) = birthdayWish(lang, p.firstName);
      await Notifications.scheduleBirthday(on, title: title, body: body);
    } catch (e) {
      debugPrint('Profile: birthday reminder not set: $e');
    }
  }
}

/// The birthday notification and Home card text.
(String, String) birthdayWish(String lang, String firstName) {
  final title = firstName.isEmpty
      ? t3(lang, 'Happy birthday!', 'जन्मदिन की शुभकामनाएँ!', 'పుట్టినరోజు శుభాకాంక్షలు!')
      : t3(
          lang,
          'Happy birthday, {0}!',
          'जन्मदिन की शुभकामनाएँ, {0}!',
          '{0}, పుట్టినరోజు శుభాకాంక్షలు!',
        ).replaceAll('{0}', firstName);
  final body = t3(
    lang,
    'May the year ahead bring you good health, peace and joy. Begin the day with a prayer.',
    'आने वाला वर्ष आपके लिए अच्छा स्वास्थ्य, शांति और आनंद लाए। दिन की शुरुआत प्रार्थना से करें।',
    'రాబోయే సంవత్సరం మీకు ఆరోగ్యం, శాంతి, ఆనందం తేవాలి. రోజును ప్రార్థనతో మొదలుపెట్టండి.',
  );
  return ('🎂 $title', body);
}
