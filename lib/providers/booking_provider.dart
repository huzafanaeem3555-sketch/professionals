import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../services/api_service.dart';
import '../models/booking_model.dart';
import '../services/firebase_service.dart';

class BookingProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final ApiService _api = ApiService();

  List<BookingModel> _myBookings = [];
  List<BookingModel> _activeBookings = [];
  List<BookingModel> _professionalBookings = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _lastCreateResult;
  StreamSubscription? _bookingSubscription;

  Map<String, dynamic>? get lastCreateResult => _lastCreateResult;

  List<BookingModel> get myBookings => _myBookings;
  List<BookingModel> get activeBookings => _activeBookings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BookingModel> get professionalBookings => _professionalBookings;

  Future<String> _getCurrentUid() async {
    return await StorageService.getUid() ?? '';
  }

  // ─── Create Booking ───────────────────────────────────────────────────────
  Future<bool> createBooking({
    required String professionalId,
    required String serviceType,
    required double proposedPrice,
    String? contactMethod,
    String? scheduledTime,
    String? address,
    String? description,
    Map<String, dynamic>? customerLocation,
  }) async {
    _setLoading(true);
    _clearError();
    _lastCreateResult = null;
    try {
      final customerId = await StorageService.getCustomerId();
      final res = await _api.createBooking(
        professionalId: professionalId,
        proposedPrice: proposedPrice,
        serviceType: serviceType,
        contactMethod: contactMethod,
        customerId: customerId,
        scheduledTime: scheduledTime,
        address: address,
        description: description,
        customerLocation: customerLocation,
      );

      if (res['success'] == true) {
        final data = res['data'];
        if (data is Map) {
          _lastCreateResult = Map<String, dynamic>.from(data);
        }
        return true;
      }
      final fallback = await _firebase.createBookingDirect(
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        proposedPrice: proposedPrice,
        contactMethod: contactMethod,
        address: address,
        description: description,
        customerLocation: customerLocation,
      );
      if (fallback != null) {
        _lastCreateResult = fallback;
        return true;
      }

      _setError(res['message'] ?? 'Failed to create booking');
      return false;
    } catch (e) {
      final customerId = await StorageService.getCustomerId();
      final fallback = await _firebase.createBookingDirect(
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        proposedPrice: proposedPrice,
        contactMethod: contactMethod,
        address: address,
        description: description,
        customerLocation: customerLocation,
      );
      if (fallback != null) {
        _lastCreateResult = fallback;
        return true;
      }
      _setError('Error: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Load Bookings (Real-time) ───────────────────────────────────────────
  Future<void> loadMyBookings(String uid, String role) async {
    _setLoading(true);
    _bookingSubscription?.cancel();

    final field = role == 'customer' ? 'customerId' : 'professionalId';

    // Initial fetch
    await _fetchAndSetBookings(uid, role);
    _setLoading(false);

    // Listen for real-time updates
    _bookingSubscription = FirebaseDatabase.instance
        .ref('bookings')
        .orderByChild(field)
        .equalTo(uid)
        .onValue
        .listen((event) {
      _fetchAndSetBookings(uid, role);
    });
  }

  Future<void> _fetchAndSetBookings(String uid, String role) async {
    try {
      final results = await _firebase.getBookingsForUser(uid, role);
      final models = results.map((b) => BookingModel.fromMap(b)).toList();

      const activeStatuses = <String>{
        'pending_acceptance',
        'pending_customer_response',
        'pending_professional_response',
        'counter_offered',
        'pending_payment',
        'confirmed',
        'in_progress',
      };

      _myBookings = models;
      _activeBookings =
          models.where((b) => activeStatuses.contains(b.status)).toList();

      if (role == 'professional') {
        _professionalBookings = models;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('fetchAndSetBookings error: $e');
    }
  }

  // ─── Booking Actions ──────────────────────────────────────────────────────
  Future<bool> acceptBooking(String bookingId) async {
    _setLoading(true);
    _clearError();
    try {
      final res = await _api.acceptBooking(bookingId);
      if (res['success'] == true) return true;
      final fallback = await _firebase.acceptBooking(bookingId);
      if (fallback) return true;
      _setError(res['message'] ?? 'Failed to accept booking');
      return false;
    } catch (e) {
      final fallback = await _firebase.acceptBooking(bookingId);
      if (fallback) return true;
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> proposePrice(String bookingId, double price) async {
    _setLoading(true);
    _clearError();
    try {
      final res = await _api.proposePrice(bookingId, price);
      if (res['success'] == true) return true;
      _setError(res['message'] ?? 'Failed to propose price');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> counterPrice(String bookingId, double price) async {
    _setLoading(true);
    _clearError();
    try {
      final res = await _api.counterPrice(bookingId, price);
      if (res['success'] == true) return true;
      _setError(res['message'] ?? 'Failed to counter price');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rejectBooking(String bookingId) async {
    _setLoading(true);
    try {
      final res = await _api.rejectBooking(bookingId);
      return res['success'] == true;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelBooking(String bookingId) async {
    _setLoading(true);
    try {
      final res = await _api.cancelBooking(bookingId);
      return res['success'] == true;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> startJob(String bookingId) async {
    _setLoading(true);
    try {
      final res = await _api.startJob(bookingId);
      return res['success'] == true;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> completeJob(String bookingId) async {
    _setLoading(true);
    try {
      final res = await _api.completeJob(bookingId);
      return res['success'] == true;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> customerConfirmCompletion(String bookingId) async {
    _setLoading(true);
    _clearError();
    try {
      final res = await _api.customerConfirmCompletion(bookingId);
      if (res['success'] == true) return true;
      final fallback =
          await _firebase.updateBookingStatus(bookingId, 'customer_confirmed');
      if (fallback) return true;
      _setError(res['message'] ?? 'Failed to confirm completion');
      return false;
    } catch (e) {
      final fallback =
          await _firebase.updateBookingStatus(bookingId, 'customer_confirmed');
      if (fallback) return true;
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> professionalConfirmCompletion(String bookingId) async {
    return completeJob(bookingId);
  }

  Future<bool> rateBooking({
    required String bookingId,
    required int rating,
    String? review,
  }) async {
    _setLoading(true);
    try {
      final res = await _api.rateBooking(
          bookingId: bookingId, rating: rating, review: review);
      return res['success'] == true;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadProfessionalBookings() async {
    final uid = await _getCurrentUid();
    await loadMyBookings(uid, 'professional');
  }

  /// Load active bookings for current user
  Future<void> loadActiveBookings() async {
    final uid = await _getCurrentUid();
    if (uid.isEmpty) {
      _setError('User ID not found');
      return;
    }
    await loadMyBookings(uid, 'customer');
  }

  /// Propose counter bid (same as counterPrice)
  Future<bool> proposeCounterBid(String bookingId, double bidPrice) async {
    return counterPrice(bookingId, bidPrice);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String e) {
    _error = e;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() => _clearError();

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }
}
