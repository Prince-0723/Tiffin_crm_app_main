import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class LocationHelper {
  /// Resolves permission (including [deniedForever]) before fixing position.
  static Future<Position?> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 25),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> openAppLocationSettings() =>
      Geolocator.openAppSettings();

  /// Open OpenStreetMap centered on [lat], [lng] in the device browser.
  static Future<void> openInMaps(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Google Maps at [lat], [lng] (browser or Maps app).
  static Future<void> openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Approximate distance in km (Haversine).
  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }
}
