import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform;

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/router/app_router.dart';

/// PDF download / save / open — Android / iOS native storage; web uses FileSaver for bytes flows.
abstract final class PdfDownloadService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  );

  static BuildContext? _effectiveContext(BuildContext? context) {
    if (context != null && context.mounted) return context;
    final root = AppRouter.navigatorKey.currentContext;
    if (root != null && root.mounted) return root;
    return null;
  }

  static void _snack(BuildContext? ctx, String msg, {bool error = false}) {
    final c = _effectiveContext(ctx);
    if (c == null) return;
    ScaffoldMessenger.of(c).hideCurrentSnackBar();
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  /// Removes unsafe path segments and fixes extension.
  static String sanitizedPdfName(String fileName, {required String fallbackBase}) {
    var name = fileName.trim();
    if (name.isEmpty) name = fallbackBase;
    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }
    name = p.basename(name);
    name = name.replaceAll(RegExp(r'[^\w\-\.]'), '_');
    return name.replaceAll(RegExp(r'_+'), '_');
  }

  static String? refinedNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    for (final key in ['filename', 'name', 'file', 'fileName']) {
      final v = uri.queryParameters[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    if (seg != null && seg.trim().isNotEmpty && seg.contains('.')) {
      return seg.trim();
    }
    return null;
  }

  static String? parseFilenameFromContentDisposition(String? cd) {
    if (cd == null || cd.trim().isEmpty) return null;
    final ascii = RegExp(
      r'filename\s*=\s*"?([^\";]+)"?',
      caseSensitive: false,
    ).firstMatch(cd);
    if (ascii != null) return ascii.group(1)?.trim();
    final utf = RegExp(
      r"filename\*\s*=\s*UTF-8''([^;\s]+)",
      caseSensitive: false,
    ).firstMatch(cd);
    if (utf != null) {
      try {
        return Uri.decodeComponent(utf.group(1)!);
      } catch (_) {
        return utf.group(1)?.trim();
      }
    }
    return null;
  }

  static Future<void> _maybeRequestAndroidStorageForPublicPath(String targetPath) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final lower = targetPath.toLowerCase();
    if (lower.contains('/android/data/')) return;
    try {
      final st = await Permission.storage.status;
      if (st.isDenied || st.isRestricted) {
        await Permission.storage.request();
      }
    } catch (_) {}
  }

  static Future<Directory> _pdfTargetDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Native storage not used on web.');
    }

    if (Platform.isIOS) {
      final base = await getApplicationDocumentsDirectory();
      final pdfDir = Directory(p.join(base.path, 'pdfs'));
      if (!await pdfDir.exists()) await pdfDir.create(recursive: true);
      return pdfDir;
    }

    final downloadsRoot = await getDownloadsDirectory();
    if (downloadsRoot != null) {
      final dest = Directory(p.join(downloadsRoot.path, 'TiffinCRM'));
      if (!await dest.exists()) await dest.create(recursive: true);
      await _maybeRequestAndroidStorageForPublicPath(dest.path);
      return dest;
    }

    final external = await getExternalStorageDirectory();
    if (external != null) {
      final dest = Directory(p.join(external.path, 'Downloads', 'TiffinCRM'));
      if (!await dest.exists()) await dest.create(recursive: true);
      return dest;
    }

    final appDocs = await getApplicationDocumentsDirectory();
    final fallback = Directory(p.join(appDocs.path, 'Downloads', 'TiffinCRM'));
    if (!await fallback.exists()) await fallback.create(recursive: true);
    return fallback;
  }

  static Future<File> _targetFile(String displayName, {bool forceUniqueName = false}) async {
    final dir = await _pdfTargetDirectory();
    final safe = sanitizedPdfName(displayName, fallbackBase: 'document');
    var path = p.join(dir.path, safe);
    if (forceUniqueName) {
      final base = safe.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      for (var i = 2; i < 200; i++) {
        path = p.join(dir.path, '${base}_$i.pdf');
        if (!await File(path).exists()) break;
      }
    }
    return File(path);
  }

  static Future<String?> _promptExistingChoice(BuildContext dialogCtx, String existingPath) async {
    final name = p.basename(existingPath);
    final choice = await showDialog<String>(
      context: dialogCtx,
      builder: (c) => AlertDialog(
        title: const Text('PDF already downloaded'),
        content: Text('A file named $name already exists on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'open'),
            child: const Text('Open existing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'redownload'),
            child: const Text('Re-download'),
          ),
        ],
      ),
    );
    return choice;
  }

  static Future<String?> saveBytesAndOpen({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    final ctx = _effectiveContext(context);
    onProgress?.call(0);
    final name = sanitizedPdfName(fileName, fallbackBase: 'document');

    if (kIsWeb) {
      try {
        final stripe = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        await FileSaver.instance.saveFile(
          name: stripe,
          bytes: bytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
        if (ctx != null) {
          _snack(ctx, 'PDF downloaded: $name');
        }
        onProgress?.call(1);
        return stripe;
      } catch (e) {
        if (ctx != null) _snack(ctx, 'Could not save PDF: $e', error: true);
        return null;
      }
    }

    if (ctx == null) return null;

    var target = await _targetFile(name);
    if (await target.exists()) {
      final choice = await _promptExistingChoice(ctx, target.path);
      if (choice == null || choice == 'cancel') return null;
      if (choice == 'open') {
        await OpenFilex.open(target.path, type: 'application/pdf');
        _snack(ctx, 'Opened: ${p.basename(target.path)}');
        onProgress?.call(1);
        return target.path;
      }
      target = await _targetFile(name, forceUniqueName: true);
    }

    try {
      await target.writeAsBytes(bytes, flush: true);
      onProgress?.call(1);
      final result = await OpenFilex.open(target.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        _snack(ctx, 'Saved: ${p.basename(target.path)} (choose an app to open)');
      } else {
        _snack(ctx, 'PDF downloaded: ${p.basename(target.path)}');
      }
      return target.path;
    } catch (e) {
      _snack(ctx, 'Could not save PDF: $e', error: true);
      return null;
    }
  }

  static Future<String?> decodeBase64AndOpen({
    required BuildContext context,
    required String base64Payload,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    final trimmed = base64Payload.trim();
    if (trimmed.isEmpty) {
      _snack(_effectiveContext(context), 'PDF not available', error: true);
      return null;
    }
    try {
      final bytes = base64Decode(trimmed);
      return saveBytesAndOpen(
        context: context,
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
        onProgress: onProgress,
      );
    } catch (e) {
      _snack(_effectiveContext(context), 'Invalid PDF data: $e', error: true);
      return null;
    }
  }

  /// Handles HTTP(S) URLs and `data:application/pdf;base64,...` payloads.
  static Future<String?> downloadAndOpen({
    required BuildContext context,
    required String url,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    final outerCtx = _effectiveContext(context);
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _snack(outerCtx, 'PDF not available', error: true);
      return null;
    }

    if (trimmed.length >= 5 &&
        trimmed.substring(0, 5).toLowerCase() == 'data:') {
      final comma = trimmed.indexOf(',');
      if (comma == -1) {
        _snack(outerCtx, 'PDF not available', error: true);
        return null;
      }
      final meta = trimmed.substring(0, comma).toLowerCase();
      final data = trimmed.substring(comma + 1);
      if (!meta.contains('base64')) {
        _snack(outerCtx, 'Unsupported PDF encoding', error: true);
        return null;
      }
      return decodeBase64AndOpen(context: context, base64Payload: data, fileName: fileName);
    }

    if (kIsWeb) {
      _snack(outerCtx, 'On web, open the PDF URL in your browser.', error: false);
      return null;
    }

    final ctx = outerCtx;
    if (ctx == null) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _snack(ctx, 'Invalid PDF URL', error: true);
      return null;
    }

    final urlHint = refinedNameFromUrl(trimmed);
    String displayName = sanitizedPdfName(fileName, fallbackBase: 'document');
    if (urlHint != null) {
      displayName = sanitizedPdfName(urlHint, fallbackBase: 'document');
    }

    final progress = PdfDownloadProgressNotifier();
    String? resultPath;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        SchedulerBinding.instance.addPostFrameCallback((_) async {
          try {
            var targetFile = await _targetFile(displayName);
            if (await targetFile.exists()) {
              if (!dialogCtx.mounted) return;
              final choice = await _promptExistingChoice(dialogCtx, targetFile.path);
              if (choice == null || choice == 'cancel') {
                if (dialogCtx.mounted) Navigator.of(dialogCtx, rootNavigator: true).pop();
                return;
              }
              if (choice == 'open') {
                if (dialogCtx.mounted) Navigator.of(dialogCtx, rootNavigator: true).pop();
                await OpenFilex.open(targetFile.path, type: 'application/pdf');
                _snack(ctx, 'Opened: ${p.basename(targetFile.path)}');
                resultPath = targetFile.path;
                onProgress?.call(1);
                return;
              }
              targetFile = await _targetFile(displayName, forceUniqueName: true);
            }

            progress.setBytes(0, 0);

            Response<dynamic> response;
            try {
              response = await _dio.download(
                trimmed,
                targetFile.path,
                deleteOnError: true,
                onReceiveProgress: (c, t) {
                  progress.setBytes(c, t);
                  if (t > 0) onProgress?.call(c / t);
                },
              );
            } on DioException catch (e) {
              if (!dialogCtx.mounted) return;
              Navigator.of(dialogCtx, rootNavigator: true).pop();
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Could not download PDF: ${e.message ?? e}'),
                  action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () async {
                      if (!ctx.mounted) return;
                      await downloadAndOpen(
                        context: ctx,
                        url: url,
                        fileName: fileName,
                        onProgress: onProgress,
                      );
                    },
                  ),
                ),
              );
              return;
            }

            final cdHeader =
                response.headers.map['content-disposition']?.join('; ');
            final alt = parseFilenameFromContentDisposition(cdHeader);
            if (alt != null) {
              final altName = sanitizedPdfName(alt, fallbackBase: 'document');
              if (altName != displayName) {
                final newPath = p.join(p.dirname(targetFile.path), altName);
                if (newPath != targetFile.path) {
                  if (await File(newPath).exists()) {
                    await File(newPath).delete();
                  }
                  await targetFile.rename(newPath);
                  targetFile = File(newPath);
                  displayName = altName;
                }
              }
            }

            onProgress?.call(1);
            if (dialogCtx.mounted) Navigator.of(dialogCtx, rootNavigator: true).pop();

            resultPath = targetFile.path;
            final openResult =
                await OpenFilex.open(targetFile.path, type: 'application/pdf');
            if (openResult.type != ResultType.done) {
              _snack(ctx,
                  'Saved: ${p.basename(targetFile.path)} (open from Downloads / Files)');
            } else {
              _snack(ctx, 'PDF downloaded: ${p.basename(targetFile.path)}');
            }
          } catch (e) {
            if (dialogCtx.mounted) Navigator.of(dialogCtx, rootNavigator: true).pop();
            _snack(ctx, 'Could not download PDF: $e', error: true);
          }
        });

        return _PdfProgressDialog(
          titleName: displayName,
          notifier: progress,
        );
      },
    );

    return resultPath;
  }
}

/// Notifies `(receivedBytes, totalBytes)` for [LinearProgressIndicator].
class PdfDownloadProgressNotifier extends ChangeNotifier {
  int receivedBytes = 0;
  int totalBytes = 0;

  void setBytes(int received, int total) {
    receivedBytes = received;
    totalBytes = total;
    notifyListeners();
  }
}

class _PdfProgressDialog extends StatelessWidget {
  const _PdfProgressDialog({
    required this.titleName,
    required this.notifier,
  });

  final String titleName;
  final PdfDownloadProgressNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: notifier,
        builder: (context, _) {
          final total = notifier.totalBytes;
          final received = notifier.receivedBytes;
          final double? fract =
              total > 0 ? (received / total).clamp(0.0, 1.0) : null;
          final pct = fract != null ? '${(fract * 100).round()}%' : 'Starting…';

          return AlertDialog(
            title: const Text('Downloading PDF'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  titleName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: fract),
                const SizedBox(height: 8),
                Text('Progress: $pct', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }
}
