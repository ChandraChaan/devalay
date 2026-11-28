import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase.dart';
import 'about_you.dart';
import 'usage.dart';

/// Optional Google sign-in for users, so "About you" is backed up and comes back after a reinstall or on
/// a new phone.
///
/// Every install already has an anonymous Firebase account (core/usage.dart). Signing in links Google to
/// it, so the account id, its usage summary and its support chat stay the same. On a second phone the
/// Google account is already linked elsewhere: the phone switches to that account and restores the backup.
/// The backup is one Firestore document, `profiles/{uid}`, that only its owner can read or write (not
/// even the admin screen). Signing out keeps the profile on the phone.
class Account {
  /// The Firebase project's web OAuth client, which Google sign-in on Android asks for the ID token of.
  static const webClientId = '729650365531-ch7t62hmm7ahqcla2jfvh5dam18v8msq.apps.googleusercontent.com';

  static Future<void>? _init;

  static User? get user {
    if (!FirebaseServices.enabled) return null;
    final u = FirebaseAuth.instance.currentUser;
    return u == null || u.isAnonymous ? null : u;
  }

  /// Google sign-in may be initialised only once per app run; the admin screen shares this.
  static Future<void> initGoogle() => _init ??= GoogleSignIn.instance.initialize(serverClientId: webClientId);

  static Future<OAuthCredential> _googleCredential() async {
    final g = GoogleSignIn.instance;
    await initGoogle();
    final account = await g.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw StateError('Google returned no ID token');
    return GoogleAuthProvider.credential(idToken: token);
  }

  /// Signs in with Google and reconciles the backup with the profile on the phone. Returns the profile
  /// the phone should now keep, or null to keep the one it has. Throws [GoogleSignInException] (cancelled
  /// or failed) and [FirebaseAuthException].
  static Future<AboutYou?> signIn(AboutYou local) async {
    final credential = await _googleCredential();
    final auth = FirebaseAuth.instance;
    // Write what this install has pending under its current id before the account can change.
    await Usage.flush();
    final current = auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use') rethrow;
        // This Google account already belongs to Devalay on another phone (or before a reinstall).
        await auth.signInWithCredential(e.credential ?? credential);
      }
    } else {
      await auth.signInWithCredential(credential);
    }
    return _reconcile(local);
  }

  /// Newest wins: a backup newer than the phone's profile replaces it; otherwise the phone's is uploaded.
  static Future<AboutYou?> _reconcile(AboutYou local) async {
    final cloud = await fetchBackup();
    if (cloud == null || cloud.isEmpty) {
      if (!local.isEmpty) await backup(local);
      return null;
    }
    final localTime = local.updated, cloudTime = cloud.updated;
    final cloudNewer = local.isEmpty || localTime == null || (cloudTime != null && cloudTime.isAfter(localTime));
    if (cloudNewer) return cloud;
    await backup(local);
    return null;
  }

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final u = user;
    return u == null ? null : FirebaseFirestore.instance.collection('profiles').doc(u.uid);
  }

  static Future<AboutYou?> fetchBackup() async {
    final doc = _doc();
    if (doc == null) return null;
    final snap = await doc.get();
    final data = snap.data();
    if (data == null) return null;
    final p = AboutYou.fromMap(data['p'] as Map?);
    final at = data['updated'];
    return at is Timestamp ? p.copyWith(updated: at.toDate().toUtc()) : p;
  }

  /// Keeps the backup in step with the phone; does nothing while signed out.
  static Future<void> backup(AboutYou p) async {
    final doc = _doc();
    if (doc == null) return;
    if (p.isEmpty) {
      await doc.delete();
      return;
    }
    final map = p.toMap()..remove('updated');
    await doc.set({'p': map, 'updated': FieldValue.serverTimestamp()});
  }

  /// Signs out of Google. The profile stays on the phone; usage statistics continue under a new
  /// anonymous id (if the user shares them).
  static Future<void> signOut() async {
    await Usage.flush();
    try {
      await initGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Account: Google sign-out: $e');
    }
    await FirebaseAuth.instance.signOut();
  }

  /// Deletes the account and everything stored under it: the backup, the usage statistics and the
  /// support chat. The profile on the phone is kept. Google may ask the user to sign in again first.
  static Future<void> deleteAccount() async {
    final u = user;
    if (u == null) return;
    final db = FirebaseFirestore.instance;
    await db.collection('profiles').doc(u.uid).delete();
    final chat = db.collection('support').doc(u.uid);
    while (true) {
      final page = await chat.collection('messages').limit(200).get();
      if (page.docs.isEmpty) break;
      final batch = db.batch();
      for (final d in page.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await chat.delete();
    await Usage.deleteMyData(deleteAccount: false);
    try {
      await u.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      await u.reauthenticateWithCredential(await _googleCredential());
      await u.delete();
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

/// The signed-in Google account, or null (signed out, or anonymous only).
final accountProvider = StreamProvider<User?>((ref) {
  if (!FirebaseServices.enabled) return Stream.value(null);
  return FirebaseAuth.instance.userChanges().map((u) => u == null || u.isAnonymous ? null : u);
});
