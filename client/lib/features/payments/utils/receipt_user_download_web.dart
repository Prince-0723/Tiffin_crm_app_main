// ignore: avoid_web_libraries_in_flutter — web-only implementation for PDF download.
import 'dart:html' as html;
import 'dart:typed_data';

/// Browser download via object URL (Chrome / web).
Future<String?> downloadReceiptPdfForUser(Uint8List bytes, String fileName) async {
  final safeName = fileName.trim().isEmpty ? 'Receipt.pdf' : fileName.trim();
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..download = safeName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return 'Saved via browser — check your Downloads folder.';
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
