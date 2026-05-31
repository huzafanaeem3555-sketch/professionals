import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AdminProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _stats;
  List<dynamic> _professionals = [];
  List<dynamic> _customers = [];
  List<dynamic> _bookings = [];
  List<dynamic> _transactions = [];
  bool _isLoading = false;
  String? _error;
  bool _isAdminLoggedIn = false;
  Timer? _pollTimer;
  bool _fetching = false;

  Map<String, dynamic>? get stats => _stats;
  List<dynamic> get professionals => _professionals;
  List<dynamic> get customers => _customers;
  List<dynamic> get bookings => _bookings;
  List<dynamic> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdminLoggedIn => _isAdminLoggedIn;
  bool get hasAnyData =>
      _stats != null ||
      _professionals.isNotEmpty ||
      _customers.isNotEmpty ||
      _bookings.isNotEmpty ||
      _transactions.isNotEmpty;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String? err) {
    _error = err;
    notifyListeners();
  }

  Future<bool> login(String username) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.adminLogin(username);
      if (res['success'] == true) {
        _isAdminLoggedIn = true;
        unawaited(fetchAll(showLoading: false));
        startRealtimePolling();
        _setError(null);
        notifyListeners();
        return true;
      }
      _setError(res['message'] ?? 'Admin login failed.');
      return false;
    } catch (e) {
      _setError('Login error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void startRealtimePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      fetchAll(showLoading: false);
    });
  }

  Future<void> fetchAll({bool showLoading = true}) async {
    if (_fetching) return;
    _fetching = true;
    if (showLoading) _setLoading(true);
    try {
      Future<Map<String, dynamic>> safeCall(
        Future<Map<String, dynamic>> future,
      ) async {
        try {
          return await future;
        } catch (e) {
          return {'success': false, 'message': e.toString()};
        }
      }

      final results = await Future.wait([
        safeCall(_api.getAdminStats()),
        safeCall(_api.getAdminProfessionals()),
        safeCall(_api.getAdminCustomers()),
        safeCall(_api.getAdminBookings()),
        safeCall(_api.getAdminTransactions()),
      ]);

      String? firstError;
      if (results[0]['success'] == true && results[0]['data'] != null) {
        _stats = Map<String, dynamic>.from(results[0]['data']);
      } else {
        firstError ??= results[0]['message']?.toString();
      }
      if (results[1]['success'] == true && results[1]['data'] != null) {
        _professionals = List<dynamic>.from(results[1]['data']);
      } else {
        firstError ??= results[1]['message']?.toString();
      }
      if (results[2]['success'] == true && results[2]['data'] != null) {
        _customers = List<dynamic>.from(results[2]['data']);
      } else {
        firstError ??= results[2]['message']?.toString();
      }
      if (results[3]['success'] == true && results[3]['data'] != null) {
        _bookings = List<dynamic>.from(results[3]['data']);
      } else {
        firstError ??= results[3]['message']?.toString();
      }
      if (results[4]['success'] == true && results[4]['data'] != null) {
        _transactions = List<dynamic>.from(results[4]['data']);
      } else {
        firstError ??= results[4]['message']?.toString();
      }
      _error = firstError;
      notifyListeners();
    } catch (e) {
      _setError('Admin refresh failed: $e');
    } finally {
      _fetching = false;
      if (showLoading) _setLoading(false);
    }
  }

  Future<void> fetchStats() => fetchAll();
  Future<void> fetchProfessionals() => fetchAll();
  Future<void> fetchCustomers() => fetchAll();
  Future<void> fetchBookings() => fetchAll();
  Future<void> fetchTransactions() => fetchAll();

  Future<bool> deleteUser(String uid) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.deleteAdminUser(uid);
      if (res['success'] == true) {
        await fetchAll(showLoading: false);
        return true;
      }
      _setError(res['message'] ?? 'Failed to delete user.');
      return false;
    } catch (e) {
      _setError('Error deleting user: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyUser(String uid, {bool verified = true}) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.verifyAdminUser(uid, verified: verified);
      if (res['success'] == true) {
        await fetchAll(showLoading: false);
        return true;
      }
      _setError(res['message'] ?? 'Failed to update verification.');
      return false;
    } catch (e) {
      _setError('Verification error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.createAdminUser(data);
      if (res['success'] == true) {
        await fetchAll(showLoading: false);
        return true;
      }
      _setError(res['message'] ?? 'Failed to add user.');
      return false;
    } catch (e) {
      _setError('Error adding user: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfessional(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _api.updateAdminProfessional(uid, data);
      if (res['success'] == true) {
        await fetchAll(showLoading: false);
        return true;
      }
      _setError(res['message'] ?? 'Failed to update professional.');
      return false;
    } catch (e) {
      _setError('Update error: $e');
      return false;
    }
  }

  Future<List<dynamic>> getProfessionalReviews(String uid) async {
    final res = await _api.getAdminProfessionalReviews(uid);
    if (res['success'] == true && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    _setError(res['message'] ?? 'Failed to fetch reviews.');
    return [];
  }

  Future<bool> deleteProfessionalReview(String uid, String reviewId) async {
    final res = await _api.deleteAdminProfessionalReview(uid, reviewId);
    if (res['success'] == true) {
      await fetchAll(showLoading: false);
      return true;
    }
    _setError(res['message'] ?? 'Failed to delete review.');
    return false;
  }

  Future<bool> deleteBooking(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.deleteAdminBooking(id);
      if (res['success'] == true) {
        await fetchAll(showLoading: false);
        return true;
      }
      _setError(res['message'] ?? 'Failed to delete booking.');
      return false;
    } catch (e) {
      _setError('Error deleting booking: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> clearAllData() async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.clearAdminData();
      if (res['success'] == true) {
        await fetchAll(showLoading: false);
        return true;
      }
      _setError(res['message'] ?? 'Failed to clear data.');
      return false;
    } catch (e) {
      _setError('Error clearing data: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _api.clearToken();
    _isAdminLoggedIn = false;
    _stats = null;
    _professionals = [];
    _customers = [];
    _bookings = [];
    _transactions = [];
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
