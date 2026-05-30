import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'geocoding_maps_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastPosition;
  final GeocodingMapsService _geocoding = GeocodingMapsService();

  /// Request permissions and return current GPS position (with retries).
  Future<Position> getCurrentPosition({int maxAttempts = 3}) async {
    await _ensurePermission();

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final accuracy = attempt < maxAttempts
            ? LocationAccuracy.high
            : LocationAccuracy.medium;
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
          timeLimit: Duration(seconds: attempt == 1 ? 12 : 18),
        );
        _lastPosition = position;
        return position;
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      _lastPosition = lastKnown;
      return lastKnown;
    }

    throw Exception(_friendlyGpsError(lastError));
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'GPS is turned off. Please enable location services in your device settings.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission denied. Allow location access so we can find nearby professionals.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission blocked. Open app settings and enable location for Service Connect.',
      );
    }
  }

  String _friendlyGpsError(Object? error) {
    final msg = error?.toString().toLowerCase() ?? '';
    if (msg.contains('timeout')) {
      return 'GPS timed out. Move outdoors or near a window and tap refresh.';
    }
    if (msg.contains('permission')) {
      return 'Location permission is required. Enable it in app settings.';
    }
    return 'Could not get GPS fix. Tap refresh or pick your location on the map.';
  }

  /// Human-readable address (Google Geocoding API, then device geocoder).
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    if (lat == 0 && lng == 0) return 'Location not set';
    return _geocoding.addressFromLatLng(lat, lng);
  }

  Future<bool> isLocationAvailable() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Position? get lastPosition => _lastPosition;

  Future<Position> positionFromLatLng(double lat, double lng) async {
    final position = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    _lastPosition = position;
    return position;
  }

  double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    return haversineKm(lat1, lon1, lat2, lon2);
  }

  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
