import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/delivery/staff_location_sync.dart';
import '../../../../core/maps/osm_map_constants.dart';
import '../../../../core/routing/osrm_route_service.dart';
import '../../../../core/socket/delivery_tracking_socket.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/location_helper.dart';
import '../../data/delivery_api.dart';
import '../../../orders/models/order_model.dart';
import '../models/delivery_map_session.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({
    super.key,
    this.showAppBar = true,
    this.orders,
    this.session,
  });

  final bool showAppBar;

  /// When null, loads [DeliveryApi.getMyDeliveries] (standalone route).
  final List<OrderModel>? orders;

  /// Embedded-only: how to render (overview / one customer route / all on-the-way).
  final DeliveryMapSession? session;

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  static const _violet900 = Color(0xFF2D1B69);
  static const _violet700 = Color(0xFF4C2DB8);
  static const _violet600 = Color(0xFF5B35D5);
  static const _violet100 = Color(0xFFEDE8FD);
  static const _violet50 = Color(0xFFF5F2FF);
  static const _bg = Color(0xFFF6F4FF);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4DFF7);
  static const _textPrimary = Color(0xFF1A0E45);
  static const _textSecondary = Color(0xFF7B6DAB);
  static const _success = Color(0xFF0F7B0F);

  static const LatLng _indore = LatLng(22.7196, 75.8577);

  final MapController _mapController = MapController();

  List<OrderModel> _orders = [];
  bool _loading = true;
  bool _updatingLocation = false;
  List<Marker> _markers = [];
  LatLng? _myPosition;
  List<LatLng> _routePolyline = [];
  int _routeRequestId = 0;
  bool _hintedLocationOnce = false;
  double? _routeKm;
  double? _routeMinutes;
  bool _initialOverviewCamera = false;

  /// Single-route: stream GPS, follow camera, live distance; refresh OSRM periodically.
  bool _navigationActive = false;
  StreamSubscription<Position>? _navigationSub;
  Timer? _navigationRouteTimer;
  DateTime? _lastNavPush;

  DeliveryMapDisplayMode get _mode =>
      widget.session?.mode ?? DeliveryMapDisplayMode.overview;

  List<OrderModel> get _onWayOrders {
    return _orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'out_for_delivery' || s == 'in_transit';
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    DeliveryTrackingSocket.instance.ensureConnected();
    if (widget.orders != null) {
      _orders = List<OrderModel>.from(widget.orders!);
      _loading = false;
    } else {
      _load();
    }
    _rebuildMarkers();
    _loadSingleRouteIfNeeded();
    _fetchMyLocation();
  }

  @override
  void didUpdateWidget(covariant DeliveryMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.orders, oldWidget.orders)) {
      if (widget.orders != null) {
        setState(() => _orders = List<OrderModel>.from(widget.orders!));
        _rebuildMarkers();
        _onModeCamera();
      }
    }
    if (widget.session != oldWidget.session) {
      _cancelNavigationResources();
      setState(() {
        _navigationActive = false;
        _routePolyline = [];
        _routeKm = null;
        _routeMinutes = null;
      });
      _rebuildMarkers();
      _loadSingleRouteIfNeeded();
      _onModeCamera();
    }
  }

  @override
  void dispose() {
    _cancelNavigationResources();
    _mapController.dispose();
    super.dispose();
  }

  void _cancelNavigationResources() {
    _navigationSub?.cancel();
    _navigationSub = null;
    _navigationRouteTimer?.cancel();
    _navigationRouteTimer = null;
    _lastNavPush = null;
  }

  double? get _liveStraightKmToCustomer {
    final c = widget.session?.focusCustomer;
    final me = _myPosition;
    if (c == null || me == null) return null;
    return LocationHelper.distanceKm(
      me.latitude,
      me.longitude,
      c.latitude,
      c.longitude,
    );
  }

  int? get _liveEtaMinutesRough {
    final km = _liveStraightKmToCustomer;
    if (km == null) return null;
    const avgKmh = 22.0;
    final mins = ((km / avgKmh) * 60).ceil();
    return mins < 1 ? 1 : mins;
  }

  void _stopLiveNavigation() {
    final wasFollowing = _navigationActive;
    _cancelNavigationResources();
    if (!mounted) return;
    setState(() => _navigationActive = false);
    if (wasFollowing) {
      _fitSingleOrMulti();
    }
  }

  Future<void> _startLiveNavigation() async {
    if (_mode != DeliveryMapDisplayMode.singleRoute) return;
    final pos = await LocationHelper.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      AppSnackbar.info(
        context,
        'Turn on GPS and allow location to use live navigation.',
      );
      return;
    }
    _cancelNavigationResources();
    setState(() {
      _navigationActive = true;
      _myPosition = LatLng(pos.latitude, pos.longitude);
    });
    _rebuildMarkers();
    _navigationRouteTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _navigationActive) {
        unawaited(_loadSingleRouteIfNeeded());
      }
    });
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _navigationSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      _onNavigationPosition,
      onError: (_) {},
    );
    await _loadSingleRouteIfNeeded();
    if (mounted && _navigationActive) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
    }
  }

  void _onNavigationPosition(Position pos) {
    if (!mounted || !_navigationActive) return;
    final ll = LatLng(pos.latitude, pos.longitude);
    setState(() => _myPosition = ll);
    _rebuildMarkers();
    _mapController.move(ll, 16);
    _maybePushNavPosition(pos);
  }

  void _maybePushNavPosition(Position pos) {
    final now = DateTime.now();
    if (_lastNavPush != null &&
        now.difference(_lastNavPush!) < const Duration(seconds: 20)) {
      return;
    }
    _lastNavPush = now;
    unawaited(StaffLocationSync.pushFromPosition(pos, _orders));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await DeliveryApi.getMyDeliveries();
      if (mounted) {
        setState(() {
          _orders = list;
        });
        _rebuildMarkers();
        _onModeCamera();
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMyLocation() async {
    final position = await LocationHelper.getCurrentPosition();
    if (!mounted) return;
    if (position != null) {
      setState(() {
        _myPosition = LatLng(position.latitude, position.longitude);
      });
      _rebuildMarkers();
      _loadSingleRouteIfNeeded();
      _applyOverviewOrRefit();
    } else {
      if (!_hintedLocationOnce) {
        _hintedLocationOnce = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AppSnackbar.info(
            context,
            'Turn on GPS and allow location to see yourself on the map. Tap the purple location button to share.',
          );
        });
      }
      _rebuildMarkers();
      _loadSingleRouteIfNeeded();
      _applyOverviewOrRefit();
    }
  }

  void _applyOverviewOrRefit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mode == DeliveryMapDisplayMode.overview) {
        if (!_initialOverviewCamera) {
          _initialOverviewCamera = true;
          _mapController.move(_myPosition ?? _indore, 14);
        }
      } else {
        _onModeCamera();
      }
    });
  }

  void _onModeCamera() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_mode) {
        case DeliveryMapDisplayMode.overview:
          _mapController.move(_myPosition ?? _indore, 14);
          break;
        case DeliveryMapDisplayMode.singleRoute:
          _fitSingleOrMulti();
          break;
        case DeliveryMapDisplayMode.multiOnWay:
          _fitSingleOrMulti();
          break;
      }
    });
  }

  void _fitSingleOrMulti() {
    final pts = <LatLng>[];
    if (_mode == DeliveryMapDisplayMode.singleRoute) {
      final c = widget.session?.focusCustomer;
      if (c == null) return;
      pts.add(_myPosition ?? _indore);
      pts.add(c);
    } else if (_mode == DeliveryMapDisplayMode.multiOnWay) {
      if (_myPosition != null) pts.add(_myPosition!);
      for (final o in _onWayOrders) {
        final loc = o.customerLocation;
        if (loc != null) pts.add(LatLng(loc.lat, loc.lng));
      }
      if (pts.isEmpty) {
        _mapController.move(_indore, 14);
        return;
      }
    } else {
      return;
    }
    if (pts.length == 1) {
      _mapController.move(pts.first, 14);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(56),
      ),
    );
  }

  Future<void> _loadSingleRouteIfNeeded() async {
    if (_mode != DeliveryMapDisplayMode.singleRoute) return;
    final focus = widget.session?.focusCustomer;
    if (focus == null) return;
    final from = _myPosition ?? _indore;
    final id = ++_routeRequestId;
    try {
      final r = await OsrmRouteService.fetchRouteDetailed(from, focus);
      if (!mounted || id != _routeRequestId) return;
      if (r != null) {
        setState(() {
          _routePolyline = r.points;
          _routeKm = r.distanceMeters / 1000.0;
          _routeMinutes = r.durationSeconds / 60.0;
        });
      } else {
        setState(() {
          _routePolyline = [];
          _routeKm = null;
          _routeMinutes = null;
        });
      }
      if (!_navigationActive) {
        _fitSingleOrMulti();
      }
    } catch (_) {
      if (!mounted || id != _routeRequestId) return;
      setState(() {
        _routePolyline = [];
        _routeKm = null;
        _routeMinutes = null;
      });
      if (!_navigationActive) {
        _fitSingleOrMulti();
      }
    }
  }

  void _rebuildMarkers() {
    final markers = <Marker>[];

    if (_mode == DeliveryMapDisplayMode.singleRoute) {
      final focus = widget.session?.focusCustomer;
      final name = widget.session?.focusCustomerName ?? 'Customer';
      if (focus != null) {
        markers.add(
          Marker(
            point: focus,
            width: 180,
            height: 72,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _violet900.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.place_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ],
            ),
          ),
        );
      }
    } else if (_mode == DeliveryMapDisplayMode.multiOnWay) {
      for (final order in _onWayOrders) {
        final loc = order.customerLocation;
        if (loc == null) continue;
        final title = order.customerName ?? order.customerId;
        markers.add(
          Marker(
            point: LatLng(loc.lat, loc.lng),
            width: 44,
            height: 44,
            alignment: Alignment.bottomCenter,
            child: Tooltip(
              message: title,
              child: const Icon(
                Icons.place_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
          ),
        );
      }
    } else {
      for (final order in _orders) {
        final loc = order.customerLocation;
        if (loc == null) continue;
        final title = order.customerName ?? order.customerId;
        final snippet = order.customerAddress ?? '';
        markers.add(
          Marker(
            point: LatLng(loc.lat, loc.lng),
            width: 44,
            height: 44,
            alignment: Alignment.bottomCenter,
            child: Tooltip(
              message: snippet.isEmpty ? title : '$title\n$snippet',
              child: const Icon(
                Icons.place_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
          ),
        );
      }
    }

    if (_myPosition != null) {
      markers.add(
        Marker(
          point: _myPosition!,
          width: 44,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: Tooltip(
            message: 'My location',
            child: Icon(
              Icons.navigation_rounded,
              color: Colors.blue.shade700,
              size: 40,
            ),
          ),
        ),
      );
    }

    setState(() => _markers = markers);

    if (_mode != DeliveryMapDisplayMode.singleRoute) {
      setState(() {
        _routePolyline = [];
        _routeKm = null;
        _routeMinutes = null;
      });
    }
  }

  LatLng get _initialCenter => _myPosition ?? _indore;

  Future<void> _shareMyLocation() async {
    setState(() => _updatingLocation = true);
    try {
      final position = await LocationHelper.getCurrentPosition();
      if (position == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not get your location. Turn on GPS and allow location permission.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: LocationHelper.openAppLocationSettings,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (mounted) {
        await StaffLocationSync.pushFromPosition(position, _orders);
        setState(() {
          _myPosition = LatLng(position.latitude, position.longitude);
        });
        _rebuildMarkers();
        _loadSingleRouteIfNeeded();
        _mapController.move(_myPosition!, 14);
        AppSnackbar.success(context, 'Location shared successfully');
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  void _centerOnMyLocation() {
    final p = _myPosition;
    if (p == null) return;
    _mapController.move(p, 14);
  }

  int get _pillStopCount {
    if (_mode == DeliveryMapDisplayMode.multiOnWay) {
      return _onWayOrders.where((o) => o.customerLocation != null).length;
    }
    return _orders.where((o) => o.customerLocation != null).length;
  }

  /// True when we expect customer pins but the API has no coordinates for any of them.
  bool get _showNoCustomerLocationBanner {
    if (_loading) return false;
    if (_mode == DeliveryMapDisplayMode.singleRoute) return false;
    if (_mode == DeliveryMapDisplayMode.multiOnWay) {
      final ow = _onWayOrders;
      return ow.isNotEmpty && ow.every((o) => o.customerLocation == null);
    }
    return _orders.isNotEmpty &&
        _orders.every((o) => o.customerLocation == null);
  }

  Widget _buildNoCustomerLocationBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _violet50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _violet900.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: _violet600),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Customer did not share the location yet.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapBody = _buildMapBody();
    if (!widget.showAppBar) return mapBody;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _violet700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'My Route',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.center_focus_strong_outlined,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Center on my location',
            onPressed: _myPosition == null ? null : _centerOnMyLocation,
          ),
          IconButton(
            icon: _updatingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
            tooltip: 'Share my location',
            onPressed: _updatingLocation ? null : _shareMyLocation,
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: mapBody,
    );
  }

  Widget _buildMapBody() {
    if (_loading && _orders.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: _violet600, strokeWidth: 2.5),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 14,
          ),
          children: [
            OsmMapConstants.tileLayer(),
            if (_routePolyline.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePolyline,
                    strokeWidth: 4,
                    color: Colors.blue.withValues(alpha: 0.85),
                  ),
                ],
              ),
            MarkerLayer(markers: _markers),
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
        if (_orders.isEmpty &&
            _mode == DeliveryMapDisplayMode.overview &&
            !_loading)
          _buildEmptyMapOverlay(),
        if (_showNoCustomerLocationBanner)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _buildNoCustomerLocationBanner(),
          ),
        if (_pillStopCount > 0 && _mode != DeliveryMapDisplayMode.singleRoute)
          Positioned(
            top: _showNoCustomerLocationBanner ? 72 : 12,
            left: 16,
            right: 16,
            child: _buildStatsPill(),
          ),
        if (_mode == DeliveryMapDisplayMode.singleRoute &&
            widget.session?.focusCustomerName != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 88,
            child: _buildRouteInfoCard(),
          ),
        Positioned(bottom: 24, right: 16, child: _buildLocationFab()),
      ],
    );
  }

  Widget _buildRouteInfoCard() {
    final name = widget.session!.focusCustomerName!;
    final km = _routeKm;
    final min = _routeMinutes;
    final liveKm = _liveStraightKmToCustomer;
    final liveMin = _liveEtaMinutesRough;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _violet900.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            if (_navigationActive && liveKm != null && liveMin != null) ...[
              Text(
                '${liveKm.toStringAsFixed(1)} km to customer · ~$liveMin min',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Live straight-line · map follows you',
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
              if (km != null && min != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Road route ~${km.toStringAsFixed(1)} km · ~${min.ceil()} min',
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ] else if (km != null && min != null)
              Text(
                '${km.toStringAsFixed(1)} km · ~${min.ceil()} min',
                style: const TextStyle(fontSize: 13, color: _textSecondary),
              )
            else
              const Text(
                'Route unavailable',
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor:
                      _navigationActive ? const Color(0xFFB91C1C) : _violet700,
                ),
                onPressed: () {
                  if (_navigationActive) {
                    _stopLiveNavigation();
                  } else {
                    unawaited(_startLiveNavigation());
                  }
                },
                icon: Icon(
                  _navigationActive
                      ? Icons.stop_rounded
                      : Icons.navigation_rounded,
                  size: 20,
                ),
                label: Text(
                  _navigationActive
                      ? 'Stop live navigation'
                      : 'Start live navigation',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _violet900.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _mode == DeliveryMapDisplayMode.multiOnWay
                  ? '$_pillStopCount on the way'
                  : '$_pillStopCount stop${_pillStopCount == 1 ? '' : 's'} on route',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 14, color: _border),
            const SizedBox(width: 10),
            Icon(Icons.navigation_rounded, size: 14, color: _violet600),
            const SizedBox(width: 4),
            Text(
              'Live',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _violet600,
              ),
            ),
          ],
        ),
      );

  Widget _buildLocationFab() => GestureDetector(
        onTap: _updatingLocation ? null : _shareMyLocation,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _violet700,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _violet900.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _updatingLocation
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      );

  Widget _buildEmptyMapOverlay() => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _violet900.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _violet100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.map_outlined, size: 28, color: _violet600),
              ),
              const SizedBox(height: 14),
              const Text(
                'No deliveries on map',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Assigned deliveries will appear here',
                style: TextStyle(fontSize: 13, color: _textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
