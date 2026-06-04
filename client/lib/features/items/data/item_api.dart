import 'package:flutter/foundation.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/item_model.dart';

abstract final class ItemApi {
  static Future<List<ItemModel>> list({
    int page = 1,
    int limit = 50,
    bool? isActive,
    String? category,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (isActive != null) query['isActive'] = isActive;
    if (category != null && category.isNotEmpty) query['category'] = category;

    final response = await DioClient.instance.get(
      ApiEndpoints.items,
      queryParameters: query,
    );

    final data = parseData(response); // returns { data: [...], total: 3 }
    List<dynamic> rawList = [];
    if (data is Map<String, dynamic>) {
      rawList = (data['data'] as List?) ?? [];
    } else if (data is List) {
      rawList = data;
    }

    if (kDebugMode) {
      debugPrint('✅ ItemApi.list parsed ${rawList.length} items');
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => ItemModel.fromJson(e))
        .toList();
  }

  static Future<ItemModel> getById(String id) async {
    final response = await DioClient.instance.get(ApiEndpoints.itemById(id));
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return ItemModel.fromJson(data);
  }

  static Future<ItemModel> create(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.items,
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return ItemModel.fromJson(data);
  }

  static Future<ItemModel> update(String id, Map<String, dynamic> body) async {
    final response = await DioClient.instance.put(
      ApiEndpoints.itemById(id),
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return ItemModel.fromJson(data);
  }

  static Future<void> delete(String id) async {
    await DioClient.instance.delete(ApiEndpoints.itemById(id));
  }
}
