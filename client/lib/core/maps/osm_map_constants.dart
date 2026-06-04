import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

/// Map tile layer settings (flutter_map).
///
/// Uses **Carto Basemaps** (OSM-derived, CDN-hosted): works on **web** (CORS) and
/// avoids blank/blue maps when direct `tile.openstreetmap.org` is blocked or throttled.
/// [userAgentPackageName] must match pubspec `name:` per tile policy.
abstract final class OsmMapConstants {
  static const String userAgentPackageName = 'tiffin_crm';

  static const String _cartoTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  static const String attributionLabel = '© OpenStreetMap © CARTO';

  static final Uri attributionCopyrightUri =
      Uri.parse('https://carto.com/attribution/');

  static TileLayer tileLayer() {
    return TileLayer(
      urlTemplate: _cartoTemplate,
      userAgentPackageName: userAgentPackageName,
      subdomains: cartoSubdomains,
      // Web limits concurrent HTTP requests; cancellable Dio provider frees slots
      // when tiles scroll off-screen so new tiles can load (avoids blank blue map).
      tileProvider:
          kIsWeb ? CancellableNetworkTileProvider() : NetworkTileProvider(),
    );
  }
}
