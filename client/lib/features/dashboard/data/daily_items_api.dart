import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

/// Client-side veg hint: item name is treated as veg if it contains any hint (lowercase).
bool matchesVegItemName(String rawName) {
  final n = rawName.toLowerCase().trim();
  if (n.isEmpty) return false;
  const hints = <String>[
    'roti',
    'chapati',
    'paratha',
    'phulka',
    'naan',
    'rice',
    'jeera rice',
    'dal',
    'daal',
    'dhal',
    'sambar',
    'rasam',
    'sabzi',
    'sabji',
    'subzi',
    'paneer',
    'aloo',
    'potato',
    'gobi',
    'bhindi',
    'baingan',
    'rajma',
    'chole',
    'chhole',
    'chana',
    'pulao',
    'khichdi',
    'poha',
    'upma',
    'dosa',
    'idli',
    'uttapam',
    'curd',
    'raita',
    'salad',
    'pickle',
    'papad',
    'puri',
    'kheer',
    'halwa',
    'veg ',
    'vegetable',
    'palak',
    'methi',
    'mix veg',
    'kadhi',
    'pav',
    'bread',
  ];
  for (final h in hints) {
    if (n.contains(h)) return true;
  }
  return false;
}

final class DailyItemRow {
  const DailyItemRow({
    required this.name,
    required this.unit,
    required this.totalQuantity,
  });

  final String name;
  final String unit;
  final int totalQuantity;

  factory DailyItemRow.fromJson(Map<String, dynamic> json) {
    return DailyItemRow(
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

final class DailyItemsResult {
  const DailyItemsResult({
    required this.date,
    required this.items,
    this.customerCount,
  });

  final String date;
  final List<DailyItemRow> items;

  /// Optional: customers included in this slot aggregate (if backend sends it).
  final int? customerCount;
}

abstract final class DailyItemsApi {
  /// [slot] is one of `breakfast`, `lunch`, `dinner`, or null / empty for all slots combined.
  ///
  /// Sent to the server as `mealPeriod` (see vendor dashboard daily-items).
  ///
  /// When [forDay] is null or equals **today** (local), the `date` query param is omitted.
  static Future<DailyItemsResult> fetch({
    DateTime? forDay,
    String? slot,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final query = <String, dynamic>{};
    final day = forDay ?? today;
    final d = DateTime(day.year, day.month, day.day);
    if (d != today) {
      query['date'] =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    final s = slot?.trim().toLowerCase();
    if (s != null &&
        s.isNotEmpty &&
        (s == 'breakfast' || s == 'lunch' || s == 'dinner')) {
      query['mealPeriod'] = s;
    }

    final response = await DioClient.instance.get(
      ApiEndpoints.vendorDashboardDailyItems,
      queryParameters: query.isEmpty ? null : query,
    );
    final data = parseData(response);
    if (data is! Map<String, dynamic>) {
      throw ApiException('Invalid response');
    }
    final itemsRaw = data['items'];
    final list = <DailyItemRow>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map<String, dynamic>) {
          list.add(DailyItemRow.fromJson(e));
        }
      }
    }
    final ccRaw =
        data['customerCount'] ?? data['customersCount'] ?? data['customer_count'];
    int? customerCount;
    if (ccRaw is num) {
      customerCount = ccRaw.toInt();
    }

    return DailyItemsResult(
      date: data['date']?.toString() ?? '',
      items: list,
      customerCount: customerCount,
    );
  }
}
