import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';

/// Result of OSRM `route` with geometry + legs summary.
final class OsrmRouteResult {
  const OsrmRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

/// Fetches a road route as GeoJSON coordinates using the public OSRM demo.
/// For production, use your own OSRM / Valhalla / ORS instance.
/// Browsers forbid setting [User-Agent] on fetch; omitted on web.
abstract final class OsrmRouteService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        if (!kIsWeb) 'User-Agent': 'tiffin_crm (flutter_map; contact: app)',
      },
    ),
  );

  /// OSRM demo server — acceptable for dev; replace for production load.
  static const String _base =
      'https://router.project-osrm.org/route/v1/driving';

  static Future<List<LatLng>> fetchRoute(LatLng from, LatLng to) async {
    final r = await fetchRouteDetailed(from, to);
    return r?.points ?? [];
  }

  static Future<OsrmRouteResult?> fetchRouteDetailed(
    LatLng from,
    LatLng to,
  ) async {
    final coord =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final res = await _dio.get<Map<String, dynamic>>(
      '$_base/$coord',
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
      },
    );
    final data = res.data;
    if (data == null) return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route0 = routes.first;
    if (route0 is! Map<String, dynamic>) return null;
    final dist = route0['distance'];
    final dur = route0['duration'];
    final geometry = route0['geometry'];
    if (geometry is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List) return null;

    final out = <LatLng>[];
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final a = c[0];
        final b = c[1];
        if (a is num && b is num) {
          out.add(LatLng(b.toDouble(), a.toDouble()));
        }
      }
    }
    if (out.length < 2) return null;
    final dm = dist is num ? dist.toDouble() : 0.0;
    final ds = dur is num ? dur.toDouble() : 0.0;
    return OsrmRouteResult(
      points: out,
      distanceMeters: dm,
      durationSeconds: ds,
    );
  }
}
