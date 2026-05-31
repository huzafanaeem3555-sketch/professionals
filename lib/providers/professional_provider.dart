import 'package:flutter/foundation.dart';
import '../models/professional_model.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class ProfessionalProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final ApiService _api = ApiService();
  final LocationService _locationService = LocationService();

  List<ProfessionalModel> _allProfessionals = [];
  ProfessionalModel? _selectedProfessional;
  bool _isLoading = false;
  String? _error;
  String? _selectedCategory;

  List<ProfessionalModel> get nearbyProfessionals {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      return _allProfessionals;
    }
    final cat = _selectedCategory!.toLowerCase();
    return _allProfessionals.where((p) {
      return p.allServices.any((s) {
        final label = ServiceLabels.labelFor(s)['name']!.toLowerCase();
        return s.toLowerCase().contains(cat) || label.contains(cat);
      });
    }).toList();
  }

  ProfessionalModel? get selectedProfessional => _selectedProfessional;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;

  /// Load ALL professionals from backend or Firebase RTDB
  Future<void> loadNearby({
    String? serviceType,
    double? fallbackLat,
    double? fallbackLng,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      List<dynamic> professionals = [];
      var pos = _locationService.lastPosition;
      try {
        pos ??= await _locationService.getCurrentPosition();
      } catch (_) {}

      final canViewFemaleProfessionals = await _canViewFemaleProfessionals();
      final viewerGender =
          (await StorageService.getGender() ?? 'male').toLowerCase();

      if (pos == null &&
          fallbackLat != null &&
          fallbackLng != null &&
          (fallbackLat != 0 || fallbackLng != 0)) {
        pos = await _locationService.positionFromLatLng(
          fallbackLat,
          fallbackLng,
        );
      }

      if (pos != null) {
        // Prefer /professionals/nearby — includes visible phone numbers
        try {
          final resp = await _api.getNearbyProfessionals(
            lat: pos.latitude,
            lng: pos.longitude,
            radius: 20,
            serviceType: serviceType,
          );
          if (resp['success'] == true && resp['data'] != null) {
            final data = resp['data'];
            if (data is List) {
              professionals = data;
            } else if (data is Map && data['professionals'] is List) {
              professionals = data['professionals'];
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Nearby professionals API failed: $e');
        }

        if (professionals.isEmpty) {
          try {
            final resp = await _api.getNearbyProfessionalsByLocation(
              lat: pos.latitude,
              lng: pos.longitude,
              radiusKm: 20,
              serviceType: serviceType,
            );
            if (resp['success'] == true && resp['data'] != null) {
              final data = resp['data'];
              if (data is List) {
                professionals = data;
              } else if (data is Map && data['professionals'] is List) {
                professionals = data['professionals'];
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Geolocation API failed: $e');
          }
        }
      }

      // Fallback to Firebase if API returned nothing
      if (professionals.isEmpty) {
        professionals = await _firebase.getAllProfessionals();
      }

      final models = <ProfessionalModel>[];
      for (final raw in professionals) {
        final p = Map<String, dynamic>.from(raw as Map);
        final location = p['location'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(p['location'] as Map)
            : (p['location'] is Map
                ? Map<String, dynamic>.from(p['location'] as Map)
                : <String, dynamic>{});

        final lat = (p['lat'] ?? location['lat'] ?? 0) as num;
        final lng = (p['lng'] ?? location['lng'] ?? 0) as num;

        if (!_isProfessionalVisible(
          p,
          canViewFemaleProfessionals: canViewFemaleProfessionals,
          viewerGender: viewerGender,
        )) {
          continue;
        }

        if (pos != null && (lat.toDouble() != 0 || lng.toDouble() != 0)) {
          final distance = _locationService.distanceBetween(
            pos.latitude,
            pos.longitude,
            lat.toDouble(),
            lng.toDouble(),
          );
          p['distance'] = distance;
          if (distance <= 20) {
            models.add(ProfessionalModel.fromMap(p));
          }
        } else {
          models.add(ProfessionalModel.fromMap(p));
        }
      }

      models.sort((a, b) {
        final ratingDiff = b.rating.compareTo(a.rating);
        if (ratingDiff != 0) return ratingDiff;
        final ratingCountDiff = b.totalRatings.compareTo(a.totalRatings);
        if (ratingCountDiff != 0) return ratingCountDiff;
        final jobDiff = b.completedJobs.compareTo(a.completedJobs);
        if (jobDiff != 0) return jobDiff;
        if (a.distance == null && b.distance == null) return 0;
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

      _allProfessionals = models;
      if (serviceType != null) _selectedCategory = serviceType;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load professionals: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _canViewFemaleProfessionals() async {
    final role = await StorageService.getRole() ?? 'customer';
    if (role == 'admin') return true;

    final gender = (await StorageService.getGender() ?? 'male').toLowerCase();
    final verificationStatus =
        (await StorageService.getVerificationStatus() ?? 'pending')
            .toLowerCase();

    return role == 'customer' &&
        gender == 'female' &&
        verificationStatus == 'verified';
  }

  bool _isProfessionalVisible(
    Map<String, dynamic> professional, {
    required bool canViewFemaleProfessionals,
    required String viewerGender,
  }) {
    if (professional['isAvailable'] == false ||
        professional['isActive'] == false) {
      return false;
    }

    final gender =
        (professional['gender']?.toString().toLowerCase().trim() ?? 'male');
    if (viewerGender == 'female') {
      return gender == 'female' && canViewFemaleProfessionals;
    }
    if (gender != 'female') return true;
    return canViewFemaleProfessionals;
  }

  /// Load a professional's public profile
  Future<ProfessionalModel?> loadProfile(String uid) async {
    _setLoading(true);
    try {
      // Prefer backend profile endpoint (phone hidden by backend)
      Map<String, dynamic>? data;
      try {
        final resp = await _api.getProfessionalProfile(uid);
        if (resp['success'] == true && resp['data'] != null) {
          final raw = resp['data'];
          if (raw is Map && raw['professional'] is Map) {
            data = Map<String, dynamic>.from(raw['professional']);
          } else if (raw is Map) {
            data = Map<String, dynamic>.from(raw);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Backend profile failed: $e');
      }

      final firebaseProfile = await _firebase.getProfessionalById(uid);
      data ??= await _firebase.getProfessionalProfile(uid);
      if (data != null) {
        if (firebaseProfile != null) {
          bool usablePhone(dynamic value) {
            final text = value?.toString().trim() ?? '';
            if (text.isEmpty) return false;
            return !text.toLowerCase().contains('hidden');
          }

          data = {
            ...firebaseProfile,
            ...data,
            'phone': usablePhone(data['phone'])
                ? data['phone']
                : firebaseProfile['phone'] ?? firebaseProfile['phoneNumber'],
            'phoneNumber': usablePhone(data['phoneNumber'])
                ? data['phoneNumber']
                : firebaseProfile['phoneNumber'] ?? firebaseProfile['phone'],
            'location': data['location'] ?? firebaseProfile['location'],
          };
        }
        final pro = ProfessionalModel.fromMap(data);
        _selectedProfessional = pro;
        notifyListeners();
        return pro;
      }
    } catch (e) {
      _setError('Failed to load profile: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

  /// Update own professional profile
  Future<bool> updateMyProfile(String uid, Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      // Try backend update first
      try {
        final resp = await _api.updateProfessionalProfile(data);
        if (resp['success'] == true) {
          notifyListeners();
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Backend update failed: $e');
      }

      final payload = Map<String, dynamic>.from(data);
      payload['phone'] = uid;
      final success = await _firebase.updateProfessionalProfile(payload);
      if (success) {
        notifyListeners();
        return true;
      }
      _setError('Update failed');
      return false;
    } catch (e) {
      _setError('Error updating profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle availability
  Future<bool> toggleAvailability(String uid, bool isAvailable) async {
    _setLoading(true);
    try {
      // Try backend toggle availability endpoint first
      try {
        final resp = await _api.toggleAvailability(
          phone: FirebaseService.normalizePhone(uid),
          isAvailable: isAvailable,
        );
        if (resp['success'] == true) {
          notifyListeners();
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Backend toggle failed: $e');
      }

      final success = await _firebase.updateAvailability(uid, isAvailable);
      if (success) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update availability: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Filter by category
  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // ─── Earnings ───────────────────────────────────────────────────────────
  Map<String, dynamic>? _earnings;
  Map<String, dynamic>? get earnings => _earnings;

  /// Load earnings for professional from bookings
  Future<void> loadEarnings(String uid) async {
    _setLoading(true);
    try {
      final bookings = await _firebase.getBookingsForUser(uid, 'professional');
      double totalEarned = 0;
      double totalCommission = 0;
      int completedJobs = 0;

      for (final b in bookings) {
        if (b['status'] == 'completed') {
          completedJobs++;
          final price = (b['agreedPrice'] ?? 0).toDouble();
          final commission = (b['commissionAmount'] ?? price * 0.05).toDouble();
          totalEarned += (price - commission);
          totalCommission += commission;
        }
      }

      _earnings = {
        'totalEarned': totalEarned,
        'totalCommission': totalCommission,
        'completedJobs': completedJobs,
        'totalBookings': bookings.length,
      };
      notifyListeners();
    } catch (e) {
      _setError('Failed to load earnings: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
