import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

abstract final class ReportApi {
  static Future<Map<String, dynamic>> getSummary({
    String period = 'monthly',
  }) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.reportsSummary,
      queryParameters: {'period': period},
    );
    final data = parseData(response);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Order rows for today (legacy helper — API returns `{ orders, total, ... }`).
  static Future<List<dynamic>> getTodayDeliveries() async {
    final payload = await getTodayDeliveriesPayload();
    final orders = payload['orders'];
    if (orders is List) return orders;
    return [];
  }

  /// Full payload: `date`, `total`, `summary` (counts by status), `orders`.
  static Future<Map<String, dynamic>> getTodayDeliveriesPayload() async {
    final response =
        await DioClient.instance.get(ApiEndpoints.reportsTodayDeliveries);
    final data = parseData(response);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  static Future<List<dynamic>> getExpiringSubscriptions({int days = 7}) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.reportsExpiringSubscriptions,
      queryParameters: {'days': days},
    );
    final data = parseData(response);
    if (data is List) return data;
    if (data is Map) {
      final subs = data['subscriptions'];
      if (subs is List) return subs;
    }
    return [];
  }

  static Future<Map<String, dynamic>> getPendingPayments() async {
    final response =
        await DioClient.instance.get(ApiEndpoints.reportsPendingPayments);
    final data = parseData(response);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}
