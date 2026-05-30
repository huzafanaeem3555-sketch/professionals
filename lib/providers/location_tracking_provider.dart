import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/geolocation_service.dart';

class LocationTrackingProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GeolocationService _geoService = GeolocationService();

  bool _isTracking = false;
  String? _activeBookingId;
  Position? _lastPosition;
  String? _error;
  Function? _stopTrackingCallback;

  bool get isTracking => _isTracking;
  String? get activeBookingId => _activeBookingId;
  Position? get lastPosition => _lastPosition;
  String? get error => _error;

  /// Start tracking location for a professional during an active job
  /// Updates location to backend every 10 seconds
  Future<bool> startTracking(String bookingId) async {
    try {
      _isTracking = true;
      _activeBookingId = bookingId;
      _error = null;
      notifyListeners();

      // Check location permission
      final hasPermission = await _geoService.requestLocationPermission();
      if (!hasPermission) {
        _error = 'Location permission denied';
        _isTracking = false;
        notifyListeners();
        return false;
      }

      // Start tracking with 10-second updates
      _stopTrackingCallback = _geoService.startLocationTracking(
        onLocationUpdate: (position) async {
          _lastPosition = position;
          
          // Get address for location
          final address = await _geoService.getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );

          // Update backend with new location
          try {
            await _apiService.updateProfessionalLocation(
              lat: position.latitude,
              lng: position.longitude,
              address: address,
            );
          } catch (e) {
            if (kDebugMode) print('Error updating location on backend: $e');
          }

          notifyListeners();
        },
        updateInterval: const Duration(seconds: 10),
      );

      return true;
    } catch (e) {
      _error = 'Failed to start tracking: $e';
      _isTracking = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop tracking location
  void stopTracking() {
    if (_stopTrackingCallback != null) {
      _stopTrackingCallback!();
    }
    _isTracking = false;
    _activeBookingId = null;
    _lastPosition = null;
    _error = null;
    notifyListeners();
  }

  /// Get current location without tracking
  Future<Position?> getCurrentLocation() async {
    try {
      final position = await _geoService.getCurrentLocation();
      _lastPosition = position;
      notifyListeners();
      return position;
    } catch (e) {
      _error = 'Failed to get location: $e';
      notifyListeners();
      return null;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await _geoService.isLocationServiceEnabled();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await _geoService.openLocationSettings();
  }


  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

