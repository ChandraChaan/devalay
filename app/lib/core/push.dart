import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase.dart';
import 'usage.dart';

/// Messages the owner sends from the admin screen ("campaigns", functions/index.js). Each carries
/// its campaign id `c` and an optional in-app link `link` (devalay://panchang) in its data.

/// The local-notification payload for a push shown while the app is open: `push|campaign|link`.
String pushPayload(Map<String, dynamic> data) => 'push|${data['c'] ?? ''}|${data['link'] ?? ''}';

/// The campaign id and link from [pushPayload], or null for other payloads.
({String campaign, String link})? parsePushPayload(String payload) {
  if (!payload.startsWith('push|')) return null;
  final parts = payload.split('|');
  return (campaign: parts.length > 1 ? parts[1] : '', link: parts.length > 2 ? parts.sublist(2).join('|') : '');
}

/// The app route for a push link: devalay://panchang → /panchang. Null for no link or anything else.
String? pushRoute(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.scheme != 'devalay' || uri.host.isEmpty) return null;
  final path = '/${uri.host}${uri.path}'.replaceFirst(RegExp(r'(?<=.)/+$'), '');
  return RegExp(r'^/[a-z0-9/_\-]+$').hasMatch(path) ? path : null;
}

final _campaignId = RegExp(r'^[A-Za-z0-9]{8,40}$');

/// push_open: counted in Analytics, in the usage log, and on the campaign itself (one increment,
/// which the rules allow any signed-in install to make) so the admin screen shows the open rate.
void logPushOpen(String campaign, {required bool coldStart}) {
  Usage.record('push_open', item: campaign, params: {'campaign': campaign, 'cold_start': coldStart ? 1 : 0});
  if (!FirebaseServices.enabled || !_campaignId.hasMatch(campaign)) return;
  if (FirebaseAuth.instance.currentUser == null) return;
  unawaited(
    FirebaseFirestore.instance
        .collection('campaigns')
        .doc(campaign)
        .update({'opens': FieldValue.increment(1)})
        .catchError((Object e) => debugPrint('push open not counted: $e')),
  );
}
