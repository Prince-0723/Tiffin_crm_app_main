import 'package:flutter/foundation.dart';

import '../models/finance_stats.dart';
import '../models/finance_summary.dart';

abstract final class FinanceCalculator {
  static bool _sameYmd(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static double _finite(double v) => v.isFinite ? v : 0;

  static FinanceStats fromDailyRow(DailyFinanceRow? r) {
    if (r == null) return FinanceStats.zero;
    final processedAmount = _finite(r.processedAmount);
    final refundAmount = _finite(r.refund);
    final netRevenue = _finite(processedAmount - refundAmount);
    final income = _finite(r.incomes);
    final expenses = _finite(r.expenses);
    final profit = _finite(netRevenue + income - expenses);
    final deposit = _finite(r.deposits); // real deposits from backend

    return FinanceStats(
      processedCount: r.processedCount,
      processedAmount: processedAmount,
      refundAmount: refundAmount,
      netRevenue: netRevenue,
      income: income,
      expenses: expenses,
      profit: profit,
      deposit: deposit,
    );
  }

  static FinanceStats calculateTodayStats({
    required List<DailyFinanceRow> rows,
    required DateTime today,
  }) {
    final t = DateTime(today.year, today.month, today.day);
    DailyFinanceRow? r;
    for (final x in rows) {
      if (_sameYmd(x.date, t)) {
        r = x;
        break;
      }
    }
    final out = fromDailyRow(r);

    if (kDebugMode) {
      debugPrint(
        '[FinanceCalculator] today processed=${out.processedAmount} refund=${out.refundAmount} income=${out.income} expenses=${out.expenses} profit=${out.profit}',
      );
    }
    return out;
  }

  static FinanceStats calculateTotalStats({
    required List<DailyFinanceRow> rows,
  }) {
    var processedCount = 0;
    var processedAmount = 0.0;
    var refundAmount = 0.0;
    var income = 0.0;
    var expenses = 0.0;
    var deposit = 0.0;

    for (final r in rows) {
      processedCount += r.processedCount;
      processedAmount += _finite(r.processedAmount);
      refundAmount += _finite(r.refund);
      income += _finite(r.incomes);
      expenses += _finite(r.expenses);
      deposit += _finite(r.deposits);
    }

    final netRevenue = _finite(processedAmount - refundAmount);
    final profit = _finite(netRevenue + income - expenses);

    final out = FinanceStats(
      processedCount: processedCount,
      processedAmount: _finite(processedAmount),
      refundAmount: _finite(refundAmount),
      netRevenue: netRevenue,
      income: _finite(income),
      expenses: _finite(expenses),
      profit: profit,
      deposit: deposit,
    );

    if (kDebugMode) {
      debugPrint(
        '[FinanceCalculator] total processed=${out.processedAmount} refund=${out.refundAmount} income=${out.income} expenses=${out.expenses} profit=${out.profit}',
      );
    }
    return out;
  }
}

