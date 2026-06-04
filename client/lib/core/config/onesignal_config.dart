import 'package:flutter_dotenv/flutter_dotenv.dart';

/// OneSignal App ID: `--dart-define=ONESIGNAL_APP_ID=...` (overrides) or
/// `assets/config/onesignal.env` after [dotenv.load] in [main].
String get kOneSignalAppId {
  const fromDefine = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '',
  );
  if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
  final fromFile = dotenv.env['ONESIGNAL_APP_ID']?.trim();
  if (fromFile != null && fromFile.isNotEmpty) return fromFile;
  return '';
}
