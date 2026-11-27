import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Debug builds started with `--dart-define=USE_EMULATORS=true` talk to the local Firebase emulators
/// (`firebase emulators:start` in the repository root) instead of the real project, so the admin
/// screen, usage reports and sendPush can be tried without touching real users or data. Release
/// builds never do: [kDebugMode] is false there, and the admin screen then offers Google sign-in only.
const useEmulators = kDebugMode && bool.fromEnvironment('USE_EMULATORS');

/// The host machine as the Android emulator sees it.
const _host = '10.0.2.2';

Future<void> connectEmulators({required String databaseUrl}) async {
  if (!useEmulators) return;
  FirebaseFirestore.instance.useFirestoreEmulator(_host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(_host, 9099);
  FirebaseFunctions.instanceFor(region: 'asia-south1').useFunctionsEmulator(_host, 5001);
  FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL: databaseUrl,
  ).useDatabaseEmulator(_host, 9000);
  debugPrint('Firebase: using the local emulators on $_host');
}
