import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readReceiptLogoFromFilePath(String path) async {
  if (path.isEmpty) return null;
  try {
    final f = File(path);
    if (await f.exists()) return await f.readAsBytes();
  } catch (_) {}
  return null;
}
