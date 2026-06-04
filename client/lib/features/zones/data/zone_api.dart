import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/zone_model.dart';

abstract final class ZoneApi {
  static Future<List<ZoneModel>> list({
    int page = 1,
    int limit = 50,
    bool? isActive,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (isActive != null) query['isActive'] = isActive;

    final response = await DioClient.instance.get(
      ApiEndpoints.zones,
      queryParameters: query,
    );

    final data = parseData(response);
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => ZoneModel.fromJson(e))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final list = data['data'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => ZoneModel.fromJson(e))
            .toList();
      }
    }
    return [];
  }

  static Future<ZoneModel> getById(String id) async {
    final response = await DioClient.instance.get(ApiEndpoints.zoneById(id));
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return ZoneModel.fromJson(data);
  }

  static Future<ZoneModel> create(Map<String, dynamic> body) async {
    final response =
        await DioClient.instance.post(ApiEndpoints.zones, data: body);
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return ZoneModel.fromJson(data);
  }

  static Future<ZoneModel> update(String id, Map<String, dynamic> body) async {
    final response =
        await DioClient.instance.put(ApiEndpoints.zoneById(id), data: body);
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return ZoneModel.fromJson(data);
  }

  static Future<void> deactivate(String id) async {
    await DioClient.instance.delete(ApiEndpoints.zoneById(id));
  }
}

