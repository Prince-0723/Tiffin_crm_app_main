import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/maps/osm_map_constants.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/location_helper.dart';
import '../../../delivery/models/delivery_staff_model.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key, this.extra});

  /// Optional [DeliveryStaffModel] when opened from delivery staff list (track on map).
  final Object? extra;

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);

  final MapController _mapController = MapController();
  StreamSubscription<DeliveryLocationUpdate>? _sub;
  LatLng? _liveStaffPoint;

  DeliveryStaffModel? get _staff =>
      widget.extra is DeliveryStaffModel ? widget.extra as DeliveryStaffModel : null;

  @override
  void initState() {
    super.initState();
    final staff = _staff;
    final staticLoc = staff?.location;
    if (staticLoc != null) {
      _liveStaffPoint = LatLng(staticLoc.lat, staticLoc.lng);
    }
    _subscribeLive();
  }

  Future<void> _subscribeLive() async {
    final staff = _staff;
    if (staff == null) return;
    await DeliveryTrackingSocket.instance.ensureConnected();
    _sub = DeliveryTrackingSocket.instance.updates.listen((u) {
      if (u.staffId != staff.id) return;
      if (!mounted) return;
      final next = LatLng(u.lat, u.lng);
      setState(() => _liveStaffPoint = next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(next, 15);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staff = _staff;
    final staticLoc = staff?.location;
    final center = _liveStaffPoint ??
        (staticLoc != null ? LatLng(staticLoc.lat, staticLoc.lng) : _defaultCenter);
    final zoom = (staticLoc != null || _liveStaffPoint != null) ? 15.0 : 12.0;
    final hasPin = staticLoc != null || _liveStaffPoint != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(staff != null ? '${staff.name} on map' : 'Delivery Route'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: AppColors.onSurface,
        actions: [
          if (hasPin)
            IconButton(
              tooltip: 'Open in OpenStreetMap',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => LocationHelper.openInMaps(center.latitude, center.longitude),
            ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
        ),
        children: [
          OsmMapConstants.tileLayer(),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 48,
                height: 48,
                alignment: Alignment.bottomCenter,
                child: Tooltip(
                  message: staff?.name ?? 'Location',
                  child: Icon(
                    Icons.location_on_rounded,
                    color: theme.colorScheme.primary,
                    size: 44,
                  ),
                ),
              ),
            ],
          ),
          SimpleAttributionWidget(
            source: Text(OsmMapConstants.attributionLabel),
            onTap: () async {
              final u = OsmMapConstants.attributionCopyrightUri;
              if (await canLaunchUrl(u)) {
                await launchUrl(u, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}
