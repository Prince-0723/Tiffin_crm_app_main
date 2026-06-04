import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../config/app_config.dart';
import '../storage/secure_storage.dart';

/// Payload from server `location_update` (delivery staff live position).
class DeliveryLocationUpdate {
  const DeliveryLocationUpdate({
    required this.lat,
    required this.lng,
    this.orderId,
    this.staffId,
    this.customerIdForOrder,
  });

  final double lat;
  final double lng;
  final String? orderId;
  final String? staffId;
  final String? customerIdForOrder;

  static DeliveryLocationUpdate? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final lat = m['lat'];
    final lng = m['lng'];
    if (lat is! num || lng is! num) return null;
    return DeliveryLocationUpdate(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      orderId: m['orderId']?.toString(),
      staffId: m['staffId']?.toString(),
      customerIdForOrder: m['customerIdForOrder']?.toString(),
    );
  }
}

/// Socket.IO `/delivery` namespace — matches [server/socket/delivery.socket.js].
final class DeliveryTrackingSocket {
  DeliveryTrackingSocket._();
  static final DeliveryTrackingSocket instance = DeliveryTrackingSocket._();

  sio.Socket? _socket;
  final _updates = StreamController<DeliveryLocationUpdate>.broadcast();
  final _dailyOrdersRefresh = StreamController<void>.broadcast();
  Future<void>? _connecting;

  Stream<DeliveryLocationUpdate> get updates => _updates.stream;

  /// Fired when vendor-facing daily order lists should refetch (e.g. customer cancelled a delivery).
  Stream<void> get dailyOrdersRefresh => _dailyOrdersRefresh.stream;

  bool get isConnected => _socket?.connected == true;

  /// Connect (or refresh token) to `/delivery`. Safe to call repeatedly.
  Future<void> ensureConnected() async {
    if (_socket?.connected == true) return;
    if (_connecting != null) {
      await _connecting;
      return;
    }
    _connecting = _openSocket();
    try {
      await _connecting;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _openSocket() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    if (_socket?.connected == true) return;

    _socket?.dispose();
    _socket = null;

    final url = '${AppConfig.socketOrigin}/delivery';
    // Web: try polling first — many hosts/proxies block or flake on WS upgrade.
    final transports =
        kIsWeb ? <String>['polling', 'websocket'] : <String>['websocket', 'polling'];
    final opts = sio.OptionBuilder()
        .setTransports(transports)
        .setAuth({'token': token})
        .enableReconnection()
        .setReconnectionAttempts(8)
        .setReconnectionDelay(2000)
        .setTimeout(20000)
        .build();

    final socket = sio.io(url, opts);
    _socket = socket;

    socket.on('location_update', (data) {
      final u = DeliveryLocationUpdate.tryParse(data);
      if (u != null && !_updates.isClosed) _updates.add(u);
    });

    socket.on('location_error', (data) {
      if (kDebugMode) {
        debugPrint('[DeliverySocket] location_error: $data');
      }
    });

    socket.on('daily_orders_changed', (_) {
      if (!_dailyOrdersRefresh.isClosed) _dailyOrdersRefresh.add(null);
    });

    socket.onConnect((_) {
      if (kDebugMode) debugPrint('[DeliverySocket] connected');
    });
    socket.onConnectError((e) {
      if (kDebugMode) debugPrint('[DeliverySocket] connect_error: $e');
    });
    socket.onDisconnect((_) {
      if (kDebugMode) debugPrint('[DeliverySocket] disconnected');
    });
  }

  void emitStaffLocation({
    required double lat,
    required double lng,
    String? orderId,
    String? customerIdForOrder,
  }) {
    if (_socket?.connected != true) return;
    _socket!.emit('location_update', {
      'lat': lat,
      'lng': lng,
      if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
      if (customerIdForOrder != null && customerIdForOrder.isNotEmpty)
        'customerIdForOrder': customerIdForOrder,
    });
  }

  /// Call after token refresh so the next handshake uses the new JWT.
  Future<void> reconnectWithFreshToken() async {
    disconnect();
    await ensureConnected();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
