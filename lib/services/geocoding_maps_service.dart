import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Reverse geocode using Google Geocoding API, then device geocoder fallback.
class GeocodingMapsService {
  static final GeocodingMapsService _instance = GeocodingMapsService._internal();
  factory GeocodingMapsService() => _instance;
  GeocodingMapsService._internal();

  Future<String> addressFromLatLng(double lat, double lng) async {
    if (lat == 0 && lng == 0) return 'Location not set';

    final google = await _googleReverseGeocode(lat, lng);
    if (google != null && google.isNotEmpty) return google;

    final device = await _deviceReverseGeocode(lat, lng);
    if (device != null && device.isNotEmpty) return device;

    return _coordLabel(lat, lng);
  }

  Future<String?> _googleReverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=${MapConstants.googleMapsApiKey}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      if (status == 'OK') {
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final addr = results.first['formatted_address']?.toString();
          if (addr != null && addr.isNotEmpty) return addr;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _deviceReverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ].whereType<String>().where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.join(', ');
    } catch (_) {}
    return null;
  }

  String _coordLabel(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
