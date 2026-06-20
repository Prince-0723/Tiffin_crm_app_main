import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/network/api_exception.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/subscription_calendar_days.dart';
import '../../../models/customer_detail_delivery_model.dart';
import '../../../services/customer_detail_service.dart';
import '../../../services/pdf_download_service.dart';

import 'customer_info_tab.dart';

class _P {
  static const g1 = Color(0xFF7B3FE4);
  static const g1Light = Color(0xFFF3EFFE);
  static const s900 = Color(0xFF0F172A);
  static const s600 = Color(0xFF475569);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFFE2E8F0);
  static const s100 = Color(0xFFF8FAFC);
  static const green = Color(0xFF22C55E);
  static const greenLight = Color(0xFFDCFCE7);
  static const greenDark = Color(0xFF16A34A);
  static const orange = Color(0xFFF59E0B);
  static const orangeLight = Color(0xFFFEF3C7);
  static const orangeDark = Color(0xFFB45309);
  static const grey = Color(0xFF94A3B8);
  static const greyLight = Color(0xFFF1F5F9);
  static const red = Color(0xFFEF4444);
  static const redLight = Color(0xFFFEE2E2);
  static const redDark = Color(0xFFDC2626);
}

class _D {
  static const card = Color(0xFF1B1F2E);
  static const cardBdr = Color(0xFF2F3347);
  static const primaryBg = Color(0xFF241B42);
  static const primaryBdr = Color(0xFF3A2E66);
  static const s900 = Color(0xFFF8FAFC);
  static const s600 = Color(0xFFCBD5E1);
  static const s400 = Color(0xFF94A3B8);
  static const s200 = Color(0xFF2F3347);
  static const greenBg = Color(0xFF0F2A1C);
  static const greenBdr = Color(0xFF1F6B3F);
  static const greenTxt = Color(0xFF4ADE80);
  static const redBg = Color(0xFF3A1212);
  static const redBdr = Color(0xFF7A2E2E);
  static const redTxt = Color(0xFFFCA5A5);
  static const orangeBg = Color(0xFF3A2A0F);
  static const orangeBdr = Color(0xFF7C5A18);
  static const orangeTxt = Color(0xFFFBBF24);
}

/// Full subscription window: info card + past / today / upcoming sections.
class DeliveriesTab extends StatefulWidget {
  const DeliveriesTab({super.key, required this.customerId, required this.customerName});

  final String customerId;
  final String customerName;

  @override
  State<DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<DeliveriesTab>
    with AutomaticKeepAliveClientMixin {
  CustomerDetailDeliveriesBundle? _bundle;
  bool _loading = true;
  String? _error;
  bool _downloading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool soft = false}) async {
    if (soft) {
      if (mounted) setState(() => _error = null);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final b = await CustomerDetailService.fetchDeliveries(widget.customerId);
      if (mounted) {
        setState(() {
          _bundle = b;
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

  static String _todayYmd() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmCancel(CustomerDetailDeliveryRow row) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _D.card : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: isDark ? _D.orangeTxt : _P.orange, size: 22),
            const SizedBox(width: 8),
            Text(
              'Cancel delivery',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? _D.s900 : _P.s900),
            ),
          ],
        ),
        content: Text(
          'Cancel tiffin for ${row.date}? You can restore it from this screen with Undo if needed.',
          style: TextStyle(fontSize: 13, color: isDark ? _D.s600 : _P.s600, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: isDark ? _D.s600 : _P.s600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final ymd = row.date.length >= 10 ? row.date.substring(0, 10) : row.date;
    try {
      await CustomerDetailService.cancelDelivery(widget.customerId, ymd);
      if (!mounted) return;
      AppSnackbar.success(context, 'Delivery cancelled');
      setState(() {
        final sub = _bundle?.subscription;
        final list = _bundle?.deliveries ?? [];
        final next = list.map((r) {
          final ry = r.date.length >= 10 ? r.date.substring(0, 10) : r.date;
          return ry == ymd
              ? CustomerDetailDeliveryRow(
                  date: r.date,
                  items: r.items,
                  status: 'cancelled',
                  amount: 0,
                )
              : r;
        }).toList();
        _bundle = CustomerDetailDeliveriesBundle(
          subscription: sub,
          deliveries: next,
        );
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? (e.message ?? 'Error') : '$e',
        );
      }
    }
  }

  Future<void> _confirmUndo(CustomerDetailDeliveryRow row) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _D.card : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.undo_rounded, color: isDark ? _D.greenTxt : _P.greenDark, size: 22),
            const SizedBox(width: 8),
            Text(
              'Restore delivery',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? _D.s900 : _P.s900),
            ),
          ],
        ),
        content: Text(
          'Restore tiffin for ${row.date}? The day will show as pending again.',
          style: TextStyle(fontSize: 13, color: isDark ? _D.s600 : _P.s600, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: isDark ? _D.s600 : _P.s600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, restore'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final ymd = row.date.length >= 10 ? row.date.substring(0, 10) : row.date;
    try {
      await CustomerDetailService.undoCancelDelivery(widget.customerId, ymd);
      if (!mounted) return;
      AppSnackbar.success(context, 'Delivery restored');
      await _load(soft: true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? (e.message ?? 'Error') : '$e',
        );
      }
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 130,
              decoration: BoxDecoration(color: isDark ? _D.card : Colors.white, borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(color: isDark ? _D.card : Colors.white, borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return CustomerDetailNetworkError(message: _error!, onRetry: _load);
    }

    final bundle = _bundle!;
    final sub = bundle.subscription;

    if (sub == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? _D.primaryBg : _P.g1Light,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.subscriptions_rounded, size: 32, color: _P.g1),
              ),
              const SizedBox(height: 16),
              Text(
                'No active subscription',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? _D.s900 : _P.s900),
              ),
              const SizedBox(height: 6),
              Text(
                'Please assign a meal plan first.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? _D.s600 : _P.s600),
              ),
            ],
          ),
        ),
      );
    }

    final today = _todayYmd();
    final rows = bundle.deliveries;
    final past = <CustomerDetailDeliveryRow>[];
    CustomerDetailDeliveryRow? todayRow;
    final upcoming = <CustomerDetailDeliveryRow>[];

    for (final r in rows) {
      final y = r.date.length >= 10 ? r.date.substring(0, 10) : r.date;
      if (y.compareTo(today) < 0) {
        past.add(r);
      } else if (y == today) {
        todayRow = r;
      } else {
        upcoming.add(r);
      }
    }

    return RefreshIndicator(
      color: _P.g1,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Deliveries',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? _D.s900 : _P.s900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _downloading ? null : _downloadMonthPdf,
                    icon: const Icon(Icons.download_rounded, color: _P.g1),
                    tooltip: 'Download',
                  ),
                ],
              ),
            ),
          ),
          // Subscription info card
          SliverToBoxAdapter(child: _SubscriptionCard(sub: sub)),

          // Today section
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: 'Today',
              icon: Icons.today_rounded,
              color: _P.g1,
            ),
          ),
          if (todayRow != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DeliveryRowCard(
                  row: todayRow,
                  todayYmd: today,
                  isTodayHighlight: true,
                  onCancel: _confirmCancel,
                  onUndo: _confirmUndo,
                ),
              ),
            )
          else
            SliverToBoxAdapter(child: _EmptyHint(text: 'No delivery row for today.', isDark: isDark)),

          // Upcoming section
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: 'Upcoming',
              icon: Icons.upcoming_rounded,
              color: _P.orange,
            ),
          ),
          if (upcoming.isEmpty)
            SliverToBoxAdapter(child: _EmptyHint(text: 'No upcoming deliveries.', isDark: isDark))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DeliveryRowCard(
                      row: upcoming[i],
                      todayYmd: today,
                      isTodayHighlight: false,
                      onCancel: _confirmCancel,
                      onUndo: _confirmUndo,
                    ),
                  ),
                ),
                childCount: upcoming.length,
              ),
            ),

          // Past section
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: 'Past Deliveries',
              icon: Icons.history_rounded,
              color: isDark ? _D.s400 : _P.s400,
            ),
          ),
          if (past.isEmpty)
            SliverToBoxAdapter(child: _EmptyHint(text: 'No past deliveries.', isDark: isDark))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DeliveryRowCard(
                      row: past[i],
                      todayYmd: today,
                      isTodayHighlight: false,
                      onCancel: _confirmCancel,
                      onUndo: _confirmUndo,
                    ),
                  ),
                ),
                childCount: past.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  String _safeBusinessName() => 'tiffincrm';

  String _monthlyDeliveriesPdfFilename() {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return 'Deliveries_${widget.customerId}_$monthKey.pdf';
  }

  Future<void> _withLoading(Future<void> Function() task) async {
    if (!mounted) return;
    setState(() => _downloading = true);
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: _P.g1),
        ),
      );
      await task();
    } finally {
      if (mounted) setState(() => _downloading = false);
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
  }

  Future<void> _downloadMonthPdf() async {
    final bundle = _bundle;
    if (bundle == null || bundle.deliveries.isEmpty) {
      AppSnackbar.error(context, 'No data to download');
      return;
    }

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthRows = bundle.deliveries.where((r) => r.date.startsWith(monthKey)).toList();
    if (monthRows.isEmpty) {
      AppSnackbar.error(context, 'No data to download');
      return;
    }

    await _withLoading(() async {
      final monthLabel = DateFormat('MMMM').format(now);
      final yearLabel = '${now.year}';

      final deliveredRows =
          monthRows.where((r) => r.status == 'delivered').toList();
      final totalDelivered = deliveredRows.length;
      final totalAmount =
          deliveredRows.fold<double>(0, (s, r) => s + r.amount);

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            return [
              pw.Text(
                _safeBusinessName(),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text('Customer: ${widget.customerName}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Month: $monthLabel $yearLabel', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: const ['Date', 'Order Items', 'Amount', 'Status', 'Delivered At'],
                data: [
                  for (final r in monthRows)
                    [
                      r.date,
                      r.items,
                      '₹${r.amount.toStringAsFixed(2)}',
                      r.status,
                      r.status == 'delivered' ? r.date : '',
                    ]
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerLeft,
                },
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total delivered: $totalDelivered'),
                      pw.Text(
                        'Total amount: ₹${totalAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  )
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      await PdfDownloadService.saveBytesAndOpen(
        context: context,
        bytes: Uint8List.fromList(bytes),
        fileName: _monthlyDeliveriesPdfFilename(),
      );
    });
  }
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty hint ─────────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: isDark ? _D.s400 : _P.s400),
      ),
    );
  }
}

// ── Subscription card ──────────────────────────────────────────────────────────
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub});

  final CustomerDetailDeliveriesSubscriptionInfo sub;

  String _fmt(String iso) {
    if (iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('d MMM yyyy').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final start = DateTime.tryParse(sub.startDate);
    final end = DateTime.tryParse(sub.endDate);
    final int totalDays = (start != null && end != null)
        ? totalDaysInclusiveIST(start, end)
        : sub.totalDays;
    final int remaining = (start != null && end != null)
        ? remainingDaysInclusiveIST(start, end)
        : sub.remainingDays;
    final done = totalDays > 0 ? ((totalDays - remaining) / totalDays).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? _D.card : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? _D.s200 : _P.s200, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan name + badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? _D.primaryBg : _P.g1Light,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, size: 18, color: _P.g1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sub.planName.isEmpty ? 'Meal Plan' : sub.planName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _D.s900 : _P.s900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? _D.greenBg : _P.greenLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? _D.greenTxt : _P.greenDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 0.8, color: isDark ? _D.s200 : _P.s200),
          const SizedBox(height: 14),

          // Date range row
          Row(
            children: [
              _InfoChip(
                icon: Icons.calendar_today_rounded,
                label: 'Start',
                value: _fmt(sub.startDate),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 14, color: isDark ? _D.s400 : _P.s400),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.event_rounded,
                label: 'End',
                value: _fmt(sub.endDate),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          Row(
            children: [
              _StatPill(label: 'Total', value: '$totalDays days', color: _P.g1),
              const SizedBox(width: 8),
              _StatPill(label: 'Remaining', value: '$remaining days', color: _P.orange),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done,
              minHeight: 5,
              backgroundColor: isDark ? _D.s200 : _P.s200,
              color: _P.g1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${((done) * 100).toStringAsFixed(0)}% completed',
            style: TextStyle(fontSize: 11, color: isDark ? _D.s400 : _P.s400),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? _D.card : _P.s100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? _D.s200 : _P.s200, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: _P.g1),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: isDark ? _D.s400 : _P.s400, fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(fontSize: 11, color: isDark ? _D.s900 : _P.s900, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _DeliveryRowCard extends StatelessWidget {
  const _DeliveryRowCard({
    required this.row,
    required this.todayYmd,
    required this.isTodayHighlight,
    required this.onCancel,
    required this.onUndo,
  });

  final CustomerDetailDeliveryRow row;
  final String todayYmd;
  final bool isTodayHighlight;
  final Future<void> Function(CustomerDetailDeliveryRow) onCancel;
  final Future<void> Function(CustomerDetailDeliveryRow) onUndo;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cancelled = row.status == 'cancelled';
    final delivered = row.status == 'delivered';

    // Status config
    final Color stColor;
    final Color stBg;
    final IconData stIcon;
    final String stLabel;
    if (delivered) {
      stColor = isDark ? _D.greenTxt : _P.greenDark;
      stBg = isDark ? _D.greenBg : _P.greenLight;
      stIcon = Icons.check_circle_rounded;
      stLabel = 'Delivered';
    } else if (cancelled) {
      stColor = isDark ? _D.s400 : _P.s400;
      stBg = isDark ? _D.s200 : _P.greyLight;
      stIcon = Icons.cancel_rounded;
      stLabel = 'Cancelled';
    } else {
      stColor = isDark ? _D.orangeTxt : _P.orangeDark;
      stBg = isDark ? _D.orangeBg : _P.orangeLight;
      stIcon = Icons.schedule_rounded;
      stLabel = 'Pending';
    }

    final ymd = row.date.length >= 10 ? row.date.substring(0, 10) : row.date;
    final d = DateTime.tryParse(ymd);
    final isPast = ymd.compareTo(todayYmd) < 0;
    final canCancel = row.status == 'pending' && !isPast;
    final canUndo = row.status == 'cancelled' && !isPast;

    // Card border + bg
    final Color cardBg;
    final Color cardBorder;
    if (isTodayHighlight) {
      cardBg = isDark ? _D.primaryBg : _P.g1Light;
      cardBorder = _P.g1;
    } else if (cancelled) {
      cardBg = isDark ? _D.s200 : _P.greyLight;
      cardBorder = isDark ? _D.s200 : _P.s200;
    } else {
      cardBg = isDark ? _D.card : Colors.white;
      cardBorder = isDark ? _D.s200 : _P.s200;
    }

    return Opacity(
      opacity: cancelled ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorder,
            width: isTodayHighlight ? 1.2 : 0.8,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date pill
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isTodayHighlight ? _P.g1 : (isDark ? _D.s200 : _P.s100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isTodayHighlight ? _P.g1 : (isDark ? _D.s200 : _P.s200), width: 0.8),
              ),
              child: Column(
                children: [
                  Text(
                    d != null ? DateFormat.E().format(d).toUpperCase() : '—',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isTodayHighlight ? Colors.white70 : (isDark ? _D.s400 : _P.s400),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d != null ? '${d.day}' : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isTodayHighlight ? Colors.white : (isDark ? _D.s900 : _P.s900),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    d != null ? DateFormat.MMM().format(d) : '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isTodayHighlight ? Colors.white70 : (isDark ? _D.s400 : _P.s400),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Items + meal amount (plan rate for the day)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.items,
                    style: TextStyle(
                      fontSize: 13,
                      color: cancelled ? (isDark ? _D.s400 : _P.s400) : (isDark ? _D.s900 : _P.s900),
                      fontWeight:
                          isTodayHighlight ? FontWeight.w600 : FontWeight.w500,
                      decoration:
                          cancelled ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: isDark ? _D.s400 : _P.s400,
                      height: 1.4,
                    ),
                  ),
                  if (row.amount > 0 && !cancelled && !delivered) ...[
                    const SizedBox(height: 4),
                    Text(
                      '₹${row.amount.toStringAsFixed(0)} / day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isTodayHighlight ? _P.g1 : (isDark ? _D.s600 : _P.s600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Status badge + cancel button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stIcon, size: 11, color: stColor),
                      const SizedBox(width: 4),
                      Text(
                        stLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: stColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => onCancel(row),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? _D.redBg : _P.redLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? _D.redBdr : _P.red, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 11, color: isDark ? _D.redTxt : _P.redDark),
                          const SizedBox(width: 4),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? _D.redTxt : _P.redDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (canUndo) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => onUndo(row),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? _D.greenBg : _P.greenLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? _D.greenBdr : _P.greenDark, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.undo_rounded, size: 11, color: isDark ? _D.greenTxt : _P.greenDark),
                          const SizedBox(width: 4),
                          Text(
                            'Undo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? _D.greenTxt : _P.greenDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}