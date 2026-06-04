import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Android device using OS `Platform` (IO targets only).
bool get isAndroidDevice => !kIsWeb && Platform.isAndroid;
