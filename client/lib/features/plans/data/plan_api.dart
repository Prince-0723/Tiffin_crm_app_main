import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/plan_model.dart';

abstract final class PlanApi {
  static Future<List<PlanModel>> list({
    int page = 1,
    int limit = 20,
    bool? isActive,
    String? planType,
    String? customerId,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (isActive != null) query['isActive'] = isActive;
    if (planType != null && planType.isNotEmpty) query['planType'] = planType;
    if (customerId != null && customerId.isNotEmpty) {
      query['customerId'] = customerId;
    }

    final response = await DioClient.instance.get(
      ApiEndpoints.plans,
      queryParameters: query,
    );

    final data = parseData(response); // returns { data: [...], total: N }
    List<dynamic> rawList = [];
    if (data is Map<String, dynamic>) {
      rawList = (data['data'] as List?) ?? (data['plans'] as List?) ?? [];
    } else if (data is List) {
      rawList = data;
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => PlanModel.fromJson(e))
        .toList();
  }

  static Future<PlanModel> getById(String id) async {
    final response = await DioClient.instance.get(ApiEndpoints.planById(id));
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return PlanModel.fromJson(data);
  }

  static Future<PlanModel> create(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.plans,
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return PlanModel.fromJson(data);
  }

  static Future<PlanModel> createForCustomer(
    String customerId,
    Map<String, dynamic> body,
  ) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.customerPlans(customerId),
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return PlanModel.fromJson(data);
  }

  static Future<PlanModel> update(String id, Map<String, dynamic> body) async {
    final response = await DioClient.instance.put(
      ApiEndpoints.planById(id),
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return PlanModel.fromJson(data);
  }

  static Future<void> delete(String id) async {
    await DioClient.instance.delete(ApiEndpoints.planById(id));
  }
}
