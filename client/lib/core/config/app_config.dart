abstract final class AppConfig {
  /// Set to true for local backend (e.g. http://localhost:5800), false for Render.
  static const bool useLocalApi = false;

  static const String apiUrlLocal = 'http://localhost:5800/api/v1';
  static const String apiUrlProduction =
      'https://tiffin-crm-app.onrender.com/api/v1';

  static String get baseUrl => useLocalApi ? apiUrlLocal : apiUrlProduction;

  /// Origin for Socket.IO (no `/api/v1` path). Used by `DeliveryTrackingSocket`.
  static String get socketOrigin {
    final u = Uri.parse(baseUrl);
    if (u.hasPort) {
      return '${u.scheme}://${u.host}:${u.port}';
    }
    return '${u.scheme}://${u.host}';
  }

  static const String fcmSenderId = String.fromEnvironment(
    'FCM_SENDER_ID',
    defaultValue: '',
  );

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'YOUR_RAZORPAY_KEY_ID',
  );
}
