import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/invoice_model.dart';

abstract final class InvoiceApi {
  static Future<List<InvoiceModel>> list({
    int page = 1,
    int limit = 20,
    String? customerId,
    String? paymentStatus,
    String? month,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (customerId != null) query['customerId'] = customerId;
    if (paymentStatus != null) query['paymentStatus'] = paymentStatus;
    if (month != null) query['month'] = month;

    final response = await DioClient.instance.get(
      ApiEndpoints.invoices,
      queryParameters: query,
    );

    final data = parseData(response); // returns { data: [...], total: N }
    List<dynamic> rawList = [];
    if (data is Map<String, dynamic>) {
      rawList = (data['data'] as List?) ??
                (data['invoices'] as List?) ?? [];
    } else if (data is List) {
      rawList = data;
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => InvoiceModel.fromJson(e))
        .toList();
  }

  static Future<List<InvoiceModel>> getOverdue() async {
    final response = await DioClient.instance.get(
      ApiEndpoints.invoicesOverdue,
    );

    final data = parseData(response);
    List<dynamic> rawList = [];
    if (data is Map<String, dynamic>) {
      rawList = (data['data'] as List?) ??
                (data['invoices'] as List?) ?? [];
    } else if (data is List) {
      rawList = data;
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => InvoiceModel.fromJson(e))
        .toList();
  }

  static Future<InvoiceModel> getById(String id) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.invoiceById(id),
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return InvoiceModel.fromJson(data);
  }

  static Future<InvoiceModel> generate({
    required String customerId,
    required DateTime billingStart,
    required DateTime billingEnd,
    String? subscriptionId,
  }) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.invoicesGenerate,
      data: {
        'customerId': customerId,
        'billingStart': billingStart.toIso8601String().split('T').first,
        'billingEnd': billingEnd.toIso8601String().split('T').first,
        'subscriptionId': ?subscriptionId,
      },
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return InvoiceModel.fromJson(data);
  }

  static Future<InvoiceModel> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await DioClient.instance.put(
      ApiEndpoints.invoiceById(id),
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return InvoiceModel.fromJson(data);
  }

  static Future<String> share(String id) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.invoiceShare(id),
    );
    final data = parseData(response);
    if (data is Map<String, dynamic> && data['shareUrl'] != null) {
      return data['shareUrl'] as String;
    }
    return '';
  }

  static Future<void> voidInvoice(String id) async {
    await DioClient.instance.post(ApiEndpoints.invoiceVoid(id));
  }

  /// Daily meal receipt for a customer (GET /invoices/daily).
  static Future<Map<String, dynamic>> getDailyReceipt({
    required String customerId,
    required DateTime date,
  }) async {
    try {
      final ds =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await DioClient.instance.get(
        ApiEndpoints.invoicesDaily,
        queryParameters: {'customerId': customerId, 'date': ds},
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