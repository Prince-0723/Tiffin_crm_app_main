import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'core/notifications/notification_badge_service.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'services/fcm_background_handler.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobile only — register before [Firebase.initializeApp] (FlutterFire).
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await initializeDateFormatting();
  DioClient.setNavigatorKey(AppRouter.navigatorKey);

  if (!kIsWeb) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        try {
          if (defaultTargetPlatform == TargetPlatform.android) {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.android,
            );
          } else {
            // iOS: add `ios/Runner/GoogleService-Info.plist` from Firebase Console.
            await Firebase.initializeApp();
          }
          await NotificationService().initFirebaseCloudMessaging();
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('[FCM] Firebase / FCM bootstrap failed: $e\n$st');
          }
        }
      default:
        break;
    }
  }

  try {
    await dotenv.load(fileName: 'assets/config/onesignal.env');
  } catch (e, st) {
    if (kDebugMode) debugPrint('dotenv load onesignal.env: $e\n$st');
  }
  final prefs = await SharedPreferences.getInstance();
  AppRouter.onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

  try {
    if (kIsWeb) {
      if (kDebugMode) debugPrint('[OneSignal] Push not initialized on web.');
    } else {
      await NotificationService().initOneSignal();
    }
  } catch (e, st) {
    if (kDebugMode) debugPrint('OneSignal init: $e\n$st');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await NotificationBadgeService.init();
  runApp(const ProviderScope(child: TiffinCrmApp()));
}
