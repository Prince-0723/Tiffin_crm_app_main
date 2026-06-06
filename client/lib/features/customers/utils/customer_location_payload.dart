/// Builds the customer location body for POST/PUT `/customers` APIs.
Map<String, dynamic> buildCustomerLocationUpdateBody({
  required double lat,
  required double lng,
  required String address,
}) {
  return {
    'address': address.trim(),
    'location': {
      'type': 'Point',
      'coordinates': [lng, lat],
    },
  };
}

bool hasValidCustomerMapPin(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  return lat != 0 || lng != 0;
}
