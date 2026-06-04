import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

final class MonthlyFinanceSummary {
  MonthlyFinanceSummary({
    required this.revenue,
    required this.expenses,
    required this.incomes,
    required this.refunds,
    required this.deposits,
    required this.profit,
  });

  final double revenue;
  final double expenses;
  final double incomes;
  final double refunds;
  final double deposits;
  final double profit;
}

final class DailyProcessedDto {
  DailyProcessedDto({required this.count, required this.amount});

  final int count;
  final double amount;
}

final class DailyFinanceRowDto {
  DailyFinanceRowDto({
    required this.date,
    required this.processed,
    required this.refund,
    required this.expenses,
    required this.income,
    required this.deposit,
  });

  final String date;
  final DailyProcessedDto processed;
  final double refund;
  final double expenses;
  final double income;
  final double deposit;
}

final class OrderChartPointDto {
  OrderChartPointDto({required this.date, required this.ordersDelivered});

  final String date;
  final int ordersDelivered;
}

final class MonthlyFinanceData {
  MonthlyFinanceData({
    required this.month,
    required this.summary,
    required this.daily,
    required this.ordersProcessed,
  });

  final String month;
  final MonthlyFinanceSummary summary;
  final List<DailyFinanceRowDto> daily;
  final List<OrderChartPointDto> ordersProcessed;
}

abstract final class FinanceMonthlyApi {
  static Future<MonthlyFinanceData> fetch(String month) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.vendorFinanceMonthly,
      queryParameters: <String, dynamic>{'month': month},
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid response');
    }
    final summaryRaw = data['summary'];
    final summary = summaryRaw is Map<String, dynamic>
        ? MonthlyFinanceSummary(
            revenue: _toDouble(summaryRaw['revenue']),
            expenses: _toDouble(summaryRaw['expenses']),
            incomes: _toDouble(summaryRaw['incomes']),
            refunds: _toDouble(summaryRaw['refunds']),
            deposits: _toDouble(summaryRaw['deposits']),
            profit: _toDouble(summaryRaw['profit']),
          )
        : MonthlyFinanceSummary(
            revenue: 0,
            expenses: 0,
            incomes: 0,
            refunds: 0,
            deposits: 0,
            profit: 0,
          );

    final dailyList = <DailyFinanceRowDto>[];
    final rawDaily = data['daily'];
    if (rawDaily is List) {
      for (final e in rawDaily) {
        if (e is! Map<String, dynamic>) continue;
        final proc = e['processed'];
        int count = 0;
        double amount = 0;
        if (proc is Map<String, dynamic>) {
          count = (proc['count'] as num?)?.toInt() ?? 0;
          amount = _toDouble(proc['amount']);
        }
        dailyList.add(
          DailyFinanceRowDto(
            date: e['date'] as String? ?? '',
            processed: DailyProcessedDto(count: count, amount: amount),
            refund: _toDouble(e['refund']),
            expenses: _toDouble(e['expenses']),
            income: _toDouble(e['income']),
            deposit: _toDouble(e['deposit']),
          ),
        );
      }
    }

    final chartRaw = data['chart'];
    final ordersProcessed = <OrderChartPointDto>[];
    if (chartRaw is Map<String, dynamic>) {
      final op = chartRaw['ordersProcessed'];
      if (op is List) {
        for (final e in op) {
          if (e is! Map<String, dynamic>) continue;
          ordersProcessed.add(
            OrderChartPointDto(
              date: e['date'] as String? ?? '',
              ordersDelivered: (e['ordersDelivered'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
    }

    return MonthlyFinanceData(
      month: data['month'] as String? ?? month,
      summary: summary,
      daily: dailyList,
      ordersProcessed: ordersProcessed,
    );
  }

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
}
