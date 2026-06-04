import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/payment_model.dart';

/// Paginated response from `GET /payments` (server returns data, total, page, limit, totalPages).
class PaymentListResult {
  const PaymentListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<PaymentModel> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasNextPage => page < totalPages;
}

abstract final class PaymentApi {
  static Future<PaymentListResult> list({
    int page = 1,
    int limit = 20,
    String? customerId,
    String? fromDate,
    String? toDate,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (customerId != null) query['customerId'] = customerId;
    if (fromDate != null) query['fromDate'] = fromDate;
    if (toDate != null) query['toDate'] = toDate;

    final response = await DioClient.instance.get(
      ApiEndpoints.payments,
      queryParameters: query,
    );

    final data = parseData(response);
    if (data is Map<String, dynamic>) {
      final rawList =
          (data['data'] as List?) ?? (data['payments'] as List?) ?? [];
      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => PaymentModel.fromJson(e))
          .toList();
      final total = (data['total'] as num?)?.toInt() ?? items.length;
      final resPage = (data['page'] as num?)?.toInt() ?? page;
      final resLimit = (data['limit'] as num?)?.toInt() ?? limit;
      var totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      if (totalPages < 1) totalPages = 1;
      return PaymentListResult(
        items: items,
        total: total,
        page: resPage,
        limit: resLimit,
        totalPages: totalPages,
      );
    }
    if (data is List) {
      final items = data
          .whereType<Map<String, dynamic>>()
          .map((e) => PaymentModel.fromJson(e))
          .toList();
      return PaymentListResult(
        items: items,
        total: items.length,
        page: page,
        limit: limit,
        totalPages: 1,
      );
    }
    return PaymentListResult(
      items: [],
      total: 0,
      page: page,
      limit: limit,
      totalPages: 0,
    );
  }

  static Future<PaymentModel> create(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.payments,
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return PaymentModel.fromJson(data);
  }

  static Future<Map<String, dynamic>> createRazorpayOrder({
    required double amount,
    String? receipt,
    String? customerId,
    String? invoiceId,
  }) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.paymentsCreateOrder,
      data: {
        'amount': amount,
        'receipt': ?receipt,
        'customerId': ?customerId,
        'invoiceId': ?invoiceId,
      },
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return data;
  }
}
