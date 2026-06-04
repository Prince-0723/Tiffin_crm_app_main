import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/expense_model.dart';

class ExpenseListResult {
  const ExpenseListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<ExpenseModel> items;
  final int total;
  final int page;
  final int limit;
}

abstract final class ExpenseApi {
  static Future<ExpenseListResult> list({
    int page = 1,
    int limit = 20,
    String? category,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'limit': limit};
      if (category != null && category.isNotEmpty) query['category'] = category;
      if (dateFrom != null) query['dateFrom'] = dateFrom;
      if (dateTo != null) query['dateTo'] = dateTo;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final response = await DioClient.instance.get(
        ApiEndpoints.expenses,
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
          .map(ExpenseModel.fromJson)
          .toList();
      return ExpenseListResult(
        items: items,
        total: total,
        page: page,
        limit: limit,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<ExpenseModel> create(Map<String, dynamic> body) async {
    try {
      final response = await DioClient.instance.post(
        ApiEndpoints.expenses,
        data: body,
      );
      final data = parseData(response);
      if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
      return ExpenseModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> delete(String id) async {
    try {
      await DioClient.instance.delete(ApiEndpoints.expenseById(id));
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> summary() async {
    try {
      final response = await DioClient.instance.get(
        ApiEndpoints.expensesSummary,
      );
      final data = parseData(response);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw ApiException('Invalid response');
    } catch (e) {
      rethrow;
    }
  }
}
