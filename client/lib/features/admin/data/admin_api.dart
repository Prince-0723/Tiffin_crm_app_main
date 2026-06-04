import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/customer_model.dart';
import '../models/admin_stats_model.dart';
import '../../delivery/models/delivery_staff_model.dart';
import '../../plans/models/plan_model.dart';
import '../../items/models/item_model.dart';
import '../../subscriptions/models/subscription_model.dart';
import '../../orders/models/order_model.dart';
import '../../payments/models/payment_model.dart';
import '../../payments/models/invoice_model.dart';
import '../models/vendor_stats_model.dart';

/// Admin list endpoints return `{ data: [...], total, page, ... }` inside `data`.
List<dynamic> _adminListRows(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    final inner = data['data'];
    if (inner is List) return inner;
    if (data['vendors'] is List) return data['vendors'] as List;
  }
  return [];
}

Map<String, dynamic> _rowMap(dynamic e) {
  if (e is Map<String, dynamic>) return e;
  if (e is Map) return Map<String, dynamic>.from(e);
  return {};
}

abstract final class AdminApi {
  static Future<AdminStatsModel> getStats() async {
    final response = await DioClient.instance.get(ApiEndpoints.adminStats);
    final data = parseData(response);
    if (data is! Map) throw ApiException('Invalid response');
    return AdminStatsModel.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<List<VendorStatsModel>> getVendorStats() async {
    try {
      final response = await DioClient.instance.get(
        ApiEndpoints.adminVendorsStats,
      );
      final data = parseData(response);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map<String, dynamic>) {
        raw = (data['data'] as List?) ?? [];
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(VendorStatsModel.fromJson)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> getVendors({
    int page = 1,
    int limit = 20,
    bool? isActive,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (isActive != null) query['isActive'] = isActive;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminVendors,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data);
  }

  static Future<List<CustomerModel>> getCustomers({
    int page = 1,
    int limit = 20,
    String? vendorId,
    String? status,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    if (status != null) query['status'] = status;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminCustomers,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(CustomerModel.fromJson)
        .toList();
  }

  static Future<List<DeliveryStaffModel>> getDeliveryStaff({
    int page = 1,
    int limit = 20,
    String? vendorId,
    bool? isActive,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    if (isActive != null) query['isActive'] = isActive;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminDeliveryStaff,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(DeliveryStaffModel.fromJson)
        .toList();
  }

  static Future<List<PlanModel>> getPlans({
    int page = 1,
    int limit = 20,
    String? vendorId,
    bool? isActive,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    if (isActive != null) query['isActive'] = isActive;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminPlans,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(PlanModel.fromJson)
        .toList();
  }

  static Future<List<ItemModel>> getItems({
    int page = 1,
    int limit = 20,
    String? vendorId,
    bool? isActive,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    if (isActive != null) query['isActive'] = isActive;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminItems,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(ItemModel.fromJson)
        .toList();
  }

  static Future<List<SubscriptionModel>> getSubscriptions({
    int page = 1,
    int limit = 20,
    String? vendorId,
    String? status,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    if (status != null) query['status'] = status;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminSubscriptions,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(SubscriptionModel.fromJson)
        .toList();
  }

  static Future<List<OrderModel>> getOrders({
    int page = 1,
    int limit = 20,
    String? vendorId,
    String? status,
    String? date,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    if (status != null) query['status'] = status;
    if (date != null) query['date'] = date;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminOrders,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(OrderModel.fromJson)
        .toList();
  }

  static Future<List<PaymentModel>> getPayments({
    int page = 1,
    int limit = 20,
    String? vendorId,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminPayments,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(PaymentModel.fromJson)
        .toList();
  }

  static Future<List<InvoiceModel>> getInvoices({
    int page = 1,
    int limit = 20,
    String? vendorId,
    String? paymentStatus,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (vendorId != null) query['vendorId'] = vendorId;
    if (paymentStatus != null) query['paymentStatus'] = paymentStatus;
    final response = await DioClient.instance.get(
      ApiEndpoints.adminInvoices,
      queryParameters: query,
    );
    final data = parseData(response);
    return _adminListRows(data)
        .map(_rowMap)
        .where((m) => m.isNotEmpty)
        .map(InvoiceModel.fromJson)
        .toList();
  }
}
