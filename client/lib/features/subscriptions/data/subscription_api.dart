import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/subscription_model.dart';

abstract final class SubscriptionApi {
  static Future<Map<String, dynamic>> list({
    int page = 1,
    int limit = 20,
    String? status,
    String? customerId,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (customerId != null && customerId.isNotEmpty) {
      query['customerId'] = customerId;
    }

    final response = await DioClient.instance.get(
      ApiEndpoints.subscriptions,
      queryParameters: query,
    );

    final data = parseData(response);
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  static Future<SubscriptionModel> getById(String id) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.subscriptionById(id),
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return SubscriptionModel.fromJson(data);
  }

  static Future<SubscriptionModel> create(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.subscriptions,
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return SubscriptionModel.fromJson(data);
  }

  static Future<void> renew(
    String id,
    DateTime startDate,
    DateTime endDate, {
    bool payLater = false,
    DateTime? paymentDueDate,
    double? creditLimit,
  }) async {
    await DioClient.instance.put(
      ApiEndpoints.subscriptionRenew(id),
      data: {
        'startDate': startDate.toIso8601String().split('T').first,
        'endDate': endDate.toIso8601String().split('T').first,
        'payLater': payLater,
        if (payLater && paymentDueDate != null)
          'paymentDueDate': paymentDueDate.toIso8601String().split('T').first,
        if (payLater && creditLimit != null) 'creditLimit': creditLimit,
      },
    );
  }

  static Future<void> cancel(String id) async {
    await DioClient.instance.put(ApiEndpoints.subscriptionCancel(id));
  }

  /// Permanent delete (vendor/admin). Same path as GET — uses DELETE.
  static Future<void> delete(String id) async {
    await DioClient.instance.delete(ApiEndpoints.subscriptionById(id));
  }

  static Future<void> pause(
    String id, {
    required DateTime pausedFrom,
    required DateTime pausedUntil,
  }) async {
    await DioClient.instance.put(
      ApiEndpoints.subscriptionPause(id),
      data: {
        'pausedFrom': pausedFrom.toIso8601String().split('T').first,
        'pausedUntil': pausedUntil.toIso8601String().split('T').first,
      },
    );
  }

  static Future<void> toggleAutoRenew(String id, bool value) async {
    await DioClient.instance.put(
      ApiEndpoints.subscriptionRenew(id), // renew endpoint reuse
      data: {'autoRenew': value},
    );
  }

  static Future<void> unpause(String id) async {
    await DioClient.instance.put(ApiEndpoints.subscriptionUnpause(id));
  }
}
