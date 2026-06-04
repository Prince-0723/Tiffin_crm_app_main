import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/customer_model.dart';

abstract final class CustomerApi {
  static Future<Map<String, dynamic>> list({
    int page = 1,
    int limit = 20,
    String? status,
    bool? lowBalance,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (lowBalance == true) query['lowBalance'] = 'true';

    final response = await DioClient.instance.get(
      ApiEndpoints.customers,
      queryParameters: query,
    );

    final data = parseData(response); // returns { data: [...], total: N }
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  static Future<CustomerModel> getById(String id) async {
    final response = await DioClient.instance.get(
      ApiEndpoints.customerById(id),
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return CustomerModel.fromJson(data);
  }

  static Future<CustomerModel> create(Map<String, dynamic> body) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.customers,
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return CustomerModel.fromJson(data);
  }

  static Future<CustomerModel> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await DioClient.instance.put(
      ApiEndpoints.customerById(id),
      data: body,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) throw ApiException('Invalid response');
    return CustomerModel.fromJson(data);
  }

  static Future<void> delete(String id) async {
    await DioClient.instance.delete(ApiEndpoints.customerById(id));
  }

  static int _readInt(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is num) return v.toInt();
    return 0;
  }

  static List<CustomerModel> _readCustomerList(Map<String, dynamic> data) {
    final raw = data['data'];
    if (raw is! List) return [];
    final out = <CustomerModel>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(CustomerModel.fromJson(item));
      }
    }
    return out;
  }

  static Future<Map<String, dynamic>> bulkImport(
    List<Map<String, dynamic>> customers,
  ) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.customersBulk,
      data: {'customers': customers},
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      return {'imported': 0, 'skipped': 0, 'customers': <CustomerModel>[]};
    }
    final importedCount = _readInt(data, 'imported') != 0
        ? _readInt(data, 'imported')
        : _readInt(data, 'created');
    return {
      'imported': importedCount,
      'skipped': _readInt(data, 'skipped'),
      'customers': _readCustomerList(data),
      'errors': data['errors'],
      'warnings': data['warnings'],
    };
  }

  /// Raw CSV as pasted in the bulk import screen (`name,phone,address,zone` …).
  static Future<Map<String, dynamic>> bulkImportCsv(String csv) async {
    final response = await DioClient.instance.post(
      ApiEndpoints.customersBulk,
      data: {'csv': csv},
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      return {'imported': 0, 'skipped': 0, 'customers': <CustomerModel>[]};
    }
    final importedCount = _readInt(data, 'imported') != 0
        ? _readInt(data, 'imported')
        : _readInt(data, 'created');
    return {
      'imported': importedCount,
      'skipped': _readInt(data, 'skipped'),
      'customers': _readCustomerList(data),
      'errors': data['errors'],
      'warnings': data['warnings'],
    };
  }

  static Future<void> creditWallet(
    String customerId, {
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    await DioClient.instance.post(
      ApiEndpoints.customerWalletCredit(customerId),
      data: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }
}
