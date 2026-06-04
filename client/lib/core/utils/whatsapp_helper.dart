import 'package:url_launcher/url_launcher.dart';

abstract final class WhatsAppHelper {
  /// Digits only, with country code (default India `91` for 10-digit local numbers).
  static String normalizeWhatsAppPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return '';
    if (clean.length == 10) return '91$clean';
    return clean;
  }

  static Future<void> openChat(String phone) async {
    final number = normalizeWhatsAppPhone(phone);
    if (number.isEmpty) return;
    final url = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens WhatsApp (or wa.me in browser) with [message] pre-filled for [phone].
  /// Returns `false` if the URL could not be launched (e.g. no handler).
  static Future<bool> openWithMessage(String phone, String message) async {
    final number = normalizeWhatsAppPhone(phone);
    if (number.isEmpty) return false;
    final enc = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$number?text=$enc');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Opens the device phone dialer with [phone] (digits / + prefix preserved).
  static Future<bool> callPhone(String phone) async {
    var d = phone.replaceAll(RegExp(r'[\s\-().]'), '');
    d = d.replaceAll(RegExp(r'[^\d+]'), '');
    if (d.replaceAll('+', '').isEmpty) return false;
    final uri = Uri.parse('tel:$d');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Low balance message template for customer.
  static String lowBalanceMessage(String name, num balance) {
    return 'Hi $name, your TiffinCRM wallet balance is ₹$balance. '
        'Please add money to continue receiving your daily tiffin. 🙏';
  }
}
