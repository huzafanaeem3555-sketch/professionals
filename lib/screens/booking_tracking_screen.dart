import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/geolocation_model.dart';
import '../models/booking_model.dart';
import '../utils/constants.dart';

class BookingTrackingScreen extends StatefulWidget {
  final String bookingId;
  final BookingModel? initialBooking;

  const BookingTrackingScreen({
    super.key,
    required this.bookingId,
    this.initialBooking,
  });

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  GoogleMapController? mapController;
  ProfessionalLocationModel? professionalLocation;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _updateTimer;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};


  StreamSubscription? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _initRealtimeTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _updateTimer?.cancel();
    try {
      mapController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  double _parseLatitude(Map<String, dynamic> userData) {
    if (userData['location'] != null && userData['location'] is Map) {
      final loc = Map<dynamic, dynamic>.from(userData['location'] as Map);
      if (loc['lat'] != null) {
        return (loc['lat'] as num).toDouble();
      }
    }
    if (userData['lat'] != null) {
      return (userData['lat'] as num).toDouble();
    }
    return 0.0;
  }

  double _parseLongitude(Map<String, dynamic> userData) {
    if (userData['location'] != null && userData['location'] is Map) {
      final loc = Map<dynamic, dynamic>.from(userData['location'] as Map);
      if (loc['lng'] != null) {
        return (loc['lng'] as num).toDouble();
      }
    }
    if (userData['lng'] != null) {
      return (userData['lng'] as num).toDouble();
    }
    return 0.0;
  }

  Future<void> _initRealtimeTracking() async {
    await _loadProfessionalLocation();
    if (professionalLocation != null && mounted) {
      final proUid = professionalLocation!.uid;
      _locationSubscription?.cancel();
      _locationSubscription = FirebaseDatabase.instance
          .ref('users/$proUid')
          .onValue
          .listen((event) {
        if (!mounted) return;
        if (event.snapshot.exists) {
          final userData = Map<String, dynamic>.from(event.snapshot.value as Map);
          final lat = _parseLatitude(userData);
          final lng = _parseLongitude(userData);
          if (lat != 0.0 && lng != 0.0 && professionalLocation != null) {
            setState(() {
              professionalLocation = ProfessionalLocationModel(
                uid: professionalLocation!.uid,
                displayName: professionalLocation!.displayName,
                photoURL: professionalLocation!.photoURL,
                lat: lat,
                lng: lng,
                address: userData['address'] ?? professionalLocation!.address,
                phoneNumber: userData['phoneNumber'] ?? professionalLocation!.phoneNumber,
                rating: professionalLocation!.rating,
                totalRatings: professionalLocation!.totalRatings,
                serviceType: professionalLocation!.serviceType,
              );
              _updateMarkers();
            });
          }
        }
      });
    }
  }

  Future<void> _loadProfessionalLocation() async {
    try {
      final bookingSnap = await FirebaseDatabase.instance
          .ref('bookings/${widget.bookingId}')
          .get()
          .timeout(const Duration(seconds: 5));
          
      if (!bookingSnap.exists) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Booking not found';
          });
        }
        return;
      }
      
      final bookingData = Map<String, dynamic>.from(bookingSnap.value as Map);
      final proUid = bookingData['professionalId'] as String;
      
      final userSnap = await FirebaseDatabase.instance
          .ref('users/$proUid')
          .get()
          .timeout(const Duration(seconds: 5));
          
      final profSnap = await FirebaseDatabase.instance
          .ref('professionals/$proUid')
          .get()
          .timeout(const Duration(seconds: 5));
          
      if (!userSnap.exists) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Professional details not found';
          });
        }
        return;
      }
      
      final userData = Map<String, dynamic>.from(userSnap.value as Map);
      final profData = profSnap.exists 
          ? Map<String, dynamic>.from(profSnap.value as Map) 
          : <String, dynamic>{};
          
      final merged = {
        'uid': proUid,
        'displayName': userData['displayName'] ?? '',
        'photoURL': userData['photoURL'] ?? '',
        'phoneNumber': userData['phoneNumber'] ?? '',
        'rating': userData['rating'] ?? 5.0,
        'totalRatings': userData['totalRatings'] ?? 0,
        'address': userData['address'] ?? profData['address'] ?? '',
        'lat': _parseLatitude(userData),
        'lng': _parseLongitude(userData),
        'serviceType': bookingData['serviceType'] ?? '',
      };

      if (mounted) {
        setState(() {
          professionalLocation = ProfessionalLocationModel.fromMap(merged);
          _isLoading = false;
          _errorMessage = null;
          _updateMarkers();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  void _updateMarkers() {
    if (professionalLocation == null) return;

    _markers.clear();

    // Add professional marker
    _markers.add(
      Marker(
        markerId: const MarkerId('professional'),
        position: LatLng(professionalLocation!.lat, professionalLocation!.lng),
        infoWindow: InfoWindow(
          title: professionalLocation!.displayName,
          snippet: professionalLocation!.phoneNumber,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (professionalLocation != null) {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(professionalLocation!.lat, professionalLocation!.lng),
            zoom: 16,
          ),
        ),
      );
    }
  }

  void _centerOnProfessional() {
    if (professionalLocation != null) {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(professionalLocation!.lat, professionalLocation!.lng),
            zoom: 16,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Professional Location'),
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _errorMessage != null
              ? _buildErrorView()
              : _buildMapView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading professional location...'),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unable to load location',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProfessionalLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    if (professionalLocation == null) {
      return _buildErrorView();
    }

    return Stack(
      children: [
        // Google Map
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: LatLng(professionalLocation!.lat, professionalLocation!.lng),
            zoom: 16,
          ),
          markers: _markers,
          circles: _circles,
          myLocationEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: true,
        ),

        // Info Card at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Professional Photo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          professionalLocation!.photoURL,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.person),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Professional Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              professionalLocation!.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 14, color: AppColors.star),
                                const SizedBox(width: 4),
                                Text(
                                  '${professionalLocation!.rating.toStringAsFixed(1)} (${professionalLocation!.totalRatings} reviews)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              professionalLocation!.serviceType,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Center button
                      FloatingActionButton(
                        mini: true,
                        onPressed: _centerOnProfessional,
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.location_on),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Container(
                    height: 1,
                    color: AppColors.divider,
                  ),
                  const SizedBox(height: 12),

                  // Location Info
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          professionalLocation!.address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Phone Info - Highlighted
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            professionalLocation!.phoneNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Show snackbar on tap
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Phone: ${professionalLocation!.phoneNumber}',
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy,
                              size: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Distance if available
                  if (professionalLocation!.distance != null)
                    Text(
                      '📍 Distance: ${professionalLocation!.distance!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

