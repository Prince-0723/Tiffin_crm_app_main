import 'dart:typed_data';

import '../../../core/router/app_router.dart';
import '../../../services/pdf_download_service.dart';

/// Saves receipt bytes via [PdfDownloadService] (open with system PDF viewer on mobile/desktop).
Future<String?> downloadReceiptPdfForUser(Uint8List bytes, String fileName) async {
  final ctx = AppRouter.navigatorKey.currentContext;
  if (ctx == null) return null;
  try {
    return PdfDownloadService.saveBytesAndOpen(
      context: ctx,
      bytes: bytes,
      fileName: fileName,
    );
  } catch (_) {
    return null;
  }
}
