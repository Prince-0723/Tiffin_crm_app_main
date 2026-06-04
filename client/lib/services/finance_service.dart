import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../features/expenses/data/expense_api.dart';
import '../features/income/data/income_api.dart';
import '../features/expenses/models/expense_model.dart';
import '../features/income/models/income_model.dart';
import '../models/finance_summary.dart';

abstract final class FinanceService {
  static const String _summaryPath = '/finance/summary';
  static const String _calendarPath = '/finance/calendar';

  static dynamic _parse(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final success = data['success'] as bool? ?? false;
      if (!success) {
        final msg =
            data['message'] as String? ?? data['error'] as String? ?? 'Failed';
        throw ApiException(msg, response.statusCode);
      }
      return data['data'];
    }
    throw ApiException('Invalid response', response.statusCode);
  }

  static Future<FinanceSummary> fetchSummaryForMonth(DateTime month) async {
    try {
      final m = month.month;
      final y = month.year;
      final res = await DioClient.instance.get(
        _summaryPath,
        queryParameters: <String, dynamic>{'month': m, 'year': y},
      );
      final data = _parse(res);
      if (data is! Map<String, dynamic>) {
        throw ApiException('Invalid response', res.statusCode);
      }

      final summaryRaw = data['summary'];
      final dailyRaw = data['daily'];

      final summary = summaryRaw is Map<String, dynamic>
          ? FinanceSummary.fromJson(summaryRaw)
          : FinanceSummary.empty;

      final daily = <DailyEntry>[];
      if (dailyRaw is List) {
        for (final e in dailyRaw) {
          if (e is! Map) continue;
          daily.add(DailyEntry.fromJson(Map<String, dynamic>.from(e)));
        }
      }

      return FinanceSummary(
        revenue: summary.revenue,
        expenses: summary.expenses,
        incomes: summary.incomes,
        deposit: summary.deposit,
        processed: summary.processed,
        refund: summary.refund,
        manual: summary.manual,
        profit: summary.profit,
        daily: daily,
      );
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Network error', e.response?.statusCode);
    }
  }

  static Future<List<DailyFinanceRow>> fetchCalendarForMonth(DateTime month) async {
    try {
      // Kept for backward compatibility (FinanceScreen uses fetchSummaryForMonth now).
      final summary = await fetchSummaryForMonth(month);
      final out = <DailyFinanceRow>[];
      for (final e in summary.daily) {
        final parts = e.date.split('/');
        final day = parts.length == 2 ? int.tryParse(parts[0]) : null;
        final mo = parts.length == 2 ? int.tryParse(parts[1]) : null;
        final date = (day != null && mo != null)
            ? DateTime(month.year, mo, day)
            : DateTime(month.year, month.month, 1);
        out.add(
          DailyFinanceRow(
            date: DateTime(date.year, date.month, date.day),
            processedCount: e.processedCount,
            processedAmount: e.processed,
            incomes: e.income,
            deposits: e.deposit,
            refund: e.refund,
            expenses: e.expense,
            manual: e.manual,
          ),
        );
      }
      return out;
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Network error', e.response?.statusCode);
    }
  }

  static Future<List<FinanceTransaction>> fetchTransactionsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final dateFrom = start.toIso8601String().split('T').first;
    final dateTo = end.toIso8601String().split('T').first;

    // NOTE:
    // We intentionally fetch using Dio directly here (rather than relying solely on
    // IncomeApi/ExpenseApi list parsing) because some deployments return list payloads
    // under keys like `items` or `results` instead of `data`.
    final incomes = await _fetchIncomeModels(dateFrom: dateFrom, dateTo: dateTo);
    final expenses = await _fetchExpenseModels(dateFrom: dateFrom, dateTo: dateTo);

    final out = <FinanceTransaction>[
      for (final i in incomes)
        FinanceTransaction(
          id: i.id,
          kind: FinanceTransactionKind.income,
          date: i.date,
          amount: i.amount,
          title: i.source.isNotEmpty ? i.source : 'Income',
        ),
      for (final e in expenses)
        FinanceTransaction(
          id: e.id,
          kind: FinanceTransactionKind.expense,
          date: e.date,
          amount: e.amount,
          title: e.title.isNotEmpty ? e.title : 'Expense',
        ),
    ];

    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static List<Map<String, dynamic>> _extractListMaps(dynamic data) {
    // Common shapes:
    // - List<Map> (already list)
    // - { data: [...] }
    // - { items: [...] }
    // - { results: [...] }
    // - { incomes: [...] } / { expenses: [...] }
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is! Map) return const [];
    final m = Map<String, dynamic>.from(data);
    dynamic list =
        m['data'] ?? m['items'] ?? m['results'] ?? m['incomes'] ?? m['expenses'];
    if (list is List) {
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    // Sometimes `data` itself contains `{ data: [...] }` nested one more level.
    if (m['data'] is Map) {
      final mm = Map<String, dynamic>.from(m['data'] as Map);
      list = mm['data'] ?? mm['items'] ?? mm['results'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return const [];
  }

  static Future<List<IncomeModel>> _fetchIncomeModels({
    String? dateFrom,
    String? dateTo,
  }) async {
    const pageSize = 200;
    final all = <IncomeModel>[];
    for (var page = 1;; page++) {
      try {
        final res = await IncomeApi.list(
          page: page,
          limit: pageSize,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
        all.addAll(res.items);
        if (res.items.isEmpty ||
            res.items.length < pageSize ||
            all.length >= res.total) {
          return all;
        }
      } catch (_) {
        if (page > 1) rethrow;
        final query = <String, dynamic>{'page': page, 'limit': pageSize};
        if (dateFrom != null) query['dateFrom'] = dateFrom;
        if (dateTo != null) query['dateTo'] = dateTo;
        final response = await DioClient.instance.get(
          ApiEndpoints.incomes,
          queryParameters: query,
        );
        final data = parseData(response);
        final raw = _extractListMaps(data);
        return raw.map(IncomeModel.fromJson).toList();
      }
    }
  }

  static Future<List<ExpenseModel>> _fetchExpenseModels({
    String? dateFrom,
    String? dateTo,
  }) async {
    const pageSize = 200;
    final all = <ExpenseModel>[];
    for (var page = 1;; page++) {
      try {
        final res = await ExpenseApi.list(
          page: page,
          limit: pageSize,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
        all.addAll(res.items);
        if (res.items.isEmpty ||
            res.items.length < pageSize ||
            all.length >= res.total) {
          return all;
        }
      } catch (_) {
        if (page > 1) rethrow;
        final query = <String, dynamic>{'page': page, 'limit': pageSize};
        if (dateFrom != null) query['dateFrom'] = dateFrom;
        if (dateTo != null) query['dateTo'] = dateTo;
        final response = await DioClient.instance.get(
          ApiEndpoints.expenses,
          queryParameters: query,
        );
        final data = parseData(response);
        final raw = _extractListMaps(data);
        return raw.map(ExpenseModel.fromJson).toList();
      }
    }
  }
}

