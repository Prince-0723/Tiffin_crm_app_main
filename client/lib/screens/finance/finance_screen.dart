import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/socket/delivery_tracking_socket.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bottom_sheet_handle.dart';
import '../../features/expenses/data/expense_api.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/income/data/income_api.dart';
import '../../features/income/screens/income_screen.dart';
import '../../models/finance_stats.dart';
import '../../models/finance_summary.dart';
import '../../services/finance_calculator.dart';
import '../../services/finance_service.dart';
import 'finance_refresh_signal.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _monthTitle = DateFormat('MMM yyyy', 'en');
  static final _dayTitle = DateFormat('d', 'en');

  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _selectedDateRange;
  DateTime? _selectedDay;
  FinanceSummary? _summary;
  List<DailyFinanceRow> _calendarData = [];
  List<FinanceTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<void>? _dailyOrdersSocketSub;

  late final TabController _tabController;

  String get _monthKey =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selectedMonth = DateTime(n.year, n.month);
    _selectedDay = DateTime(n.year, n.month, n.day);
    _tabController = TabController(length: 2, vsync: this);
    financeDashboardTabSelectedTick.addListener(_onFinanceTabReselected);
    _fetch();
    _attachFinanceSocket();
  }

  void _onFinanceTabReselected() {
    if (mounted) _fetch();
  }

  Future<void> _attachFinanceSocket() async {
    await DeliveryTrackingSocket.instance.ensureConnected();
    _dailyOrdersSocketSub =
        DeliveryTrackingSocket.instance.dailyOrdersRefresh.listen((_) {
      if (mounted) _fetch();
    });
  }

  @override
  void dispose() {
    financeDashboardTabSelectedTick.removeListener(_onFinanceTabReselected);
    _dailyOrdersSocketSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summary = await FinanceService.fetchSummaryForMonth(_selectedMonth);
      final daily = await FinanceService.fetchCalendarForMonth(_selectedMonth);

      // Transactions should NOT block the whole Finance screen.
      List<FinanceTransaction> txns = const [];
      try {
        txns = await FinanceService.fetchTransactionsForMonth(_selectedMonth);
      } catch (_) {
        txns = const [];
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _calendarData = daily;
        _transactions = txns;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _onMonthPicked(DateTime month) {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(month.year, month.month);
      _selectedDateRange = null;
      _selectedDay = (_selectedMonth.year == now.year &&
              _selectedMonth.month == now.month)
          ? DateTime(now.year, now.month, now.day)
          : DateTime(
              _selectedMonth.year,
              _selectedMonth.month,
              DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day,
            );
    });
    _fetch();
  }

  void _applyDateRange(DateTimeRange range) {
    DateTime norm(DateTime d) => DateTime(d.year, d.month, d.day);
    final start = norm(range.start);
    final end = norm(range.end);
    final today = norm(DateTime.now());

    setState(() {
      _selectedDateRange = DateTimeRange(
        start: start,
        end: end,
      );

      // Cards should show a single day's data.
      // - If user picked a single day (start == end): use that day.
      // - If user picked a range: show Today when it's within the range,
      //   otherwise show the latest day in the range (end).
      if (start == end) {
        _selectedDay = start;
      } else if (!today.isBefore(start) && !today.isAfter(end)) {
        _selectedDay = today;
      } else {
        _selectedDay = end;
      }
    });
  }

  List<DailyFinanceRow> get _filteredCalendar {
    final range = _selectedDateRange;
    if (range == null) return _calendarData;
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return _calendarData.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  String _monthLabel(DateTime m) {
    try {
      return _monthTitle.format(m);
    } catch (_) {
      return _monthKey;
    }
  }

  String _rangeLabel() {
    final range = _selectedDateRange;
    if (range == null) {
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      return '${_monthTitle.format(_selectedMonth)} · ${start.day} – ${end.day}';
    }
    final m = DateFormat('MMM', 'en');
    return '${m.format(range.start)} ${range.start.day} – ${m.format(range.end)} ${range.end.day}';
  }

  Future<void> _openDateRangeSheet() async {
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final initial = _selectedDateRange ??
        DateTimeRange(start: monthStart, end: monthEnd);

    DateTimeRange temp = initial;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> pickFrom() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: temp.start,
                firstDate: monthStart,
                lastDate: monthEnd,
              );
              if (picked == null) return;
              final normalized = DateTime(picked.year, picked.month, picked.day);
              final end = temp.end.isBefore(normalized) ? normalized : temp.end;
              setModal(() {
                temp = DateTimeRange(start: normalized, end: end);
              });
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: temp.end,
                firstDate: monthStart,
                lastDate: monthEnd,
              );
              if (picked == null) return;
              final normalized = DateTime(picked.year, picked.month, picked.day);
              final start =
                  temp.start.isAfter(normalized) ? normalized : temp.start;
              setModal(() {
                temp = DateTimeRange(start: start, end: normalized);
              });
            }

            final df = DateFormat('d MMM', 'en');

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BottomSheetHandle(),
                  const SizedBox(height: 10),
                  Text(
                    'Select Date Range',
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _dateChip(
                          label: 'From',
                          value: df.format(temp.start),
                          onTap: pickFrom,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateChip(
                          label: 'To',
                          value: df.format(temp.end),
                          onTap: pickTo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      _applyDateRange(temp);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _dateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMonthPickerSheet() async {
    var year = _selectedMonth.year;
    final selectedMonth = _selectedMonth.month;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Widget monthButton(int m) {
              final isSel = (year == _selectedMonth.year && m == selectedMonth);
              return InkWell(
                onTap: () {
                  _onMonthPicked(DateTime(year, m));
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    DateFormat('MMM', 'en').format(DateTime(2000, m, 1)),
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              isSel ? AppColors.primary : AppColors.textPrimary,
                        ),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BottomSheetHandle(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setModal(() => year -= 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: AppColors.primary,
                      ),
                      Expanded(
                        child: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setModal(() => year += 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.4,
                    children: [
                      for (var m = 1; m <= 12; m += 1) monthButton(m),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () async {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
                return;
              }
              final router = GoRouter.of(context);
              if (router.canPop()) {
                context.pop();
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: const Text('Finance'),
          actions: [
            IconButton(
              tooltip: 'Select date range',
              onPressed: _openDateRangeSheet,
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _monthPill(
                label: _monthLabel(_selectedMonth),
                onTap: _openMonthPickerSheet,
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.onPrimary,
            unselectedLabelColor: AppColors.onPrimary.withValues(alpha: 0.70),
            indicatorColor: AppColors.onPrimary,
            indicatorWeight: 3,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.onPrimary, width: 3),
            ),
            tabs: const [
              Tab(text: 'Revenue'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _fetch)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _RevenueTab(
                        theme: theme,
                        summary: _summary ?? FinanceSummary.empty,
                        chartRows: _filteredCalendar,
                        dailyRows: _calendarData,
                        rangeLabel: _rangeLabel(),
                        selectedMonth: _selectedMonth,
                        selectedDay: _selectedDay ??
                            DateTime(_selectedMonth.year, _selectedMonth.month, 1),
                        onRefresh: _fetch,
                      ),
                      _TransactionsTab(
                        theme: theme,
                        transactions: _transactions,
                        onChanged: _fetch,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _monthPill({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.onPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.onPrimary.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.onPrimary.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueTab extends StatefulWidget {
  const _RevenueTab({
    required this.theme,
    required this.summary,
    required this.chartRows,
    required this.dailyRows,
    required this.rangeLabel,
    required this.selectedMonth,
    required this.selectedDay,
    required this.onRefresh,
  });

  final ThemeData theme;
  final FinanceSummary summary;
  final List<DailyFinanceRow> chartRows;
  final List<DailyFinanceRow> dailyRows;
  final String rangeLabel;
  final DateTime selectedMonth;
  final DateTime selectedDay;
  final Future<void> Function() onRefresh;

  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  State<_RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<_RevenueTab> {
  bool _showTotal = false;

  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;
    return RefreshIndicator(
      color: AppColors.primaryAccent,
      onRefresh: widget.onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _viewToggle(),
            const SizedBox(height: 12),
            _summaryRow(context),
            const SizedBox(height: 16),
            _dailyTableLikeScreenshot(context),
          ],
        ),
      ),
    );
  }

  Widget _viewToggle() {
    Widget pill(String label, bool sel, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sel ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: widget.theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: sel ? AppColors.primary : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: pill(
            'Today',
            !_showTotal,
            () => setState(() => _showTotal = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: pill(
            'Total',
            _showTotal,
            () => setState(() => _showTotal = true),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final stats = _showTotal
        ? FinanceCalculator.calculateTotalStats(rows: widget.dailyRows)
        : FinanceCalculator.calculateTodayStats(rows: widget.dailyRows, today: today);

    final processedCount = stats.processedCount;
    final processedAmount = stats.processedAmount;
    final refund = stats.refundAmount;
    final netRevenue = stats.netRevenue;
    final expenses = stats.expenses;
    final incomes = stats.income;
    final profit = stats.profit;
    final deposit = stats.deposit;

    final processedLabel = processedCount > 0
        ? '$processedCount (${_money.format(processedAmount)})'
        : _money.format(processedAmount);

    final cards = <Widget>[
      FinanceMiniCard(
        title: 'Revenue',
        value: _money.format(netRevenue),
        color: AppColors.primary,
      ),
      FinanceMiniCard(
        title: 'Expenses',
        value: _money.format(expenses),
        color: const Color(0xFFF97316), // orange
      ),
      FinanceMiniCard(
        title: 'Income',
        value: _money.format(incomes),
        color: AppColors.primaryAccent,
      ),
      FinanceMiniCard(
        title: 'Profit',
        value: _money.format(profit),
        color: const Color(0xFF16A34A), // green
      ),
      FinanceMiniCard(
        title: 'Refund',
        value: _money.format(refund),
        color: const Color(0xFFF59E0B), // yellow/amber
      ),
      FinanceMiniCard(
        title: 'Deposit',
        value: _money.format(deposit),
        color: AppColors.textSecondary,
      ),
      FinanceMiniCard(
        title: 'Processed',
        value: processedLabel,
        color: AppColors.primary,
      ),
    ];

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => cards[i],
      ),
    );
  }

  // Old large grid cards removed; we use FinanceMiniCard instead.

  bool _isCurrentMonth() {
    final now = DateTime.now();
    return widget.selectedMonth.year == now.year && widget.selectedMonth.month == now.month;
  }

  Widget _dailyTableLikeScreenshot(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _isCurrentMonth();
    final today = DateTime(now.year, now.month, now.day);

    // Use full month daily data so backend values always show here
    // (chartRows may be locally date-range filtered).
    final visible = [...widget.dailyRows]..sort((a, b) => b.date.compareTo(a.date));

    // Never show future dates for the current month.
    final filtered = isCurrentMonth
        ? visible.where((r) => !r.date.isAfter(today)).toList()
        : visible;

    String processedText(DailyFinanceRow r) {
      if (r.processedCount > 0) {
        return '${r.processedCount} (${_money.format(r.processedAmount)})';
      }
      return _money.format(r.processedAmount);
    }

    String moneyOr0(double v) => _money.format(v);
    String dateLabel(DateTime d) => DateFormat('MMM d', 'en').format(d);
    double profit(DailyFinanceRow r) => FinanceCalculator.fromDailyRow(r).profit;

    final headerStyle = widget.theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.2,
    );
    final cellStyle = widget.theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );

    const dateColW = 86.0;
    const colW = 126.0;

    Widget headerCell(String t, {required double w, TextAlign align = TextAlign.center}) => SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              t,
              textAlign: align,
              style: headerStyle,
            ),
          ),
        );

    Widget dataCell(
      String t, {
      required double w,
      TextAlign align = TextAlign.center,
      Color? color,
      FontWeight? weight,
    }) =>
        SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(
              t,
              textAlign: align,
              style: cellStyle.copyWith(
                color: color ?? cellStyle.color,
                fontWeight: weight ?? cellStyle.fontWeight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

    Widget dateCell(String t, {required bool muted}) => SizedBox(
          width: dateColW,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(
              t,
              style: cellStyle.copyWith(
                color: muted ? AppColors.textSecondary : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

    Widget vSep() => Container(width: 1, height: 44, color: AppColors.border);

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'No daily data',
          style: widget.theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    headerCell('Date', w: dateColW, align: TextAlign.left),
                    vSep(),
                    headerCell('Processed', w: colW),
                    vSep(),
                    headerCell('Income', w: colW),
                    vSep(),
                    headerCell('Deposit', w: colW),
                    vSep(),
                    headerCell('Refund', w: colW),
                    vSep(),
                    headerCell('Expenses', w: colW),
                    vSep(),
                    headerCell('Profit', w: colW),
                  ],
                ),
              ),
              for (var i = 0; i < filtered.length; i += 1)
                Builder(
                  builder: (_) {
                    final r = filtered[i];
                    final isAlt = i.isOdd;
                    final rowBg =
                        isAlt ? AppColors.surfaceContainerLow : AppColors.surface;
                    final muted = r.processedAmount <= 0.0001 &&
                        r.incomes <= 0.0001 &&
                        r.deposits <= 0.0001 &&
                        r.refund <= 0.0001 &&
                        r.expenses <= 0.0001 &&
                        r.manual <= 0.0001;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: rowBg,
                        border: Border(
                          bottom:
                              BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          dateCell(dateLabel(r.date), muted: muted),
                          vSep(),
                          dataCell(
                            processedText(r),
                            w: colW,
                            weight: FontWeight.w800,
                          ),
                          vSep(),
                          dataCell(
                            moneyOr0(r.incomes),
                            w: colW,
                            color: AppColors.primary,
                          ),
                          vSep(),
                          dataCell(moneyOr0(r.deposits), w: colW),
                          vSep(),
                          dataCell(
                            moneyOr0(r.refund),
                            w: colW,
                            color: const Color(0xFFF59E0B),
                          ),
                          vSep(),
                          dataCell(
                            moneyOr0(r.expenses),
                            w: colW,
                            color: const Color(0xFFF97316),
                          ),
                          vSep(),
                          Builder(
                            builder: (_) {
                              final p = profit(r);
                              final pc = p >= 0
                                  ? const Color(0xFF16A34A)
                                  : AppColors.error;
                              return dataCell(
                                moneyOr0(p),
                                w: colW,
                                color: pc,
                                weight: FontWeight.w900,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceMiniCard extends StatelessWidget {
  const FinanceMiniCard({
    super.key,
    required this.title,
    required this.value,
    this.color,
  });

  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? AppColors.primary;
    final bg = c.withValues(alpha: 0.08);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: c,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.theme,
    required this.transactions,
    required this.onChanged,
  });

  final ThemeData theme;
  final List<FinanceTransaction> transactions;
  final Future<void> Function() onChanged;

  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryAccent,
                onRefresh: onChanged,
                child: transactions.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          SizedBox(
                            height: 220,
                            child: Center(
                              child: Text(
                                'No transactions this month',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: transactions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final t = transactions[index];
                          final isCredit = t.isCredit;
                          final titleColor =
                              isCredit ? AppColors.success : AppColors.error;
                          final dateStr = DateFormat('MMM d, yyyy', 'en')
                              .format(t.date.toLocal());

                          final title = t.title.isNotEmpty
                              ? t.title
                              : (isCredit ? 'Income' : 'Expense');

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$title (${_money.format(t.amount)})',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          color: titleColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        dateStr,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: () {
                                    // Edit flow not implemented in existing APIs here.
                                    // Keeping icon to match requested UI.
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  onPressed: () => _confirmDelete(context, t),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 22),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Bottom action bar (Add Expense / Add Income)
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _openAddExpense(context),
                      child: const Text(
                        'Add Expense',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _openAddIncome(context),
                      child: const Text(
                        'Add Income',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddIncome(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddIncomeSheet(
        onAdded: () async {
          Navigator.pop(ctx);
          await onChanged();
        },
      ),
    );
  }

  Future<void> _openAddExpense(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExpenseSheet(
        onAdded: () async {
          Navigator.pop(ctx);
          await onChanged();
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FinanceTransaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Remove "${t.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (t.kind == FinanceTransactionKind.income) {
        await IncomeApi.delete(t.id);
      } else {
        await ExpenseApi.delete(t.id);
      }
      await onChanged();
    } catch (_) {
      // Keep silent here; Errors are already logged by DioClient in debug mode.
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 46,
              color: AppColors.error,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to retry',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

