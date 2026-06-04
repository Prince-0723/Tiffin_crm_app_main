import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';

/// Single Nominatim search result.
class NominatimPlaceHit {
  const NominatimPlaceHit({
    required this.displayName,
    required this.latLng,
  });

  final String displayName;
  final LatLng latLng;
}

/// OpenStreetMap Nominatim (free). Use a descriptive User-Agent per usage policy.
/// Browsers forbid setting [User-Agent] on fetch; the default browser UA is sent on web.
abstract final class NominatimGeocodeService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        if (!kIsWeb) 'User-Agent': 'tiffin_crm/1.0 (delivery routing)',
        'Accept': 'application/json',
      },
    ),
  );

  /// Returns first search hit or null.
  static Future<LatLng?> searchFirst(String query) async {
    final hits = await searchPlaces(query, limit: 1);
    return hits.isEmpty ? null : hits.first.latLng;
  }

  /// Forward geocode: up to [limit] hits (max 10 recommended by Nominatim).
  static Future<List<NominatimPlaceHit>> searchPlaces(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final capped = limit.clamp(1, 10);
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '$capped',
      'addressdetails': '1',
    });
    try {
      final res = await _dio.get<List<dynamic>>(uri.toString());
      final list = res.data;
      if (list == null || list.isEmpty) return [];
      final out = <NominatimPlaceHit>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final name = item['display_name']?.toString().trim() ?? '';
        final lat = item['lat'];
        final lon = item['lon'];
        if (lat is! String || lon is! String) continue;
        final la = double.tryParse(lat);
        final lo = double.tryParse(lon);
        if (la == null || lo == null) continue;
        out.add(
          NominatimPlaceHit(displayName: name.isEmpty ? '$la, $lo' : name, latLng: LatLng(la, lo)),
        );
      }
      return out;
    } on DioException {
      rethrow;
    }
  }

  /// Reverse geocode: human-readable address for a point.
  static Future<String?> reverseDisplayName(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'json',
    });
    try {
      final res = await _dio.get<Map<String, dynamic>>(uri.toString());
      final map = res.data;
      if (map == null) return null;
      final name = map['display_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      return null;
    } on DioException {
      rethrow;
    }
  }
}
