import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class GeolocationService {
  static final GeolocationService _instance = GeolocationService._internal();
  
  factory GeolocationService() => _instance;
  GeolocationService._internal();

  StreamSubscription<Position>? _positionStream;
  
  /// Check and request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied) {
        return false;
      } else if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, we cannot request them again.
        await Geolocator.openLocationSettings();
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) print('Permission error: $e');
      return false;
    }
  }

  /// Get current location as Position
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 15));
      
      return position;
    } catch (e) {
      if (kDebugMode) print('Error getting current location: $e');
      return null;
    }
  }

  /// Get address from coordinates using reverse geocoding
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}';
        return address.replaceAll(RegExp(r',\s+'), ', ').trim();
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error reverse geocoding: $e');
      return null;
    }
  }

  /// Get coordinates from address using geocoding
  Future<List<Location>?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      return locations.isNotEmpty ? locations : null;
    } catch (e) {
      if (kDebugMode) print('Error geocoding address: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // Convert to km
  }

  /// Start listening to location updates (for real-time tracking)
  /// Calls onLocationUpdate with every new position
  /// Returns a function to stop listening
  Function startLocationTracking({
    required Function(Position position) onLocationUpdate,
    Duration updateInterval = const Duration(seconds: 10),
    double distanceFilter = 0,
  }) {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter.toInt(),
        timeLimit: updateInterval,
      ),
    ).listen(
      (Position position) {
        onLocationUpdate(position);
      },
      onError: (error) {
        if (kDebugMode) print('Location tracking error: $error');
      },
    );

    // Return function to stop tracking
    return () {
      _positionStream?.cancel();
      _positionStream = null;
    };
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}

