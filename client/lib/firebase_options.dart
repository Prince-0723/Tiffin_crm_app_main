// Android options from `android/app/google-services.json` (app `com.tiffin.crm.tiffin_crm`).
//
// iOS: add `ios/Runner/GoogleService-Info.plist`, then call `Firebase.initializeApp()`
// **without** Dart [FirebaseOptions] (see [main.dart]). Or run `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('FCM is not initialized for web.');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'On iOS use Firebase.initializeApp() without options once GoogleService-Info.plist is added.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjjSlpvwzPrOs8W1gDAjRkKAUAfZrDK68',
    appId: '1:146547626377:android:fea6eff34a1989cd615158',
    messagingSenderId: '146547626377',
    projectId: 'tiffin-crm-819fc',
    storageBucket: 'tiffin-crm-819fc.firebasestorage.app',
  );
}
