import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/maps/osm_map_constants.dart';
import '../../../../core/routing/nominatim_geocode_service.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/location_helper.dart';

/// Result from [showCustomerLocationPickSheet].
class CustomerLocationPickResult {
  const CustomerLocationPickResult({
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String address;
  final double lat;
  final double lng;
}

/// Map-based location picker (OSM tiles + Nominatim). Not Google Maps SDK.
Future<CustomerLocationPickResult?> showCustomerLocationPickSheet(
  BuildContext context, {
  LatLng? initialPosition,
  String? initialAddress,
}) {
  final mq = MediaQuery.sizeOf(context);
  final h = mq.height;
  return showModalBottomSheet<CustomerLocationPickResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black54,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return LayoutBuilder(
        builder: (ctx, constraints) {
          double sheetW = constraints.maxWidth;
          if (!sheetW.isFinite || sheetW <= 0) {
            sheetW = MediaQuery.sizeOf(ctx).width;
          }
          if (!sheetW.isFinite || sheetW <= 0) {
            sheetW = 560;
          }

          final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: sheetW,
                  height: h * 0.92,
                  child: _CustomerLocationPickBody(
                    initialPosition: initialPosition,
                    initialAddress: initialAddress,
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _CustomerLocationPickBody extends StatefulWidget {
  const _CustomerLocationPickBody({
    this.initialPosition,
    this.initialAddress,
  });

  final LatLng? initialPosition;
  final String? initialAddress;

  @override
  State<_CustomerLocationPickBody> createState() =>
      _CustomerLocationPickBodyState();
}

class _CustomerLocationPickBodyState extends State<_CustomerLocationPickBody> {
  static const LatLng _fallbackCenter = LatLng(22.7196, 75.8577);

  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  LatLng? _pin;
  String _address = '';
  bool _reverseBusy = false;
  bool _gpsBusy = false;
  bool _searchBusy = false;
  String? _searchError;
  Timer? _debounce;
  List<NominatimPlaceHit> _suggestions = [];

  @override
  void initState() {
    super.initState();
    final init = widget.initialPosition;
    if (init != null &&
        (init.latitude != 0 || init.longitude != 0)) {
      _pin = init;
      final a = widget.initialAddress?.trim();
      _address = (a != null && a.isNotEmpty) ? a : '';
      if (_address.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_reverseAndSetAddress(init, moveCamera: false));
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  LatLng get _mapCenter => _pin ?? widget.initialPosition ?? _fallbackCenter;

  double get _mapZoom => (_pin != null || widget.initialPosition != null) ? 16.0 : 5.0;

  Future<void> _reverseAndSetAddress(LatLng p, {required bool moveCamera}) async {
    setState(() {
      _reverseBusy = true;
      _searchError = null;
    });
    try {
      final name = await NominatimGeocodeService.reverseDisplayName(p);
      if (!mounted) return;
      final trimmed = name?.trim() ?? '';
      setState(() {
        _address = trimmed.isNotEmpty
            ? trimmed
            : '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
        _reverseBusy = false;
      });
      if (moveCamera) {
        _mapController.move(p, 16);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _reverseBusy = false);
      AppSnackbar.error(context, e.message ?? 'Could not resolve address');
    } catch (e) {
      if (!mounted) return;
      setState(() => _reverseBusy = false);
      AppSnackbar.error(context, '$e');
    }
  }

  void _onSearchChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.length < 3) {
      setState(() {
        _suggestions = [];
        _searchError = null;
        _searchBusy = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _searchBusy = true;
      _searchError = null;
    });
    try {
      final hits = await NominatimGeocodeService.searchPlaces(q, limit: 6);
      if (!mounted) return;
      setState(() {
        _suggestions = hits;
        _searchBusy = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _searchBusy = false;
        _suggestions = [];
        _searchError = e.message ?? 'Search failed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchBusy = false;
        _suggestions = [];
        _searchError = '$e';
      });
    }
  }

  void _selectHit(NominatimPlaceHit hit) {
    FocusScope.of(context).unfocus();
    setState(() {
      _pin = hit.latLng;
      _address = hit.displayName;
      _suggestions = [];
      _searchCtrl.clear();
    });
    _mapController.move(hit.latLng, 16);
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    FocusScope.of(context).unfocus();
    setState(() => _pin = point);
    await _reverseAndSetAddress(point, moveCamera: false);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gpsBusy = true);
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (!mounted) return;
      if (pos == null) {
        AppSnackbar.error(
          context,
          'Could not get GPS location. Enable location permission and try again.',
        );
        return;
      }
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = point);
      await _reverseAndSetAddress(point, moveCamera: true);
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  void _submit() {
    final p = _pin;
    final addr = _address.trim();
    if (p == null) {
      AppSnackbar.error(context, 'Tap the map or search to pick a location.');
      return;
    }
    if (addr.isEmpty) {
      AppSnackbar.error(context, 'Address is missing. Wait for lookup or search again.');
      return;
    }
    Navigator.of(context).pop(CustomerLocationPickResult(
      address: addr,
      lat: p.latitude,
      lng: p.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pin = _pin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  'Customer location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                onPressed: _reverseBusy ? null : _submit,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search place or address',
                  prefixIcon: _searchBusy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _searchError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (_suggestions.isNotEmpty)
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(10),
                  color: theme.colorScheme.surface,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (ctx, i) {
                        final h = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 20),
                          title: Text(
                            h.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _selectHit(h),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: _mapZoom,
                  onTap: _onMapTap,
                ),
                children: [
                  OsmMapConstants.tileLayer(),
                  if (pin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: pin,
                          width: 48,
                          height: 48,
                          alignment: Alignment.bottomCenter,
                          child: Icon(
                            Icons.location_on_rounded,
                            color: theme.colorScheme.primary,
                            size: 44,
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
              if (_reverseBusy || _gpsBusy)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 12,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Fetching address…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  heroTag: 'customer_location_gps',
                  onPressed: (_reverseBusy || _gpsBusy) ? null : _useCurrentLocation,
                  tooltip: 'Use current location',
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected address',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _address.isEmpty
                    ? 'Tap the map or choose a search result.'
                    : _address,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (pin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${pin.latitude.toStringAsFixed(6)}, ${pin.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
