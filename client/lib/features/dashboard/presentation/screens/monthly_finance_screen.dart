import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/finance_monthly_api.dart';

/// Monthly finance overview (vendor): summary, orders chart, daily breakdown.
class MonthlyFinanceScreen extends StatefulWidget {
  const MonthlyFinanceScreen({super.key, this.embeddedInFinanceShell = false});

  final bool embeddedInFinanceShell;

  @override
  State<MonthlyFinanceScreen> createState() => _MonthlyFinanceScreenState();
}

class _MonthlyFinanceScreenState extends State<MonthlyFinanceScreen> {
  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _monthTitle = DateFormat('MMM yyyy', 'en');

  late DateTime _month;
  MonthlyFinanceData? _data;
  bool _loading = true;
  Object? _error;

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await FinanceMonthlyApi.fetch(_monthKey);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.embeddedInFinanceShell) {
      return ColoredBox(
        color: AppColors.background,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Monthly finance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    final topPad = widget.embeddedInFinanceShell ? 12.0 : 8.0;
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, topPad, 16, 12),
          child: _monthPicker(),
        ),
        Expanded(child: _buildBodyBelowPicker(bottomPad)),
      ],
    );
  }

  Widget _buildBodyBelowPicker(double bottomPad) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load finance data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: AppColors.primaryAccent,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow(data.summary),
            const SizedBox(height: 20),
            _chartCard(data.ordersProcessed),
            const SizedBox(height: 20),
            _sectionLabel('Daily breakdown'),
            const SizedBox(height: 10),
            ...data.daily.map(_dailyTile),
          ],
        ),
      ),
    );
  }

  String _formatMonthTitle(DateTime m) {
    try {
      return _monthTitle.format(m);
    } catch (_) {
      return '${m.year}-${m.month.toString().padLeft(2, '0')}';
    }
  }

  Widget _monthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevMonth,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primary,
          ),
          Expanded(
            child: Text(
              _formatMonthTitle(_month),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(MonthlyFinanceSummary s) {
    return Row(
      children: [
        Expanded(
          child: _sumCard(
            'Revenue',
            _money.format(s.revenue),
            AppColors.successChipBg,
            AppColors.successChipText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _sumCard(
            'Expenses',
            _money.format(s.expenses),
            AppColors.errorContainer,
            AppColors.error,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _sumCard(
            'Profit',
            _money.format(s.profit),
            AppColors.primaryContainer,
            s.profit >= 0 ? AppColors.successChipText : AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _sumCard(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _chartCard(List<OrderChartPointDto> points) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No order data for this month.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final maxO = points.fold<int>(
      0,
      (m, p) => p.ordersDelivered > m ? p.ordersDelivered : m,
    );
    final maxY = maxO <= 0 ? 5.0 : (maxO * 1.2).ceilToDouble();
    final labelStep = points.length <= 8
        ? 1
        : (points.length / 7).ceil().clamp(1, points.length);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Orders delivered (by day)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < 0 || groupIndex >= points.length) {
                        return null;
                      }
                      final p = points[groupIndex];
                      return BarTooltipItem(
                        '${p.ordersDelivered}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY <= 5 ? 1 : null,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (i % labelStep != 0 && i != points.length - 1) {
                          return const SizedBox.shrink();
                        }
                        final d = DateTime.tryParse(points[i].date);
                        final label = d != null
                            ? '${d.day}/${d.month}'
                            : points[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY <= 5 ? 1 : maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].ordersDelivered.toDouble(),
                          width: points.length > 20 ? 4 : 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          color: AppColors.primaryAccent,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDailyRowDate(DateTime d) {
    try {
      return DateFormat('EEE, d MMM', 'en').format(d);
    } catch (_) {
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _dailyTile(DailyFinanceRowDto row) {
    final d = DateTime.tryParse(row.date);
    final dateLabel = d != null ? _formatDailyRowDate(d) : row.date;
    final ordersBit =
        '${row.processed.count} · ${_money.format(row.processed.amount)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ordersBit,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  'Refund ${_money.format(row.refund)}  ·  Expenses ${_money.format(row.expenses)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
