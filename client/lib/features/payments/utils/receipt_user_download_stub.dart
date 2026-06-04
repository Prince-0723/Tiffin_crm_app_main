import 'dart:typed_data';

/// Fallback (should not run in Flutter web / mobile builds).
Future<String?> downloadReceiptPdfForUser(Uint8List bytes, String fileName) async =>
    null;
