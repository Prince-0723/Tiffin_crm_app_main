import 'package:latlong2/latlong.dart';

enum DeliveryMapDisplayMode { overview, singleRoute, multiOnWay }

/// How the embedded delivery map should render (passed from [DeliveryDashboardScreen]).
final class DeliveryMapSession {
  const DeliveryMapSession._({
    required this.mode,
    this.focusCustomer,
    this.focusCustomerName,
  });

  const DeliveryMapSession.overview()
      : this._(mode: DeliveryMapDisplayMode.overview);

  const DeliveryMapSession.multiOnWay()
      : this._(mode: DeliveryMapDisplayMode.multiOnWay);

  const DeliveryMapSession.singleRoute({
    required LatLng customerPoint,
    required String customerName,
  }) : this._(
          mode: DeliveryMapDisplayMode.singleRoute,
          focusCustomer: customerPoint,
          focusCustomerName: customerName,
        );

  final DeliveryMapDisplayMode mode;
  final LatLng? focusCustomer;
  final String? focusCustomerName;
}
