import 'package:flutter/material.dart';
import '../utils/snackbar_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/geolocation_model.dart';
import '../models/booking_model.dart';
import '../models/professional_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/contact_actions.dart';
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
  final _api = ApiService();
  GoogleMapController? mapController;
  ProfessionalLocationModel? professionalLocation;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _customerLocation;
  List<ProfessionalModel> _backupProfessionals = [];
  bool _isLoading = true;
  bool _loadingBackup = false;
  bool _backupRecommended = false;
  double? _distanceKm;
  int? _etaMinutes;
  String? _errorMessage;
  Timer? _updateTimer;
  Timer? _etaTimer;
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
    _etaTimer?.cancel();
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

  Map<String, dynamic>? _readLocation(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final lat = (map['lat'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble();
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        return {
          'lat': lat,
          'lng': lng,
          'address': map['address']?.toString() ?? '',
        };
      }
    }
    return null;
  }

  Future<void> _refreshArrivalGuarantee() async {
    final pro = professionalLocation;
    final customerLoc = _customerLocation;
    if (!mounted || pro == null || customerLoc == null) {
      return;
    }

    final customerLat = (customerLoc['lat'] as num?)?.toDouble();
    final customerLng = (customerLoc['lng'] as num?)?.toDouble();
    if (customerLat == null || customerLng == null) return;

    final distance = LocationService.haversineKm(
      customerLat,
      customerLng,
      pro.lat,
      pro.lng,
    );
    final eta = (distance * 2.5 + 5).round().clamp(5, 180);
    final shouldSuggestBackup = eta > 25 || pro.lat == 0 || pro.lng == 0;

    if (!mounted) return;
    setState(() {
      _distanceKm = double.parse(distance.toStringAsFixed(1));
      _etaMinutes = eta;
      _backupRecommended = shouldSuggestBackup;
    });

    if (shouldSuggestBackup) {
      await _loadBackupProfessionals();
    }
  }

  Future<void> _loadBackupProfessionals() async {
    final booking = _bookingData;
    final customerLoc = _customerLocation;
    final pro = professionalLocation;
    if (booking == null ||
        customerLoc == null ||
        pro == null ||
        _loadingBackup) {
      return;
    }

    final customerLat = (customerLoc['lat'] as num?)?.toDouble();
    final customerLng = (customerLoc['lng'] as num?)?.toDouble();
    if (customerLat == null || customerLng == null) return;

    setState(() => _loadingBackup = true);
    try {
      final res = await _api.getNearbyProfessionalsByLocation(
        lat: customerLat,
        lng: customerLng,
        radiusKm: 20,
        serviceType: booking['serviceType']?.toString(),
      );
      final list = <ProfessionalModel>[];
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final rawList = data is Map && data['professionals'] is List
            ? List.from(data['professionals'] as List)
            : data is List
                ? List.from(data)
                : <dynamic>[];
        for (final item in rawList) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          if ((map['uid']?.toString() ?? '') == pro.uid) continue;
          list.add(ProfessionalModel.fromMap(map));
        }
        list.sort((a, b) {
          final da = a.distance ?? 999;
          final db = b.distance ?? 999;
          final diff = da.compareTo(db);
          if (diff != 0) return diff;
          return b.rating.compareTo(a.rating);
        });
      }
      if (mounted) {
        setState(() => _backupProfessionals = list.take(3).toList());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _backupProfessionals = []);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingBackup = false);
      }
    }
  }

  Future<void> _initRealtimeTracking() async {
    await _loadProfessionalLocation();
    if (professionalLocation != null && mounted) {
      _etaTimer?.cancel();
      _etaTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) {
          _refreshArrivalGuarantee();
        }
      });
      final proUid = professionalLocation!.uid;
      _locationSubscription?.cancel();
      _locationSubscription = FirebaseDatabase.instance
          .ref('users/$proUid')
          .onValue
          .listen((event) {
        if (!mounted) return;
        if (event.snapshot.exists) {
          final userData =
              Map<String, dynamic>.from(event.snapshot.value as Map);
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
                phoneNumber: userData['phoneNumber'] ??
                    professionalLocation!.phoneNumber,
                rating: professionalLocation!.rating,
                totalRatings: professionalLocation!.totalRatings,
                serviceType: professionalLocation!.serviceType,
              );
              _updateMarkers();
              _refreshArrivalGuarantee();
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
      _bookingData = bookingData;
      _customerLocation = _readLocation(bookingData['customerLocation']) ??
          _readLocation(bookingData['location']);
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
        await _refreshArrivalGuarantee();
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
            target:
                LatLng(professionalLocation!.lat, professionalLocation!.lng),
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
            target:
                LatLng(professionalLocation!.lat, professionalLocation!.lng),
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
            target:
                LatLng(professionalLocation!.lat, professionalLocation!.lng),
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
                            showTimedSnackBar(
                              context,
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

                  _buildArrivalGuaranteeCard(),
                  const SizedBox(height: 12),

                  // Distance if available
                  if (professionalLocation!.distance != null)
                    Text(
                      'Distance: ${professionalLocation!.distance!.toStringAsFixed(1)} km',
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

  Widget _buildArrivalGuaranteeCard() {
    final eta = _etaMinutes;
    final distance = _distanceKm;
    final badgeColor =
        _backupRecommended ? AppColors.warning : AppColors.success;
    final badgeText = _backupRecommended ? 'Backup recommended' : 'On time';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: badgeColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Arrival Guarantee',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            distance != null
                ? 'Live distance: ${distance.toStringAsFixed(1)} km'
                : 'Live distance: unavailable',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            eta != null
                ? 'Estimated arrival: about $eta minutes'
                : 'Estimated arrival: calculating...',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadingBackup ? null : _loadBackupProfessionals,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Suggest Backup'),
                ),
              ),
            ],
          ),
          if (_loadingBackup) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (_backupProfessionals.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Best nearby alternatives',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._backupProfessionals.map(
              (pro) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BackupProfessionalTile(
                  professional: pro,
                  onCall: () => launchContactUri(contactUriFor(
                    method: ContactMethod.call,
                    phoneNumber: pro.phone,
                  )),
                  onWhatsApp: () => launchContactUri(contactUriFor(
                    method: ContactMethod.whatsapp,
                    phoneNumber: pro.phone,
                    message:
                        'Hello, I found your profile on HirePro and need a backup professional for ${pro.serviceText}.',
                  )),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupProfessionalTile extends StatelessWidget {
  final ProfessionalModel professional;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _BackupProfessionalTile({
    required this.professional,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            professional.name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            professional.serviceText,
            style: const TextStyle(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            professional.distance != null
                ? '${professional.distance!.toStringAsFixed(1)} km away'
                : 'Nearby professional',
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCall,
                  child: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
