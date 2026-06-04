import 'dart:convert';

/// Reads unverified JWT payload (claims only). Used for customerId on customer role.
Map<String, dynamic> readJwtPayload(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return {};
  var payload = parts[1];
  final pad = payload.length % 4;
  if (pad == 2) {
    payload += '==';
  } else if (pad == 3) {
    payload += '=';
  }
  try {
    final bytes = base64Url.decode(payload);
    final map = jsonDecode(utf8.decode(bytes));
    if (map is Map<String, dynamic>) return map;
    if (map is Map) return Map<String, dynamic>.from(map);
  } catch (_) {}
  return {};
}
