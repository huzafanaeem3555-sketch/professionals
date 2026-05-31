import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Direct Firebase Realtime Database service.
/// Conforms to Firebase RTDB security rules using UID paths.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final ApiService _api = ApiService();

  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? phone.trim() : digits;
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _normalizeGender(dynamic value) {
    return (value ?? '').toString().toLowerCase().trim() == 'female' ? 'female' : 'male';
  }

  Future<bool> _canViewFemaleProfessionals() async {
    final role = await StorageService.getRole() ?? 'customer';
    if (role == 'admin') return true;
    final gender = await StorageService.getGender() ?? 'male';
    final verificationStatus = await StorageService.getVerificationStatus() ?? 'verified';
    return role == 'customer' &&
        gender.toLowerCase() == 'female' &&
        verificationStatus.toLowerCase() == 'verified';
  }

  bool _canShowProfessional(
    Map<String, dynamic> prof, {
    required bool canViewFemaleProfessionals,
  }) {
    if (prof['isActive'] == false) return false;
    if (_normalizeGender(prof['gender']) != 'female') return true;
    return canViewFemaleProfessionals;
  }

  Future<bool> saveContactLead({
    required String professionalId,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String serviceType,
    required String contactMethod,
    Map<String, dynamic>? customerLocation,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? customerId;
      final userSnap = await _db.child('users/$currentUid').get();
      var isFemaleCustomer = false;
      if (userSnap.exists && userSnap.value != null) {
        final user = Map<String, dynamic>.from(userSnap.value as Map);
        isFemaleCustomer = user['gender']?.toString().toLowerCase() == 'female';
      }
      final visiblePhone = isFemaleCustomer ? 'Hidden' : customerPhone;
      await _db.child('professionalContactLeads/$professionalId').push().set({
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': visiblePhone,
        'customerGender': isFemaleCustomer ? 'female' : 'male',
        'customerAddress': customerAddress,
        'customerLocation': customerLocation,
        'serviceType': serviceType,
        'contactMethod': contactMethod,
        'type': contactMethod == 'whatsapp' ? 'direct_whatsapp' : 'direct_call',
        'title': contactMethod == 'whatsapp'
            ? 'Customer sent WhatsApp message'
            : 'Customer called you',
        'body':
            '$customerName contacted you for ${serviceType.replaceAll('_', ' ')}. Phone: $visiblePhone',
        'createdAt': now,
        'expiresAt': now + 5 * 60 * 60 * 1000,
        '_createdAt': now,
      }).timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      debugPrint('saveContactLead error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFESSIONALS (UID as ID)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _professionalsFromApi() async {
    final res = await _api.getAllProfessionalsApi();
    if (res['success'] != true) return [];
    final data = res['data'];
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Get all professionals (RTDB)
  Future<List<Map<String, dynamic>>> getAllProfessionals() async {
    try {
      final canViewFemaleProfessionals = await _canViewFemaleProfessionals();
      final snapshot = await _db
          .child('professionals')
          .get()
          .timeout(const Duration(seconds: 10));
      if (!snapshot.exists) {
        final apiResults = await _professionalsFromApi();
        return apiResults
            .where((prof) => _canShowProfessional(
                  prof,
                  canViewFemaleProfessionals: canViewFemaleProfessionals,
                ))
            .toList();
      }

      final results = <Map<String, dynamic>>[];
      final profMap = Map<String, dynamic>.from(snapshot.value as Map);

      for (final uid in profMap.keys) {
        final prof = Map<String, dynamic>.from(profMap[uid] as Map);
        prof['uid'] = uid;

        // Ensure legacy fields are populated
        if (prof['phone'] == null && prof['phoneNumber'] != null) {
          prof['phone'] = prof['phoneNumber'];
        }
        if (prof['phone'] == null) {
          prof['phone'] = uid; // fallback
        }

        final services = prof['services'];
        final customServices = prof['customServices'];
        final hasServices = services is List && services.isNotEmpty;
        final hasCustomServices =
            customServices is List && customServices.isNotEmpty;
        if (!hasServices && !hasCustomServices) {
          continue;
        }

        if (!_canShowProfessional(
          prof,
          canViewFemaleProfessionals: canViewFemaleProfessionals,
        )) {
          continue;
        }

        results.add(prof);
      }
      if (results.isNotEmpty) return results;
      final apiResults = await _professionalsFromApi();
      return apiResults
          .where((prof) => _canShowProfessional(
                prof,
                canViewFemaleProfessionals: canViewFemaleProfessionals,
              ))
          .toList();
    } catch (e) {
      debugPrint('getAllProfessionals error: $e');
      final canViewFemaleProfessionals = await _canViewFemaleProfessionals();
      final apiResults = await _professionalsFromApi();
      return apiResults
          .where((prof) => _canShowProfessional(
                prof,
                canViewFemaleProfessionals: canViewFemaleProfessionals,
              ))
          .toList();
    }
  }

  /// Get professional by UID
  Future<Map<String, dynamic>?> getProfessionalById(String uid) async {
    try {
      final snapshot = await _db.child('professionals/$uid').get();
      if (!snapshot.exists) return null;
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['uid'] = uid;
      if (data['phone'] == null && data['phoneNumber'] != null) {
        data['phone'] = data['phoneNumber'];
      }
      return data;
    } catch (e) {
      debugPrint('getProfessionalById error: $e');
      return null;
    }
  }

  /// Get professional by phone number (backward compatibility fallback)
  Future<Map<String, dynamic>?> getProfessionalByPhone(String phone) async {
    try {
      final canViewFemaleProfessionals = await _canViewFemaleProfessionals();
      final normalized = normalizePhone(phone);
      // First try to look up as UID directly
      final direct = await getProfessionalById(phone);
      if (direct != null) return direct;

      // If not found, look up by comparing phone fields
      final snapshot = await _db.child('professionals').get();
      if (!snapshot.exists) return null;

      final profMap = Map<String, dynamic>.from(snapshot.value as Map);
      for (final uid in profMap.keys) {
        final prof = Map<String, dynamic>.from(profMap[uid] as Map);
        final profPhone = normalizePhone(
            prof['phone']?.toString() ?? prof['phoneNumber']?.toString() ?? '');
        if (profPhone == normalized) {
          prof['uid'] = uid;
          prof['phone'] = profPhone.isNotEmpty ? profPhone : uid;
          if (!_canShowProfessional(
            prof,
            canViewFemaleProfessionals: canViewFemaleProfessionals,
          )) {
            return null;
          }
          return prof;
        }
      }
      return null;
    } catch (e) {
      debugPrint('getProfessionalByPhone error: $e');
      return null;
    }
  }

  /// Save or update professional profile (API first, fallback to direct RTDB write)
  Future<bool> saveProfessional(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? data['uid'] ?? '';
    if (uid.isEmpty) return false;

    final phone = normalizePhone(
        data['phone']?.toString() ?? data['phoneNumber']?.toString() ?? '');
    final lat = (data['location']?['lat'] ?? data['lat'] ?? 0).toDouble();
    final lng = (data['location']?['lng'] ?? data['lng'] ?? 0).toDouble();

    final payload = {
      'uid': uid,
      'phone': phone,
      'phoneNumber': phone,
      'name': data['name'] ?? '',
      'services': data['services'] ?? [],
      'customServices': data['customServices'] ?? [],
      'location': {
        'lat': lat,
        'lng': lng,
        'address': data['location']?['address'] ?? data['address'] ?? '',
      },
      'description': data['description'] ?? '',
      'photoURL': data['photoURL'] ?? '',
      'brochureImages': data['brochureImages'] ?? [],
      'experienceYears': data['experienceYears'] ?? 0,
    };

    // Attempt API first
    try {
      final apiRes = await _api.saveProfessionalProfile(payload);
      if (apiRes['success'] == true) return true;
      debugPrint('saveProfessional API failed: ${apiRes['message']}');
    } catch (e) {
      debugPrint('saveProfessional API error: $e');
    }

    // Direct RTDB write (conforms to security rules: professionals/$uid)
    try {
      final professional = {
        'uid': uid,
        'name': payload['name'],
        'phone': payload['phone'],
        'phoneNumber': payload['phone'],
        'services': payload['services'],
        'customServices': payload['customServices'],
        'serviceTypes': payload['services'],
        'location': payload['location'],
        'lat': lat,
        'lng': lng,
        'description': payload['description'],
        'brochureImages': payload['brochureImages'],
        'experienceYears': payload['experienceYears'],
        'isAvailable': data['isAvailable'] ?? true,
        'isAvailableNow': data['isAvailable'] ?? true,
        'rating': data['rating'] ?? 0,
        'photoURL': payload['photoURL'],
        'updatedAt': ServerValue.timestamp,
      };
      professional['wallet'] = data['wallet'] ?? 5000.0;
      professional['totalEarnings'] = data['totalEarnings'] ?? 0.0;
      await _db.child('professionals/$uid').set(professional);
      await _db.child('users/$uid').update({
        'displayName': payload['name'],
        'name': payload['name'],
        'phoneNumber': payload['phone'],
        if ((payload['photoURL']?.toString() ?? '').isNotEmpty)
          'photoURL': payload['photoURL'],
        'lat': lat,
        'lng': lng,
        'location': payload['location'],
        'address': payload['location']['address'] ?? '',
        'profileCompleted': true,
        'role': 'professional',
        '_updatedAt': ServerValue.timestamp,
      });
      return true;
    } catch (e) {
      debugPrint('saveProfessional RTDB error: $e');
      return false;
    }
  }

  /// Update professional availability
  Future<bool> updateAvailability(String identifier, bool isAvailable) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? identifier;
    try {
      final apiRes = await _api.toggleAvailability(
        phone: identifier,
        isAvailable: isAvailable,
      );
      if (apiRes['success'] == true) return true;
    } catch (e) {
      debugPrint('updateAvailability API error: $e');
    }

    try {
      // Try writing to professionals/$uid (conforms to rules)
      await _db.child('professionals/$uid/isAvailable').set(isAvailable);
      return true;
    } catch (e) {
      // If UID failed, try writing to identifier path directly
      try {
        await _db
            .child('professionals/$identifier/isAvailable')
            .set(isAvailable);
        return true;
      } catch (e2) {
        debugPrint('updateAvailability error: $e2');
        return false;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOOKINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create booking (API first, fallback to RTDB) — returns booking id or null.
  Future<Map<String, dynamic>?> createBookingDirect({
    required String customerId,
    required String professionalId,
    required String serviceType,
    required double proposedPrice,
    String? contactMethod,
    String? address,
    String? description,
    Map<String, dynamic>? customerLocation,
  }) async {
    try {
      final res = await _api.createBooking(
        professionalId: professionalId,
        proposedPrice: proposedPrice,
        serviceType: serviceType,
        customerId: customerId,
        address: address,
        description: description,
        contactMethod: contactMethod,
        customerLocation: customerLocation,
      );
      if (res['success'] == true && res['data'] is Map) {
        return Map<String, dynamic>.from(res['data'] as Map);
      }
    } catch (e) {
      debugPrint('createBooking API error: $e');
    }

    try {
      final customerSnap = await _db.child('users/$customerId').get();
      final customerData = customerSnap.exists && customerSnap.value != null
          ? Map<String, dynamic>.from(customerSnap.value as Map)
          : <String, dynamic>{};
      final pro = await getProfessionalById(professionalId);
      final price = proposedPrice;
      final ref = _db.child('bookings').push();
      final bookingId = ref.key!;

      final booking = {
        'bookingId': bookingId,
        'customerId': customerId,
        'professionalId': professionalId,
        'serviceType': serviceType,
        'proposedPrice': price,
        'counterPrice': 0,
        'agreedPrice': 0,
        'status': 'pending_acceptance',
        'paymentStatus': 'pending_quote',
        'commissionAmount': double.parse((price * 0.10).toStringAsFixed(2)),
        'professionalEarnings': double.parse((price * 0.90).toStringAsFixed(2)),
        'commissionDeducted': false,
        'professionalPhone':
            pro?['phone']?.toString() ?? pro?['phoneNumber']?.toString() ?? '',
        'professionalLocation': pro?['location'],
        'customerLocation': customerLocation ?? {'lat': 0, 'lng': 0},
        'customerAddress': address ?? pro?['location']?['address'] ?? '',
        'address': address ?? '',
        'description': description ?? '',
        'customerPhone': customerData['phoneNumber']?.toString() ?? '',
        'customerName': customerData['displayName']?.toString() ?? '',
        'contactMethod': contactMethod ?? 'direct_contact',
        'negotiationHistory': {
          'initial': {
            'from': 'customer',
            'price': price,
            'timestamp': ServerValue.timestamp,
          },
        },
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      };

      await ref.set(booking);

      return {
        ...booking,
        'phoneRevealed': false,
      };
    } catch (e) {
      debugPrint('createBooking RTDB error: $e');
      return null;
    }
  }

  Future<bool> confirmBookingDeal(String bookingId) async {
    try {
      final bookingSnap = await _db.child('bookings/$bookingId').get();
      if (!bookingSnap.exists || bookingSnap.value == null) return false;

      final booking = Map<String, dynamic>.from(bookingSnap.value as Map);
      final professionalId = booking['professionalId']?.toString() ?? '';
      if (professionalId.isEmpty) return false;

      final price = _asDouble(
        booking['proposedPrice'] ??
            booking['counterPrice'] ??
            booking['agreedPrice'],
      );
      if (price <= 0) return false;

      final pro = await getProfessionalById(professionalId);
      final proPhone =
          pro?['phone']?.toString() ?? pro?['phoneNumber']?.toString() ?? '';
      final proLocation = pro?['location'];
      final commission = double.parse((price * 0.10).toStringAsFixed(2));
      final earnings = double.parse((price - commission).toStringAsFixed(2));
      final currentEarnings = _asDouble(pro?['totalEarnings']);

      await _db.child('bookings/$bookingId').update({
        'status': 'confirmed',
        'agreedPrice': price,
        'commissionAmount': commission,
        'professionalEarnings': earnings,
        'professionalPhone': proPhone,
        'professionalLocation': proLocation,
        'paymentStatus': 'pending_commission',
        'commissionDeducted': false,
        'confirmedAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      await _db.child('professionals/$professionalId').update({
        'totalEarnings': currentEarnings + earnings,
        'updatedAt': ServerValue.timestamp,
      });

      return true;
    } catch (e) {
      debugPrint('confirmBookingDeal error: $e');
      return false;
    }
  }

  /// Get bookings for customer
  Future<List<Map<String, dynamic>>> getBookingsForCustomer(
      String customerId) async {
    try {
      final snapshot = await _db
          .child('bookings')
          .orderByChild('customerId')
          .equalTo(customerId)
          .get();

      if (!snapshot.exists) return [];

      final results = <Map<String, dynamic>>[];
      final bookingsMap = Map<String, dynamic>.from(snapshot.value as Map);

      for (final entry in bookingsMap.entries) {
        final booking = Map<String, dynamic>.from(entry.value as Map);
        booking['bookingId'] = entry.key;

        // Get professional details
        final proId = booking['professionalId'] ?? booking['professionalPhone'];
        if (proId != null) {
          final pro = await getProfessionalById(proId) ??
              await getProfessionalByPhone(proId);
          if (pro != null) {
            booking['professionalName'] = pro['name'];
            booking['professionalPhone'] = pro['phone'];
            booking['professionalLocation'] = pro['location'];
          }
        }
        results.add(booking);
      }

      results
          .sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      return results;
    } catch (e) {
      debugPrint('getBookingsForCustomer error: $e');
      return [];
    }
  }

  /// Get bookings for professional by UID
  Future<List<Map<String, dynamic>>> getBookingsForProfessional(
      String professionalId) async {
    try {
      // Query /bookings directly using indexed professionalId (conforms to rules)
      final snapshot = await _db
          .child('bookings')
          .orderByChild('professionalId')
          .equalTo(professionalId)
          .get();

      if (!snapshot.exists) {
        // Fallback search using legacy professionalPhone if needed
        final legacySnapshot = await _db
            .child('bookings')
            .orderByChild('professionalPhone')
            .equalTo(professionalId)
            .get();
        if (!legacySnapshot.exists) return [];
        return _parseBookingsSnapshot(legacySnapshot);
      }

      return _parseBookingsSnapshot(snapshot);
    } catch (e) {
      debugPrint('getBookingsForProfessional error: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _parseBookingsSnapshot(DataSnapshot snapshot) {
    final results = <Map<String, dynamic>>[];
    final bookingsMap = Map<String, dynamic>.from(snapshot.value as Map);

    for (final entry in bookingsMap.entries) {
      final booking = Map<String, dynamic>.from(entry.value as Map);
      booking['bookingId'] = entry.key;
      booking['customerName'] = booking['customerName'] ??
          'Customer ${booking['customerId']?.substring(0, 8) ?? ''}';
      results.add(booking);
    }

    results
        .sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
    return results;
  }

  /// Update booking status
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      await _db.child('bookings/$bookingId/status').set(status);
      await _db
          .child('bookings/$bookingId/updatedAt')
          .set(ServerValue.timestamp);
      return true;
    } catch (e) {
      debugPrint('updateBookingStatus error: $e');
      return false;
    }
  }

  /// Accept booking
  Future<bool> acceptBooking(String bookingId) async {
    return updateBookingStatus(bookingId, 'confirmed');
  }

  /// Reject booking
  Future<bool> rejectBooking(String bookingId) async {
    return updateBookingStatus(bookingId, 'rejected');
  }

  /// Complete booking
  Future<bool> completeBooking(String bookingId) async {
    try {
      final apiRes = await _api.completeJob(bookingId);
      if (apiRes['success'] == true) return true;
    } catch (e) {
      debugPrint('completeBooking API error: $e');
    }
    return updateBookingStatus(bookingId, 'completed');
  }

  /// Cancel booking
  Future<bool> cancelBooking(String bookingId) async {
    return updateBookingStatus(bookingId, 'cancelled');
  }

  /// Add rating after completion
  Future<bool> rateBooking(String bookingId, int rating, String? review) async {
    try {
      await _db.child('bookings/$bookingId').update({
        'customerRating': rating,
        'customerReview': review ?? '',
        'ratedAt': ServerValue.timestamp,
      });

      // Update professional's average rating
      final booking = await _db.child('bookings/$bookingId').get();
      if (booking.exists) {
        final data = booking.value as Map;
        final proId = data['professionalId'] ?? data['professionalPhone'];
        if (proId != null) {
          final pro = await getProfessionalById(proId) ??
              await getProfessionalByPhone(proId);
          if (pro != null) {
            final oldRating = (pro['rating'] ?? 0).toDouble();
            final oldTotal = (pro['totalRatings'] ?? 0).toInt();
            final newTotal = oldTotal + 1;
            final newRating = ((oldRating * oldTotal) + rating) / newTotal;
            await _db.child('professionals/$proId').update({
              'rating': double.parse(newRating.toStringAsFixed(2)),
              'totalRatings': newTotal,
              'updatedAt': ServerValue.timestamp,
            });
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('rateBooking error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT (UID based)
  // ═══════════════════════════════════════════════════════════════════════════

  String _chatPath(
      {String? bookingId,
      required String userId,
      required String otherUserId}) {
    if (bookingId != null && bookingId.isNotEmpty) {
      return 'chats/$bookingId';
    }
    return 'chats/${_getChatId(userId, otherUserId)}';
  }

  /// Send chat message (booking-scoped when [bookingId] provided).
  Future<bool> sendMessage(
    String senderId,
    String receiverId,
    String text, {
    String? bookingId,
  }) async {
    try {
      if (senderId.isEmpty || receiverId.isEmpty || text.trim().isEmpty) {
        return false;
      }

      final base = _chatPath(
        bookingId: bookingId,
        userId: senderId,
        otherUserId: receiverId,
      );
      final ref = _db.child('$base/messages').push();

      await ref.set({
        'id': ref.key,
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text.trim(),
        'timestamp': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 10));

      await _db.child('$base/meta').update({
        'lastMessage': text.trim(),
        'lastTimestamp': ServerValue.timestamp,
        'participant1': senderId,
        'participant2': receiverId,
        if (bookingId != null) 'bookingId': bookingId,
      });

      return true;
    } catch (e) {
      debugPrint('sendMessage error: $e');
      return false;
    }
  }

  /// Messages ref — prefers chats/{bookingId}/messages when bookingId set.
  DatabaseReference getChatMessagesRef(
    String userId,
    String otherUserId, {
    String? bookingId,
  }) {
    final base = _chatPath(
      bookingId: bookingId,
      userId: userId,
      otherUserId: otherUserId,
    );
    return _db.child('$base/messages');
  }

  /// Get all conversations for a user
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      final snapshot = await _db.child('chats').get();
      if (!snapshot.exists) return [];

      final results = <Map<String, dynamic>>[];
      final chatsMap = Map<String, dynamic>.from(snapshot.value as Map);

      for (final entry in chatsMap.entries) {
        final chat = Map<String, dynamic>.from(entry.value as Map);
        final meta = chat['meta'];
        if (meta == null) continue;

        final metaMap = Map<String, dynamic>.from(meta as Map);
        final participant1 = metaMap['participant1']?.toString() ?? '';
        final participant2 = metaMap['participant2']?.toString() ?? '';

        if (participant1 != userId && participant2 != userId) continue;

        final otherId = participant1 == userId ? participant2 : participant1;

        results.add({
          'chatId': entry.key,
          'otherUserId': otherId,
          'otherUserName':
              otherId.startsWith('customer_') ? 'Customer' : 'Professional',
          'lastMessage': metaMap['lastMessage'] ?? '',
          'lastTimestamp': metaMap['lastTimestamp'] ?? 0,
        });
      }

      results.sort((a, b) =>
          (b['lastTimestamp'] ?? 0).compareTo(a['lastTimestamp'] ?? 0));
      return results;
    } catch (e) {
      debugPrint('getConversations error: $e');
      return [];
    }
  }

  String getChatId(String id1, String id2) => _getChatId(id1, id2);

  String _getChatId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Bookings for customer or professional (role: customer | professional).
  Future<List<Map<String, dynamic>>> getBookingsForUser(
    String userId,
    String role,
  ) async {
    if (role == 'customer') {
      return getBookingsForCustomer(userId);
    }
    return getBookingsForProfessional(userId);
  }

  Future<bool> hasConfirmedBooking(String id1, String id2) async {
    return isChatAllowed(myId: id1, otherUserId: id2);
  }

  Future<Map<String, dynamic>?> getProfessionalProfile(String uid) =>
      getProfessionalById(uid);

  Future<bool> updateProfessionalProfile(Map<String, dynamic> data) =>
      saveProfessional(data);

  /// Chat only when a confirmed booking exists between customer and professional.
  Future<bool> isChatAllowed({
    required String myId,
    required String otherUserId,
    String? bookingId,
  }) async {
    try {
      if (bookingId != null && bookingId.isNotEmpty) {
        final snap = await _db.child('bookings/$bookingId').get();
        if (snap.exists) {
          final data = Map<String, dynamic>.from(snap.value as Map);
          return data['status'] == 'confirmed';
        }
      }

      final snapshot = await _db.child('bookings').get();
      if (!snapshot.exists) return false;

      final bookings = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in bookings.entries) {
        final b = Map<String, dynamic>.from(entry.value as Map);
        if (b['status'] != 'confirmed') continue;

        final customerId = b['customerId']?.toString() ?? '';
        final proPhone = b['professionalPhone']?.toString() ?? '';
        final proId = b['professionalId']?.toString() ?? '';

        if ((customerId == myId || customerId == otherUserId) &&
            (proPhone == myId ||
                proPhone == otherUserId ||
                proId == myId ||
                proId == otherUserId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('isChatAllowed error: $e');
      return false;
    }
  }
}
