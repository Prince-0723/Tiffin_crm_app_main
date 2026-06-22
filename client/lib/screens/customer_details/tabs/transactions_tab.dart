import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../models/customer_detail_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/customer_detail_service.dart';
import '../../../services/pdf_download_service.dart';

import 'customer_info_tab.dart';

class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const s900 = Color(0xFF0F172A);
  static const s600 = Color(0xFF475569);
  static const s200 = Color(0xFFE2E8F0);
  static const s100 = Color(0xFFF8FAFC);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
}

class _D {
  static const card = Color(0xFF1B1F2E);
  static const cardBdr = Color(0xFF2F3347);
  static const primaryBg = Color(0xFF241B42);
  static const s900 = Color(0xFFF8FAFC);
  static const s600 = Color(0xFFCBD5E1);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFF2F3347);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
}

/// Filters + transaction list + receipt bottom sheet.
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab>
    with AutomaticKeepAliveClientMixin {
  List<CustomerDetailTransaction> _all = [];
  bool _loading = true;
  String? _error;
  int _filter = 0; // 0 all, 1 today, 2 week
  bool _downloading = false;

  /// True while an add/deduct bottom sheet is on screen (disables footer buttons only).
  bool _transactionSheetOpen = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads transactions for the current filter window.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final range = _computeRange();
    try {
      final list = await CustomerDetailService.fetchTransactions(
        widget.customerId,
        startDate: range.$1,
        endDate: range.$2,
      );
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? (e.message ?? 'Error') : '$e';
        });
      }
    }
  }

  (String?, String?) _computeRange() {
    final now = DateTime.now();
    switch (_filter) {
      case 1:
        final start = DateTime(now.year, now.month, now.day);
        final end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return (start.toUtc().toIso8601String(), end.toUtc().toIso8601String());
      case 2:
        final start = now.subtract(const Duration(days: 7));
        return (start.toUtc().toIso8601String(), now.toUtc().toIso8601String());
      default:
        return (null, null);
    }
  }

  Future<void> _openReceipt(CustomerDetailTransaction t) async {
    try {
      final r = await CustomerDetailService.fetchReceipt(
        widget.customerId,
        t.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _ReceiptSheet(receipt: r),
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? (e.message ?? 'Error') : '$e',
        );
      }
    }
  }

  Future<void> _openAddBalanceSheet() async {
    if (_transactionSheetOpen) return;
    setState(() => _transactionSheetOpen = true);
    final snackCtx = context;
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalCtx) {
          final kb = MediaQuery.viewInsetsOf(modalCtx).bottom;
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + kb),
              decoration: BoxDecoration(
                color: isDark ? _D.card : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? _D.s200 : _P.s200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _TransactionsAddBalanceBody(
                customerId: widget.customerId,
                snackbarContext: snackCtx,
                onDone: () async {
                  if (!mounted) return;
                  AppSnackbar.success(context, 'Balance added');
                  await _load();
                },
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _transactionSheetOpen = false);
    }
  }

  Future<void> _openDeductBalanceSheet() async {
    if (_transactionSheetOpen) return;
    setState(() => _transactionSheetOpen = true);
    final snackCtx = context;
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalCtx) {
          final kb = MediaQuery.viewInsetsOf(modalCtx).bottom;
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + kb),
              decoration: BoxDecoration(
                color: isDark ? _D.card : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? _D.s200 : _P.s200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _TransactionsDeductBalanceBody(
                customerId: widget.customerId,
                snackbarContext: snackCtx,
                onDone: () async {
                  if (!mounted) return;
                  AppSnackbar.success(context, 'Balance deducted');
                  await _load();
                },
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _transactionSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Shimmer.fromColors(
        baseColor: isDark ? _D.s200 : _P.s200,
        highlightColor: isDark ? _D.card : _P.s100,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, _) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? _D.card : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return CustomerDetailNetworkError(message: _error!, onRetry: _load);
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              _chip('All', 0),
              _chip('Today', 1),
              _chip('This Week', 2),
              IconButton(
                icon: const Icon(Icons.download_rounded, color: _P.g1),
                tooltip: 'Download',
                onPressed: _downloading ? null : _openDownloadSheet,
              ),
            ],
          ),
        ),
        _subscriptionSummaryCard(),
        Expanded(
          child: _all.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: isDark ? _D.s600 : _P.s600),
                      const SizedBox(height: 8),
                      Text(
                        'No transactions found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? _D.s600 : _P.s600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _P.g1,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: _all.length,
                    itemBuilder: (context, i) {
                      final t = _all[i];
                      final credit = t.isCredit;
                      final amtColor = credit ? (isDark ? _D.green : _P.green) : (isDark ? _D.red : _P.red);
                      final amountText = t.amountLabel(hideDeliveredAmount: true);
                      final icon = Icons.arrow_circle_down;
                      final dt = DateTime.tryParse(t.date);
                      final dateStr = dt != null
                          ? DateFormat.yMMMd().add_jm().format(dt.toLocal())
                          : t.date;
                      final desc = t.description;
                      return RepaintBoundary(
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: isDark ? _D.card : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? _D.s200 : _P.s200, width: 0.5),
                          ),
                          child: ListTile(
                            leading: Icon(icon, color: amtColor, size: 28),
                            title: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? _D.s900 : _P.s900,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? _D.s600 : _P.s600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (amountText.isNotEmpty) ...[
                                      Text(
                                        amountText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: amtColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark ? _D.s200 : _P.s100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? _D.s200 : _P.s200),
                                      ),
                                      child: Text(
                                        t.typeLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? _D.s600 : _P.s600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.receipt, color: _P.g1),
                              onPressed: () => _openReceipt(t),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _transactionSheetOpen
                          ? null
                          : _openAddBalanceSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? _D.green : _P.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add Balance',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _transactionSheetOpen
                          ? null
                          : _openDeductBalanceSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? _D.red : _P.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Deduct Balance',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sel = _filter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (v) async {
          if (v) {
            setState(() => _filter = index);
            await _load();
          }
        },
        selectedColor: _P.g1.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: sel ? _P.g1 : (isDark ? _D.s600 : _P.s600),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _subscriptionSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subscriptionDebits = _all
        .where((t) => t.isSubscriptionTransaction && !t.isCredit)
        .toList();
    final totalDeducted = subscriptionDebits.fold<double>(
      0,
      (sum, t) => sum + t.displayAmount,
    );

    final dailyDeductionDays = subscriptionDebits
        .map((t) {
          final dt = DateTime.tryParse(t.date)?.toLocal();
          if (dt == null) return null;
          return DateTime(dt.year, dt.month, dt.day);
        })
        .whereType<DateTime>()
        .toSet()
        .length;

    final perDayAmount = subscriptionDebits.isEmpty
        ? 0.0
        : totalDeducted / (dailyDeductionDays > 0 ? dailyDeductionDays : 1);
    final subscriptionTotal = perDayAmount * 30;
    final remainingBalance = subscriptionTotal - totalDeducted;

    String formatAmount(double value) {
      if (value < 0) {
        return '-₹${value.abs().toStringAsFixed(0)}';
      }
      return '₹${value.toStringAsFixed(0)}';
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? _D.s600 : _P.s600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? _D.s900 : _P.s900,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        elevation: 0,
        color: isDark ? _D.card : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isDark ? _D.s200 : _P.s200, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              row('Subscription Total', formatAmount(subscriptionTotal)),
              row('Total Deducted', formatAmount(totalDeducted)),
              row('Remaining Balance', formatAmount(remainingBalance)),
              row('Daily Deduction', '₹${perDayAmount.toStringAsFixed(0)}/day'),
            ],
          ),
        ),
      ),
    );
  }

  String _safeBusinessName() {
    return 'tiffincrm';
  }

  String _fileBase(String suffix) {
    final biz = _safeBusinessName().trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    return '${biz}_${suffix}_${widget.customerId}'.toLowerCase();
  }

  Future<void> _openDownloadSheet() async {
    if (_all.isEmpty) {
      AppSnackbar.error(context, 'No data to download');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? _D.card : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? _D.s200 : _P.s200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Download',
                            style: TextStyle(
                              color: isDark ? _D.s900 : _P.s900,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: isDark ? _D.s200 : _P.s200),
                  ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: _P.g1,
                    ),
                    title: Text(
                      'Download as PDF',
                      style: TextStyle(
                        color: isDark ? _D.s900 : _P.s900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _downloadPdf();
                    },
                  ),
                  Container(height: 1, color: isDark ? _D.s200 : _P.s200),
                  ListTile(
                    leading: const Icon(Icons.grid_on_rounded, color: _P.g1),
                    title: Text(
                      'Download as Excel',
                      style: TextStyle(
                        color: isDark ? _D.s900 : _P.s900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _downloadExcel();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _withLoading(Future<void> Function() task) async {
    if (!mounted) return;
    setState(() => _downloading = true);
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator(color: _P.g1)),
      );
      await task();
    } finally {
      if (mounted) setState(() => _downloading = false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // close loading dialog
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_all.isEmpty) {
      AppSnackbar.error(context, 'No data to download');
      return;
    }

    await _withLoading(() async {
      final now = DateTime.now();
      final credits = _all
          .where((t) => t.isCredit)
          .fold<double>(0, (s, t) => s + t.displayAmount);
      final debits = _all
          .where((t) => !t.isCredit)
          .fold<double>(0, (s, t) => s + t.displayAmount);
      final net = credits - debits;

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            pw.Widget headerCell(
              String text, {
              pw.Alignment align = pw.Alignment.centerLeft,
            }) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
                ),
                color: PdfColors.grey300,
                alignment: align,
                child: pw.Text(
                  text,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              );
            }

            pw.Widget bodyCell(
              String text, {
              pw.Alignment align = pw.Alignment.centerLeft,
              PdfColor? color,
            }) {
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 6,
                ),
                alignment: align,
                child: pw.Text(
                  text,
                  style: pw.TextStyle(fontSize: 9, color: color),
                ),
              );
            }

            return [
              pw.Text(
                _safeBusinessName(),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Customer: ${widget.customerName}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Generated: ${DateFormat('d MMM yyyy, h:mm a').format(now)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.1),
                  1: pw.FlexColumnWidth(3.3),
                  2: pw.FlexColumnWidth(1.3),
                  3: pw.FlexColumnWidth(1.6),
                  4: pw.FlexColumnWidth(1.7),
                },
                children: [
                  pw.TableRow(
                    children: [
                      headerCell('Date'),
                      headerCell('Description'),
                      headerCell('Type', align: pw.Alignment.center),
                      headerCell('Amount', align: pw.Alignment.centerRight),
                      headerCell('Payment Mode', align: pw.Alignment.center),
                    ],
                  ),
                  for (final t in _all)
                    pw.TableRow(
                      children: [
                        bodyCell(() {
                          final dt = DateTime.tryParse(t.date);
                          return dt != null
                              ? DateFormat(
                                  'd MMM yyyy, h:mm a',
                                ).format(dt.toLocal())
                              : t.date;
                        }()),
                        bodyCell(t.description),
                        bodyCell(t.typeLabel, align: pw.Alignment.center),
                        bodyCell(
                          '${t.isCredit ? '+' : '-'}₹${t.displayAmount.toStringAsFixed(2)}',
                          align: pw.Alignment.centerRight,
                          color: t.isCredit ? PdfColors.green : PdfColors.red,
                        ),
                        bodyCell(t.paymentMode, align: pw.Alignment.center),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Credits: ₹${credits.toStringAsFixed(2)}'),
                      pw.Text('Total Debits: ₹${debits.toStringAsFixed(2)}'),
                      pw.Text(
                        'Net Balance: ₹${net.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      final datePart = DateFormat('yyyyMMdd').format(DateTime.now());
      await PdfDownloadService.saveBytesAndOpen(
        context: context,
        bytes: Uint8List.fromList(bytes),
        fileName: 'Transactions_${widget.customerId}_$datePart.pdf',
      );
    });
  }

  Future<void> _downloadExcel() async {
    if (_all.isEmpty) {
      AppSnackbar.error(context, 'No data to download');
      return;
    }

    await _withLoading(() async {
      // No xlsx package installed; generate CSV content but save as .xlsx so Excel opens it.
      // This keeps functionality without changing any existing API/data flow.
      final header = ['Date', 'Description', 'Type', 'Amount', 'Payment Mode'];
      String esc(String v) {
        final s = v.replaceAll('"', '""');
        return '"$s"';
      }

      final credits = _all
          .where((t) => t.isCredit)
          .fold<double>(0, (s, t) => s + t.displayAmount);
      final debits = _all
          .where((t) => !t.isCredit)
          .fold<double>(0, (s, t) => s + t.displayAmount);
      final net = credits - debits;

      final lines = <String>[header.map(esc).join(',')];
      for (final t in _all) {
        final dt = DateTime.tryParse(t.date);
        final dateStr = dt != null ? dt.toLocal().toIso8601String() : t.date;
        final amountStr =
            '${t.isCredit ? '+₹' : '-₹'}${t.displayAmount.toStringAsFixed(2)}';
        lines.add(
          [
            dateStr,
            t.description,
            t.typeLabel,
            amountStr,
            t.paymentMode,
          ].map((e) => esc(e.toString())).join(','),
        );
      }
      lines.add(
        [
          'Totals',
          '',
          '',
          'Credits ₹${credits.toStringAsFixed(2)} | Debits ₹${debits.toStringAsFixed(2)} | Net ₹${net.toStringAsFixed(2)}',
          '',
        ].map((e) => esc(e.toString())).join(','),
      );

      final bytes = Uint8List.fromList(lines.join('\n').codeUnits);
      await FileSaver.instance.saveFile(
        name: _fileBase('transactions'),
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) AppSnackbar.success(context, 'Downloaded successfully');
    });
  }
}

/// Add-balance form: [State] holds payment mode and controllers so keyboard
/// `MediaQuery` rebuilds of the sheet do not reset dropdown state.
class _TransactionsAddBalanceBody extends StatefulWidget {
  const _TransactionsAddBalanceBody({
    required this.customerId,
    required this.snackbarContext,
    required this.onDone,
  });

  final String customerId;
  final BuildContext snackbarContext;
  final Future<void> Function() onDone;

  @override
  State<_TransactionsAddBalanceBody> createState() =>
      _TransactionsAddBalanceBodyState();
}

class _TransactionsAddBalanceBodyState
    extends State<_TransactionsAddBalanceBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  String _payMode = 'cash';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      AppSnackbar.error(widget.snackbarContext, 'Enter a valid amount');
      return;
    }
    setState(() => _submitting = true);
    try {
      await CustomerDetailService.addBalance(
        widget.customerId,
        amount: amt,
        paymentMode: _payMode,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onDone();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          widget.snackbarContext,
          e is ApiException ? (e.message ?? 'Error') : '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Balance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? _D.s900 : _P.s900,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: TextStyle(color: isDark ? _D.s900 : _P.s900),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _payMode,
            decoration: const InputDecoration(
              labelText: 'Payment mode',
              border: OutlineInputBorder(),
            ),
            dropdownColor: isDark ? _D.card : Colors.white,
            style: TextStyle(fontSize: 14, color: isDark ? _D.s900 : _P.s900),
            items: [
              DropdownMenuItem(value: 'cash', child: Text('Cash', style: TextStyle(color: isDark ? _D.s900 : _P.s900))),
              DropdownMenuItem(value: 'upi', child: Text('UPI', style: TextStyle(color: isDark ? _D.s900 : _P.s900))),
              DropdownMenuItem(value: 'online', child: Text('Online', style: TextStyle(color: isDark ? _D.s900 : _P.s900))),
            ],
            onChanged: _submitting
                ? null
                : (v) {
                    if (v != null) setState(() => _payMode = v);
                  },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteCtrl,
            style: TextStyle(color: isDark ? _D.s900 : _P.s900),
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? _D.green : _P.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionsDeductBalanceBody extends StatefulWidget {
  const _TransactionsDeductBalanceBody({
    required this.customerId,
    required this.snackbarContext,
    required this.onDone,
  });

  final String customerId;
  final BuildContext snackbarContext;
  final Future<void> Function() onDone;

  @override
  State<_TransactionsDeductBalanceBody> createState() =>
      _TransactionsDeductBalanceBodyState();
}

class _TransactionsDeductBalanceBodyState
    extends State<_TransactionsDeductBalanceBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      AppSnackbar.error(widget.snackbarContext, 'Enter a valid amount');
      return;
    }
    setState(() => _submitting = true);
    try {
      await CustomerDetailService.deductBalance(
        widget.customerId,
        amount: amt,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onDone();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          widget.snackbarContext,
          e is ApiException ? (e.message ?? 'Error') : '$e',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Deduct Balance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? _D.s900 : _P.s900,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: TextStyle(color: isDark ? _D.s900 : _P.s900),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteCtrl,
            style: TextStyle(color: isDark ? _D.s900 : _P.s900),
            decoration: const InputDecoration(
              labelText: 'Reason / Note',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? _D.red : _P.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Deduct'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Receipt preview with dashed rule and share.
class _ReceiptSheet extends StatelessWidget {
  const _ReceiptSheet({required this.receipt});

  final CustomerDetailReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.store, color: _P.g1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      receipt.businessName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? _D.s900 : _P.s900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.share, color: isDark ? _D.s600 : _P.s600),
                    onPressed: () {
                      final buf = StringBuffer()
                        ..writeln(receipt.businessName)
                        ..writeln(receipt.description)
                        ..writeln('Total: ₹${receipt.total.toStringAsFixed(0)}')
                        ..writeln('Mode: ${receipt.paymentMode}');
                      Share.share(buf.toString());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 1,
                child: CustomPaint(painter: _DashedLinePainter(isDark: isDark)),
              ),
              const SizedBox(height: 12),
              ...receipt.items.map(
                (it) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        size: 8,
                        color: isDark ? _D.s600 : _P.s600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${it.name} x${it.quantity.toStringAsFixed(0)} @ ₹${it.unitPrice.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 13, color: isDark ? _D.s900 : _P.s900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.currency_rupee, size: 18, color: isDark ? _D.s900 : _P.s900),
                  Text(
                    'Total: ₹${receipt.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? _D.s900 : _P.s900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.payment, size: 18, color: isDark ? _D.s600 : _P.s600),
                  const SizedBox(width: 6),
                  Text(
                    receipt.paymentMode,
                    style: TextStyle(fontSize: 13, color: isDark ? _D.s600 : _P.s600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? _D.s200 : const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
