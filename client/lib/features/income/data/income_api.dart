import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/income_model.dart';

class IncomeListResult {
  const IncomeListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<IncomeModel> items;
  final int total;
  final int page;
  final int limit;
}

abstract final class IncomeApi {
  static Future<IncomeListResult> list({
    int page = 1,
    int limit = 20,
    String? source,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'limit': limit};
      if (source != null && source.isNotEmpty) query['source'] = source;
      if (dateFrom != null) query['dateFrom'] = dateFrom;
      if (dateTo != null) query['dateTo'] = dateTo;

      final response = await DioClient.instance.get(
        ApiEndpoints.incomes,
        queryParameters: query,
      );
      final data = parseData(response);
      List<dynamic> rawList = [];
      int total = 0;
      if (data is Map<String, dynamic>) {
        rawList = (data['data'] as List?) ?? [];
        total = (data['total'] as num?)?.toInt() ?? rawList.length;
      } else if (data is List) {
        rawList = data;
        total = rawList.length;
      }
      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map(IncomeModel.fromJson)
          .toList();
      return IncomeListResult(
        items: items,
        total: total,
        page: page,
        limit: limit,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<IncomeModel> create(Map<String, dynamic> body) async {
    try {
      final response = await DioClient.instance.post(
        ApiEndpoints.incomes,
        data: body,
      );
      final data = parseData(response);
      if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
      return IncomeModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> delete(String id) async {
    try {
      await DioClient.instance.delete(ApiEndpoints.incomeById(id));
    } catch (e) {
      rethrow;
    }
  }
}
