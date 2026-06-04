import 'package:geolocator/geolocator.dart';

import '../socket/delivery_tracking_socket.dart';
import '../../features/delivery/data/delivery_api.dart';
import '../../features/orders/models/order_model.dart';

/// Persists staff GPS via REST and broadcasts live position on Socket.IO.
abstract final class StaffLocationSync {
  static OrderModel? primaryActiveDelivery(List<OrderModel> orders) {
    for (final o in orders) {
      final s = o.status.toLowerCase();
      if ((s == 'out_for_delivery' || s == 'in_transit') &&
          o.customerLocation != null) {
        return o;
      }
    }
    return null;
  }

  static Future<void> pushFromPosition(
    Position p,
    List<OrderModel> orders,
  ) async {
    await DeliveryApi.updateMe({
      'location': {
        'type': 'Point',
        'coordinates': [p.longitude, p.latitude],
      },
    });
    await DeliveryTrackingSocket.instance.ensureConnected();
    final primary = primaryActiveDelivery(orders);
    DeliveryTrackingSocket.instance.emitStaffLocation(
      lat: p.latitude,
      lng: p.longitude,
      orderId: primary?.id,
      customerIdForOrder: primary?.customerId,
    );
  }
}
