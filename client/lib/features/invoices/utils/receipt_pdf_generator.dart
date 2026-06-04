import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'receipt_local_logo.dart';

/// Professional A4 receipt PDF. Embedded DejaVu Sans (includes U+20B9 rupee glyph).
abstract final class ReceiptPdfGenerator {
  static const int _rupeeCodePoint = 0x20B9;
  static String get _rupee => String.fromCharCode(_rupeeCodePoint);

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    var s = '$v'.replaceAll(_rupee, '').trim();
    s = s.replaceAll(RegExp(r'Rs\.?\s*', caseSensitive: false), '').trim();
    s = s.replaceAll(',', '');
    return double.tryParse(s) ?? 0;
  }

  /// Indian rupee sign + amount (DejaVu renders U+20B9 correctly).
  static String _money(double v) => '$_rupee${v.toStringAsFixed(2)}';

  static String _stripRupeeGlyphs(String s) {
    return s
        .replaceAll(_rupee, '')
        .replaceAll(RegExp(r'Rs\.?\s*', caseSensitive: false), '')
        .trim();
  }

  static String _ddMmYyyy(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  static String _fmtParsedDate(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return _stripRupeeGlyphs(v.toString());
    return _ddMmYyyy(dt);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }
    return ('${parts[0].isNotEmpty ? parts[0][0] : ''}'
            '${parts[1].isNotEmpty ? parts[1][0] : ''}')
        .toUpperCase();
  }

  static Future<Uint8List> generate(Map<String, dynamic> receiptData) async {
    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final boldFontData = await rootBundle.load(
      'assets/fonts/DejaVuSans-Bold.ttf',
    );
    final font = pw.Font.ttf(fontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final purple = PdfColor.fromHex('#6D28D9');
    final purpleDark = PdfColor.fromHex('#4C1D95');
    final purpleLight = PdfColor.fromHex('#EDE9FE');
    final purpleMid = PdfColor.fromHex('#8B5CF6');
    final grayText = PdfColor.fromHex('#6B7280');
    final darkText = PdfColor.fromHex('#1F1235');
    final borderColor = PdfColor.fromHex('#DDD6FE');
    final grayLight = PdfColor.fromHex('#F8F7FF');
    final white = PdfColor.fromHex('#FFFFFF');

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final generatedStr =
        '$dateStr ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final receipt = (receiptData['receipt'] is Map)
        ? Map<String, dynamic>.from(receiptData['receipt'] as Map)
        : <String, dynamic>{};
    final vendor = (receiptData['vendor'] is Map)
        ? Map<String, dynamic>.from(receiptData['vendor'] as Map)
        : <String, dynamic>{};
    final customer = (receiptData['customer'] is Map)
        ? Map<String, dynamic>.from(receiptData['customer'] as Map)
        : <String, dynamic>{};
    final subscription = (receiptData['subscription'] is Map)
        ? Map<String, dynamic>.from(receiptData['subscription'] as Map)
        : <String, dynamic>{};
    final summary = (receiptData['summary'] is Map)
        ? Map<String, dynamic>.from(receiptData['summary'] as Map)
        : <String, dynamic>{};
    final deliveries = (receiptData['deliveries'] as List?) ?? const [];
    final paymentHistory = (receiptData['paymentHistory'] as List?) ?? const [];

    final businessName = _stripRupeeGlyphs(
      vendor['businessName']?.toString().trim() ?? 'Business',
    );
    final phone = _stripRupeeGlyphs(vendor['phone']?.toString().trim() ?? '');
    final city = _stripRupeeGlyphs(vendor['city']?.toString().trim() ?? '');
    final cityLine = [phone, city].where((s) => s.isNotEmpty).join(' | ');

    String subscriptionLine() {
      final planName = _stripRupeeGlyphs(
        subscription['planName']?.toString().trim() ?? '',
      );
      final planType = _stripRupeeGlyphs(
        subscription['planType']?.toString().trim() ?? '',
      );
      if (planName.isEmpty && planType.isEmpty) return '';
      if (planType.isEmpty) return planName;
      if (planName.isEmpty) return planType;
      return '$planName · $planType';
    }

    final subscriptionDisplay = subscriptionLine();

    Uint8List? logoBytes;
    final logoPath = vendor['logoPath']?.toString().trim();
    if (logoPath != null && logoPath.isNotEmpty) {
      if (logoPath.startsWith('assets/')) {
        try {
          final d = await rootBundle.load(logoPath);
          logoBytes = d.buffer.asUint8List();
        } catch (_) {}
      } else {
        final fromFile = await readReceiptLogoFromFilePath(logoPath);
        if (fromFile != null && fromFile.isNotEmpty) logoBytes = fromFile;
      }
    }
    if (logoBytes == null || logoBytes.isEmpty) {
      final logoUrl = vendor['logoUrl']?.toString();
      if (logoUrl != null && logoUrl.startsWith('http') && logoUrl.isNotEmpty) {
        try {
          final dio = Dio();
          final res = await dio.get<List<int>>(
            logoUrl,
            options: Options(
              responseType: ResponseType.bytes,
              receiveTimeout: const Duration(seconds: 8),
            ),
          );
          final bytes = res.data;
          if (bytes != null && bytes.isNotEmpty) {
            logoBytes = Uint8List.fromList(bytes);
          }
        } catch (_) {}
      }
    }

    final receiptNo = _stripRupeeGlyphs(
      receipt['receiptNumber']?.toString() ?? '—',
    );
    final receiptDate = _fmtParsedDate(receipt['date'] ?? receiptData['date']);

    final subtotal = _num(summary['subtotal'] ?? receiptData['subtotal']);
    final tax = _num(summary['taxAmount'] ?? receiptData['tax']);
    final grandTotal = _num(summary['grandTotal'] ?? receiptData['grandTotal']);
    final paidAmount = _num(summary['paidAmount'] ?? receiptData['paidAmount']);
    final amountDue = _num(summary['dueAmount'] ?? receiptData['dueAmount']);
    final runningBalance = _num(
      summary['runningBalance'] ?? receiptData['runningBalance'],
    );

    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: font,
      bold: boldFont,
      italic: font,
      boldItalic: boldFont,
    );

    final pdf = pw.Document(theme: theme);

    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 18 * PdfPageFormat.mm,
      marginRight: 18 * PdfPageFormat.mm,
      marginTop: 14 * PdfPageFormat.mm,
      marginBottom: 14 * PdfPageFormat.mm,
    );

    pw.Widget logoBox() {
      final bytes = logoBytes;
      if (bytes != null && bytes.isNotEmpty) {
        final logoImage = pw.MemoryImage(bytes);
        return pw.Container(
          width: 50,
          height: 50,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 8,
            verticalRadius: 8,
            child: pw.Image(logoImage, fit: pw.BoxFit.cover),
          ),
        );
      }
      return pw.Container(
        width: 50,
        height: 50,
        decoration: pw.BoxDecoration(
          color: purpleLight,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: purpleMid, width: 1),
        ),
        child: pw.Center(
          child: pw.Text(
            _initials(businessName),
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              color: purpleDark,
            ),
          ),
        ),
      );
    }

    pw.Widget hr() =>
        pw.Container(height: 0.6, color: borderColor, width: double.infinity);

    pw.Widget billToCard() {
      return pw.Container(
        decoration: pw.BoxDecoration(
          color: purpleLight,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: borderColor),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BILL TO',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8.5,
                color: purple,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              _stripRupeeGlyphs(customer['name']?.toString() ?? '—'),
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 11,
                color: darkText,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _stripRupeeGlyphs(
                '${customer['phone'] ?? ''} | ${customer['address'] ?? ''}',
              ),
              style: pw.TextStyle(font: font, fontSize: 9.5, color: grayText),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Customer Code: ${_stripRupeeGlyphs(customer['customerCode']?.toString() ?? '—')}',
              style: pw.TextStyle(font: font, fontSize: 9, color: grayText),
            ),
            pw.Text(
              'Subscription: ${subscriptionDisplay.isEmpty ? '—' : subscriptionDisplay}',
              style: pw.TextStyle(font: font, fontSize: 9, color: grayText),
            ),
            pw.Text(
              'Delivery Slot: ${_stripRupeeGlyphs(subscription['deliverySlot']?.toString() ?? '')}',
              style: pw.TextStyle(font: font, fontSize: 9, color: grayText),
            ),
          ],
        ),
      );
    }

    pw.Widget thCell(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        t,
        style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: white),
        textAlign: t == 'Item Name' ? pw.TextAlign.left : pw.TextAlign.right,
      ),
    );

    pw.Widget tdCell(
      String t,
      PdfColor color, {
      pw.TextAlign align = pw.TextAlign.left,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        t,
        style: pw.TextStyle(font: font, fontSize: 9.5, color: color),
        textAlign: align,
      ),
    );

    pw.Widget itemsSection(Map<String, dynamic> slot) {
      final items = (slot['items'] as List?) ?? const [];
      final slotTitle = _stripRupeeGlyphs(
        '${slot['slot'] ?? 'MEAL'}'.toUpperCase(),
      );

      double lineTotal(Map<String, dynamic> it) {
        final t = _num(it['total']);
        if (t > 0) return t;
        final q = _num(it['quantity']);
        final up = _num(it['unitPrice']);
        return q * up;
      }

      double slotSub = 0;
      for (final e in items) {
        if (e is Map) slotSub += lineTotal(Map<String, dynamic>.from(e));
      }
      if (slotSub <= 0 && slot['slotTotal'] != null) {
        slotSub = _num(slot['slotTotal']);
      }

      final dataRows = <pw.TableRow>[];
      var idx = 0;
      for (final e in items) {
        if (e is! Map) continue;
        final it = Map<String, dynamic>.from(e);
        final bg = idx.isEven ? white : grayLight;
        idx++;
        dataRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              tdCell(
                _stripRupeeGlyphs('${it['name'] ?? '—'}'),
                darkText,
                align: pw.TextAlign.left,
              ),
              tdCell(
                _stripRupeeGlyphs('${it['quantity'] ?? '—'}'),
                darkText,
                align: pw.TextAlign.right,
              ),
              tdCell(
                _stripRupeeGlyphs('${it['unit'] ?? '—'}'),
                darkText,
                align: pw.TextAlign.right,
              ),
              tdCell(
                _money(_num(it['unitPrice'])),
                darkText,
                align: pw.TextAlign.right,
              ),
              tdCell(
                _money(lineTotal(it)),
                darkText,
                align: pw.TextAlign.right,
              ),
            ],
          ),
        );
      }

      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borderColor, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: purple,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  slotTitle,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    color: white,
                  ),
                ),
              ),
            ),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: borderColor,
                  width: 0.35,
                ),
                verticalInside: pw.BorderSide(color: borderColor, width: 0.35),
                left: pw.BorderSide(color: borderColor, width: 0.35),
                right: pw.BorderSide(color: borderColor, width: 0.35),
                bottom: pw.BorderSide(color: borderColor, width: 0.35),
                top: pw.BorderSide.none,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(1.7),
                4: pw.FlexColumnWidth(1.7),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: purpleMid),
                  verticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    thCell('Item Name'),
                    thCell('Qty'),
                    thCell('Unit'),
                    thCell('Unit Price'),
                    thCell('Total'),
                  ],
                ),
                ...dataRows,
              ],
            ),
            pw.Container(
              color: purpleLight,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Slot subtotal: ${_money(slotSub)}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 11,
                    color: purpleDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget totalsBlock() {
      pw.Widget row(
        String label,
        String value, {
        bool useBold = false,
        double fs = 10,
        PdfColor? labelColor,
        PdfColor? valueColor,
        PdfColor? bg,
        pw.EdgeInsets? pad,
      }) {
        return pw.Container(
          color: bg,
          padding:
              pad ?? const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 68,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    font: useBold ? boldFont : font,
                    fontSize: fs,
                    color: labelColor ?? darkText,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 32,
                child: pw.Text(
                  value,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    font: useBold ? boldFont : font,
                    fontSize: fs,
                    color: valueColor ?? darkText,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borderColor, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            row('Subtotal', _money(subtotal)),
            row('Tax (0%)', _money(tax)),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Container(height: 0.5, color: borderColor),
            ),
            pw.Container(
              decoration: pw.BoxDecoration(
                color: purpleLight,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 8,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 68,
                    child: pw.Text(
                      'Grand Total',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 12,
                        color: purpleDark,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 32,
                    child: pw.Text(
                      _money(grandTotal),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 12,
                        color: purpleDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Container(height: 0.5, color: borderColor),
            ),
            row('Paid Amount', _money(paidAmount)),
            row('Amount Due', _money(amountDue)),
            row('Running Balance', _money(runningBalance)),
          ],
        ),
      );
    }

    final body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            logoBox(),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    businessName,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20,
                      color: purpleDark,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    cityLine.isEmpty ? '—' : cityLine,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 9.5,
                      color: grayText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        hr(),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Receipt No: $receiptNo',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8.5,
                      color: grayText,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated: $generatedStr',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8.5,
                      color: grayText,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              'Date: $receiptDate',
              style: pw.TextStyle(font: font, fontSize: 8.5, color: grayText),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        billToCard(),
        pw.SizedBox(height: 14),
        if (deliveries.isEmpty)
          pw.Text(
            'No deliveries recorded for this date.',
            style: pw.TextStyle(font: font, color: grayText),
          )
        else
          ...deliveries.whereType<Map>().map((slotRaw) {
            final slot = Map<String, dynamic>.from(slotRaw);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: itemsSection(slot),
            );
          }),
        pw.SizedBox(height: 8),
        hr(),
        pw.SizedBox(height: 10),
        totalsBlock(),
        if (paymentHistory.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            'RECENT PAYMENTS',
            style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: purple),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.35),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: purpleMid),
                children: ['Date', 'Amount', 'Method', 'Ref ID', 'Status']
                    .map(
                      (t) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          t,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 8.5,
                            color: white,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...paymentHistory.whereType<Map>().map((pRaw) {
                final p = Map<String, dynamic>.from(pRaw);
                return pw.TableRow(
                  children:
                      [
                            _fmtParsedDate(p['date']),
                            _money(_num(p['amount'])),
                            _stripRupeeGlyphs('${p['method'] ?? ''}'),
                            _stripRupeeGlyphs('${p['referenceId'] ?? ''}'),
                            _stripRupeeGlyphs('${p['status'] ?? ''}'),
                          ]
                          .map(
                            (t) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                t,
                                style: pw.TextStyle(font: font, fontSize: 8.5),
                              ),
                            ),
                          )
                          .toList(),
                );
              }),
            ],
          ),
        ],
        pw.SizedBox(height: 16),
        hr(),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'Thank you for your order! | $businessName | $phone',
            style: pw.TextStyle(font: font, fontSize: 7.5, color: grayText),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'This is a computer-generated receipt and does not require a signature.',
            style: pw.TextStyle(font: font, fontSize: 7.5, color: grayText),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        maxPages: 100,
        build: (ctx) => [body],
      ),
    );

    return pdf.save();
  }
}
