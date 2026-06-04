import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract final class ReceiptPdfGenerator {
  /// Generates a daily tiffin receipt PDF and returns bytes for save/share.
  static Future<Uint8List> generateReceiptPdf({
    required String customerName,
    required String customerId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentStatus,
    required String businessName,
  }) async {
    final doc = pw.Document();
    final df = DateFormat('dd MMM yyyy');
    final timeDf = DateFormat('hh:mm a');
    const brandPrimaryDark = PdfColor.fromInt(0xFF5B21B6);
    const textDark = PdfColor.fromInt(0xFF0F172A);
    const textMuted = PdfColor.fromInt(0xFF64748B);
    const cardBg = PdfColor.fromInt(0xFFF8FAFC);
    const tableHeadBg = PdfColor.fromInt(0xFFEDE9FE);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);

    PdfColor statusColor(String status) {
      final s = status.toLowerCase();
      if (s.contains('paid') ||
          s.contains('success') ||
          s.contains('covered') ||
          s.contains('subscription')) {
        return PdfColors.green700;
      }
      if (s.contains('partial')) return PdfColors.orange700;
      if (s.contains('pending')) return PdfColors.orange700;
      if (s == '—' || s == '-') return PdfColors.grey700;
      return PdfColors.red700;
    }

    final cleanedItems = items
        .map((e) => <String, dynamic>{
              'name': e['name']?.toString() ??
                  e['itemName']?.toString() ??
                  e['slot']?.toString() ??
                  'Item',
              'qty': '${e['quantity'] ?? e['qty'] ?? 1}',
              'price': (() {
                final n = e['price'] ?? e['total'] ?? e['unitPrice'] ?? 0;
                return n is num ? n.toDouble() : double.tryParse('$n') ?? 0;
              })(),
            })
        .toList();
    final subTotal =
        cleanedItems.fold<double>(0, (sum, e) => sum + (e['price'] as double));
    final total = totalAmount > 0 ? totalAmount : subTotal;
    final receiptNo =
        'RC-${customerId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase()}-${DateFormat('yyyyMMdd').format(date)}';
    final paymentLabel = paymentStatus.isEmpty ? 'Pending' : paymentStatus;

    pw.Widget th(String t) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Text(
            t,
            style: pw.TextStyle(
              color: brandPrimaryDark,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10.5,
            ),
          ),
        );
    pw.Widget td(String t, {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            t,
            textAlign: align,
            style: const pw.TextStyle(color: textDark, fontSize: 10.2),
          ),
        );
    pw.Widget sumLine(
      String label,
      double value, {
      bool bold = false,
      PdfColor valueColor = textDark,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: textMuted,
                  fontSize: 10.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
              pw.Text(
                'Rs ${value.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  color: valueColor,
                  fontSize: 11,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        );

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: pw.BoxDecoration(
                color: cardBg,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: borderColor, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      color: brandPrimaryDark,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Daily Tiffin Receipt',
                    style: const pw.TextStyle(color: textMuted, fontSize: 11),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: borderColor, height: 1),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Customer: $customerName',
                              style:
                                  const pw.TextStyle(color: textDark, fontSize: 11),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Customer ID: $customerId',
                              style:
                                  const pw.TextStyle(color: textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: ${df.format(date)}',
                            style: const pw.TextStyle(color: textDark, fontSize: 10.5),
                          ),
                          pw.Text(
                            'Time: ${timeDf.format(DateTime.now())}',
                            style: const pw.TextStyle(color: textMuted, fontSize: 10),
                          ),
                          pw.Text(
                            receiptNo,
                            style: const pw.TextStyle(color: textMuted, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.8),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: tableHeadBg),
                  children: [th('Item name'), th('Qty'), th('Price')],
                ),
                ...cleanedItems.asMap().entries.map((entry) {
                  final i = entry.value;
                  final zebra = entry.key.isEven
                      ? PdfColors.white
                      : const PdfColor.fromInt(0xFFFDFDFF);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: zebra),
                    children: [
                      td(i['name'] as String),
                      td(i['qty'] as String, align: pw.TextAlign.center),
                      td(
                        'Rs ${(i['price'] as double).toStringAsFixed(2)}',
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: cardBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor, width: 0.8),
              ),
              child: pw.Column(
                children: [
                  sumLine('Subtotal', subTotal),
                  sumLine('Total', total, bold: true, valueColor: brandPrimaryDark),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: statusColor(paymentLabel)),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Text(
                    'Payment: $paymentLabel',
                    style: pw.TextStyle(
                      color: statusColor(paymentLabel),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Text(
              'Thank you for your business',
              style: const pw.TextStyle(color: textDark, fontSize: 11),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Generated by Tiffin CRM',
              style: const pw.TextStyle(color: textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }
}

