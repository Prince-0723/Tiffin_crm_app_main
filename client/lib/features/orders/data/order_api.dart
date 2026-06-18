import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/order_model.dart';

final class BulkOrderStatusResult {
  const BulkOrderStatusResult({
    required this.status,
    required this.requestedCount,
    required this.updatedCount,
    required this.skippedSameStatus,
    required this.skippedInvalidTransition,
    required this.notFoundCount,
    required this.failures,
  });

  final String status;
  final int requestedCount;
  final int updatedCount;
  final int skippedSameStatus;
  final int skippedInvalidTransition;
  final int notFoundCount;
  final List<BulkOrderStatusFailure> failures;

  static BulkOrderStatusResult fromJson(Map<String, dynamic> json) {
    final rawFailures = json['failures'];
    final failures = <BulkOrderStatusFailure>[];
    if (rawFailures is List) {
      for (final e in rawFailures) {
        if (e is Map<String, dynamic>) {
          failures.add(BulkOrderStatusFailure.fromJson(e));
        } else if (e is Map) {
          failures.add(
            BulkOrderStatusFailure.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return BulkOrderStatusResult(
      status: json['status']?.toString() ?? '',
      requestedCount: (json['requestedCount'] as num?)?.toInt() ?? 0,
      updatedCount: (json['updatedCount'] as num?)?.toInt() ?? 0,
      skippedSameStatus: (json['skippedSameStatus'] as num?)?.toInt() ?? 0,
      skippedInvalidTransition:
          (json['skippedInvalidTransition'] as num?)?.toInt() ?? 0,
      notFoundCount: (json['notFoundCount'] as num?)?.toInt() ?? 0,
      failures: failures,
    );
  }
}

final class BulkOrderStatusFailure {
  const BulkOrderStatusFailure({required this.orderId, required this.message});

  final String orderId;
  final String message;

  static BulkOrderStatusFailure fromJson(Map<String, dynamic> json) {
    return BulkOrderStatusFailure(
      orderId: json['orderId']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

abstract final class OrderApi {
  /// [mealPeriod] is one of: breakfast | lunch | dinner | snack.
  static Future<List<OrderModel>> getToday({String? mealPeriod}) async {
    final mp = mealPeriod?.trim().toLowerCase();
    final query = <String, dynamic>{};
    if (mp != null &&
        mp.isNotEmpty &&
        (mp == 'breakfast' || mp == 'lunch' || mp == 'dinner' || mp == 'snack')) {
      query['mealPeriod'] = mp;
    }

    final response = await DioClient.instance.get(
      ApiEndpoints.dailyOrdersToday,
      queryParameters: query.isEmpty ? null : query,
    );
    final data = parseData(response);
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => OrderModel.fromJson(e))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final list = data['data'] ?? data['orders'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => OrderModel.fromJson(e))
            .toList();
      }
    }
    return [];
  }

  static Future<void> process({String? date}) async {
    await DioClient.instance.post(
      ApiEndpoints.dailyOrdersProcess,
      data: date != null ? {'date': date} : null,
    );
  }

  /// Cancels all non-delivered daily orders for [date] (YYYY-MM-DD) or today.
  /// Subscription/wallet deduction happens when an order moves to processing.
  static Future<int> cancelVendorHoliday({String? date}) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.dailyOrdersCancelVendorHoliday,
      data: date != null ? {'date': date} : null,
    );
    final data = parseData(response);
    if (data is Map<String, dynamic>) {
      return (data['cancelledCount'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static Future<void> assign(String orderId, String deliveryStaffId) async {
    await DioClient.instance.patch(
      ApiEndpoints.dailyOrderAssign(orderId),
      data: {'deliveryStaffId': deliveryStaffId},
    );
  }

  static Future<void> assignBulk(
    List<String> orderIds,
    String deliveryStaffId,
  ) async {
    await DioClient.instance.post(
      ApiEndpoints.dailyOrdersAssignBulk,
      data: {'orderIds': orderIds, 'deliveryStaffId': deliveryStaffId},
    );
  }

  static Future<void> updateStatus(String orderId, String status) async {
    await DioClient.instance.patch(
      ApiEndpoints.dailyOrderStatus(orderId),
      data: {'status': status},
    );
  }

  /// Same lifecycle as [updateStatus] for many orders (vendor dashboard bulk bar).
  static Future<BulkOrderStatusResult> updateStatusBulk(
    List<String> orderIds,
    String status,
  ) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.dailyOrdersBulkStatus,
      data: {'orderIds': orderIds, 'status': status},
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid bulk status response', response.statusCode);
    }
    return BulkOrderStatusResult.fromJson(data);
  }

  static Future<void> updateQuantities(
    String orderId,
    List<Map<String, dynamic>> quantities,
  ) async {
    await DioClient.instance.patch(
      ApiEndpoints.dailyOrderQuantities(orderId),
      data: quantities,
    );
  }

  static Future<void> accept(String orderId) async {
    await DioClient.instance.post(ApiEndpoints.dailyOrderAccept(orderId));
  }

  static Future<void> reject(String orderId, {required String reason}) async {
    await DioClient.instance.post(
      ApiEndpoints.dailyOrderReject(orderId),
      data: {'reason': reason},
    );
  }

  static Future<void> generate({String? date}) async {
    await DioClient.instance.post(
      ApiEndpoints.dailyOrdersGenerate,
      data: date != null ? {'date': date} : null,
    );
  }
}
