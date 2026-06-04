import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/jwt_payload_reader.dart';
import '../core/config/onesignal_config.dart';
import '../core/router/app_router.dart';
import '../core/router/app_routes.dart';
import '../core/storage/secure_storage.dart';
import '../features/auth/data/auth_api.dart';

/// OneSignal delivers most production pushes today; Firebase Cloud Messaging
/// integrates with `/users/fcm-token` so the backend can reach devices via `User.fcmToken`.
///
/// See `FCM_PUSH.md` for payload contract (`android.channel_id`, `click_action`, `data.screen`).
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Android 8+ — must match [AndroidManifest] `default_notification_channel_id`.
const String kFcmAndroidChannelId = 'tiffin_crm_channel';
const String kFcmAndroidChannelName = 'Tiffin CRM Notifications';

const AndroidNotificationChannel _kAndroidPushChannel = AndroidNotificationChannel(
  kFcmAndroidChannelId,
  kFcmAndroidChannelName,
  description: 'High-priority push for Tiffin CRM',
  importance: Importance.max,
  enableVibration: true,
  playSound: true,
  showBadge: true,
);

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._();
  static final NotificationService _instance = NotificationService._();

  static bool _oneSignalInitialized = false;
  static bool _fcmInitialized = false;
  static bool _localPluginReady = false;

  Future<void> _ensureLocalNotificationsInited() async {
    if (_localPluginReady) return;
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );
    _localPluginReady = true;
  }

  /// Call after [Firebase.initializeApp] (Android: with [DefaultFirebaseOptions.android], iOS: default / plist).
  Future<void> initFirebaseCloudMessaging() async {
    if (kIsWeb || _fcmInitialized) return;
    _fcmInitialized = true;

    await _ensureLocalNotificationsInited();
    await createNotificationChannel();

    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('[FCM] permission: ${settings.authorizationStatus}');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance.getAPNSToken();
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _maybeRotateTokenIfStale();
    await _registerCurrentFcmToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      unawaited(_persistAndUploadFcmToken(t));
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handlePayloadForNavigation(Map<String, dynamic>.from(message.data));
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handlePayloadForNavigation(Map<String, dynamic>.from(initial.data));
      });
    }
  }

  /// Android channel for FCM + local notifications (sound + vibration).
  Future<void> createNotificationChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_kAndroidPushChannel);
  }

  /// Heads-up when app is foreground (FCM does not show system banner on Android foreground).
  Future<void> showNotification(RemoteMessage message) async {
    final n = message.notification;
    final data = Map<String, String>.from(message.data);
    final title = n?.title ?? data['title'] ?? 'Tiffin CRM';
    final body = n?.body ??
        data['body'] ??
        data['message'] ??
        data['pushBody'] ??
        '';
    if (body.isEmpty) return;

    final merged = <String, dynamic>{
      ...data,
      if (n?.title != null) 'title': n!.title!,
      if (n?.body != null) 'body': n!.body!,
      'click_action': data['click_action'] ?? 'FLUTTER_NOTIFICATION_CLICK',
    };

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          kFcmAndroidChannelId,
          kFcmAndroidChannelName,
          channelDescription: _kAndroidPushChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notification',
          enableVibration: true,
          playSound: true,
          styleInformation: const DefaultStyleInformation(true, true),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(merged),
    );
  }

  static void _onLocalNotificationTapped(NotificationResponse response) {
    final p = response.payload;
    if (p == null || p.isEmpty) return;
    try {
      final map = jsonDecode(p) as Map<String, dynamic>;
      NotificationService().handlePayloadForNavigation(map);
    } catch (_) {}
  }

  void handlePayloadForNavigation(Map<String, dynamic> data) {
    _navigateFromPayload(data);
  }

  static const _prefsFcmRegisteredAtMs = 'fcm_registered_at_ms';
  static const _prefsLastFcmToken = 'last_fcm_token';

  Future<void> _maybeRotateTokenIfStale() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefsFcmRegisteredAtMs);
    if (ms == null) return;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (age.inDays < 30) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _registerCurrentFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) debugPrint('[FCM] FCM registration token: $token');
      if (token != null) await _persistAndUploadFcmToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] getToken failed: $e');
    }
  }

  Future<void> _persistAndUploadFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastFcmToken, token);
    await prefs.setInt(
      _prefsFcmRegisteredAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );

    final access = await SecureStorage.getAccessToken();
    if (access == null || access.isEmpty) return;

    try {
      await AuthApi.saveFcmToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] saveFcmToken API failed: $e');
    }
  }

  // ── OneSignal (existing) ───────────────────────────────────────────────

  Future<void> initOneSignal() async {
    if (kIsWeb) {
      if (kDebugMode) debugPrint('[OneSignal] skipped on web');
      return;
    }
    if (kOneSignalAppId.isEmpty ||
        kOneSignalAppId == 'YOUR_ACTUAL_ONESIGNAL_APP_ID_HERE') {
      if (kDebugMode) {
        debugPrint(
          '[OneSignal] App ID empty — set assets/config/onesignal.env or '
          '--dart-define=ONESIGNAL_APP_ID=...',
        );
      }
      return;
    }
    if (_oneSignalInitialized) return;

    OneSignal.initialize(kOneSignalAppId);

    if (!kIsWeb) {
      await _ensureLocalNotificationsInited();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await createNotificationChannel();
        if (kDebugMode) {
          debugPrint('[OneSignal] Android notification channel synced');
        }
      }
    }

    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final raw = event.notification.additionalData;
      final map = <String, dynamic>{};
      if (raw != null) {
        raw.forEach((k, v) => map[k.toString()] = v);
      }
      if (_isVendorAnnouncementPayload(map)) {
        event.preventDefault();
        final body = event.notification.body ??
            event.notification.title ??
            'New announcement from your vendor';
        _showAnnouncementForegroundSnack(body);
        return;
      }
      event.notification.display();
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (kDebugMode) {
        debugPrint('[OneSignal] click additionalData: $data');
      }
      if (data == null) return;
      final map = <String, dynamic>{};
      data.forEach((k, v) => map[k.toString()] = v);
      _navigateFromPayload(map);
    });

    _oneSignalInitialized = true;
    if (kDebugMode) debugPrint('[OneSignal] initialized');
  }

  static bool _isVendorAnnouncementPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final screen = data['screen']?.toString();
    return type == 'vendor_announcement' || screen == 'announcement';
  }

  void _showAnnouncementForegroundSnack(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = AppRouter.navigatorKey.currentContext;
      if (ctx == null) return;
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              try {
                GoRouter.of(ctx).go(AppRoutes.customerHome);
              } catch (_) {}
            },
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  void _navigateFromPayload(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = AppRouter.navigatorKey.currentContext;
      if (ctx == null) return;
      final router = GoRouter.of(ctx);
      if (_isVendorAnnouncementPayload(data)) {
        router.go(AppRoutes.customerHome);
        return;
      }
      final screen = data['screen']?.toString();
      switch (screen) {
        case 'orderDetail':
        case 'wallet':
        case 'subscriptions':
          router.go(AppRoutes.customerHome);
          break;
        case 'myDeliveries':
          router.go(AppRoutes.deliveryDashboard);
          break;
        case 'home':
          router.go(AppRoutes.dashboard);
          break;
        default:
          final route = data['route']?.toString();
          if (route != null && route.isNotEmpty) {
            router.go(route);
          } else {
            router.go(AppRoutes.notifications);
          }
      }
    });
  }

  Future<void> syncExternalIdAfterLogin() async {
    if (kIsWeb || kOneSignalAppId.isEmpty) return;
    if (kOneSignalAppId == 'YOUR_ACTUAL_ONESIGNAL_APP_ID_HERE') return;
    if (!_oneSignalInitialized) {
      try {
        await initOneSignal();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[OneSignal] re-init failed: $e\n$st');
        }
        return;
      }
    }
    if (!_oneSignalInitialized) return;
    try {
      final token = await SecureStorage.getAccessToken();
      final role = await SecureStorage.getUserRole();
      String? externalId;
      Map<String, dynamic> claims = {};

      if (token != null && token.isNotEmpty) {
        claims = readJwtPayload(token);
        if (role == 'customer') {
          final cid = claims['customerId']?.toString();
          if (cid != null && cid.isNotEmpty) externalId = cid;
        }
        externalId ??= claims['userId']?.toString();
      }
      externalId ??= await SecureStorage.getUserId();

      if (kDebugMode) {
        debugPrint('[OneSignal] Role: $role');
        debugPrint('[OneSignal] JWT Claims: $claims');
        debugPrint('[OneSignal] ExternalId being set: $externalId');
      }

      if (externalId != null && externalId.isNotEmpty) {
        await OneSignal.login(externalId);
        if (kDebugMode) {
          debugPrint('[OneSignal] login() called with: $externalId');
        }
      } else if (kDebugMode) {
        debugPrint(
          '[OneSignal] ERROR — externalId is null/empty, login skipped!',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[OneSignal] login error: $e');
    }
  }

  Future<void> registerTokenAfterLogin() async {
    await syncExternalIdAfterLogin();
    if (!_fcmInitialized) return;
    await _registerCurrentFcmToken();
  }

  static Future<void> logoutPushUser() async {
    if (kIsWeb || kOneSignalAppId.isEmpty) return;
    if (kOneSignalAppId == 'YOUR_ACTUAL_ONESIGNAL_APP_ID_HERE') return;
    try {
      await OneSignal.logout();
      if (kDebugMode) debugPrint('[OneSignal] logout');
    } catch (e) {
      if (kDebugMode) debugPrint('[OneSignal] logout error: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
