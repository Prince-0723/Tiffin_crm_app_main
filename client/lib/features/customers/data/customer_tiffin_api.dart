import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/customer_tiffin_models.dart';

abstract final class CustomerTiffinApi {
  /// GET without `history` — [tiffinCount] only (lightweight for summary row).
  static Future<int> fetchCount(String customerId) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.vendorCustomerTiffin(customerId),
    );
    final data = parseData(response);
    if (data is Map<String, dynamic> && data['tiffinCount'] != null) {
      final tc = data['tiffinCount'];
      if (tc is num) return tc.toInt();
      return int.tryParse('$tc') ?? 0;
    }
    throw ApiException('Invalid tiffin response');
  }

  /// GET …/tiffin?history=true
  static Future<CustomerTiffinSnapshot> fetchWithHistory(String customerId) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.vendorCustomerTiffin(customerId),
      queryParameters: {'history': 'true'},
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid tiffin response');
    }
    return CustomerTiffinSnapshot.fromJson(data);
  }

  static Future<int> increment(String customerId) async {
    final response = await DioClient.instance.patch(
      ApiEndpoints.vendorCustomerTiffinIncrement(customerId),
      data: <String, dynamic>{},
    );
    final data = parseData(response);
    if (data is Map<String, dynamic> && data['tiffinCount'] != null) {
      final tc = data['tiffinCount'];
      if (tc is num) return tc.toInt();
      return int.tryParse('$tc') ?? 0;
    }
    throw ApiException('Invalid tiffin response');
  }

  static Future<int> decrement(String customerId) async {
    final response = await DioClient.instance.patch(
      ApiEndpoints.vendorCustomerTiffinDecrement(customerId),
      data: <String, dynamic>{},
    );
    final data = parseData(response);
    if (data is Map<String, dynamic> && data['tiffinCount'] != null) {
      final tc = data['tiffinCount'];
      if (tc is num) return tc.toInt();
      return int.tryParse('$tc') ?? 0;
    }
    throw ApiException('Invalid tiffin response');
  }
}
