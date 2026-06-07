import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import 'storage_service.dart';

/// Public API client with Authorization header management.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 35),
      sendTimeout: const Duration(seconds: 25),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            print('🔵 [API] ${options.method} ${options.path}');
            print('🔵 [API Headers] ${options.headers}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            print(
                '✅ [API] ${response.statusCode} ${response.requestOptions.path}');
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            print('❌ [API] ${error.type}: ${error.message}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> initializeToken() async {
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<void> setBackendToken(String? token) async {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      await StorageService.setToken(token);
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<void> clearToken() async {
    _dio.options.headers.remove('Authorization');
    await StorageService.clearAll();
  }

  Future<void> clearBackendTokenOnly() async {
    _dio.options.headers.remove('Authorization');
    await StorageService.clearToken();
  }

  Future<String?> getCurrentToken() async {
    return await StorageService.getToken();
  }

  // ─── FCM NOTIFICATION TOKEN ────────────────────────────────────────────────

  /// Update FCM token for current user
  Future<Map<String, dynamic>> updateFcmToken(
      String userId, String token) async {
    try {
      final response = await _withRetry(
        () => _dio.post('/notifications/update-token', data: {
          'userId': userId,
          'token': token,
        }),
      );
      if (kDebugMode) {
        print('✅ FCM token updated for user: $userId');
      }
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update FCM token: $e');
      }
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendContactNotification({
    required String targetUserId,
    required String title,
    required String body,
    String? bookingId,
    String? contactMethod,
    String? type,
    String? serviceType,
    String? customerPhone,
    String? customerAddress,
    Map<String, dynamic>? customerLocation,
    bool leadAlreadySaved = false,
    String? referralCode,
    String? referralDiscountPercent,
    String? referralOwnerId,
    String? referralOwnerName,
    bool hasReferralDiscount = false,
  }) async {
    try {
      final response = await _withRetry(
        () => _dio.post('/notifications/contact', data: {
          'targetUserId': targetUserId,
          'title': title,
          'body': body,
          if (bookingId != null) 'bookingId': bookingId,
          if (contactMethod != null) 'contactMethod': contactMethod,
          if (type != null) 'type': type,
          if (serviceType != null) 'serviceType': serviceType,
          if (customerPhone != null) 'customerPhone': customerPhone,
          if (customerAddress != null) 'customerAddress': customerAddress,
          if (customerLocation != null) 'customerLocation': customerLocation,
          if (leadAlreadySaved) 'leadAlreadySaved': true,
          if (referralCode != null && referralCode.isNotEmpty)
            'referralCode': referralCode,
          if (referralDiscountPercent != null &&
              referralDiscountPercent.isNotEmpty)
            'referralDiscountPercent': referralDiscountPercent,
          if (referralOwnerId != null && referralOwnerId.isNotEmpty)
            'referralOwnerId': referralOwnerId,
          if (referralOwnerName != null && referralOwnerName.isNotEmpty)
            'referralOwnerName': referralOwnerName,
          if (hasReferralDiscount) 'hasReferralDiscount': true,
        }),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── AUTH ENDPOINTS ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveContactLeadPublic({
    required String targetUserId,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String serviceType,
    required String contactMethod,
    Map<String, dynamic>? customerLocation,
    bool leadAlreadySaved = false,
    String? referralCode,
    String? referralDiscountPercent,
    String? referralOwnerId,
    String? referralOwnerName,
    bool hasReferralDiscount = false,
  }) async {
    try {
      final uid = await StorageService.getUid();
      final details = await StorageService.getUserDetails();
      final customerPhotoURL = details['photo']?.toString().trim() ?? '';
      var gender = await StorageService.getGender() ?? 'male';
      if (uid != null && uid.isNotEmpty) {
        // Keep payload stable even if local gender is unavailable.
        gender = gender.toLowerCase() == 'female' ? 'female' : 'male';
      }
      final isProfileView = contactMethod == 'profile_view';
      final title = isProfileView
          ? 'Customer viewed your profile'
          : contactMethod == 'whatsapp'
              ? 'Customer sent WhatsApp message'
              : 'Customer called you';
      final visiblePhone = gender == 'female' ? 'Hidden' : customerPhone;
      final body = isProfileView
          ? '$customerName viewed your HirePro profile.'
          : '$customerName contacted you for ${serviceType.replaceAll('_', ' ')}. Phone: $visiblePhone';
      final response = await _withRetry(
        () => _dio.post('/notifications/contact-public', data: {
          'targetUserId': targetUserId,
          'customerId': customerId,
          'customerName': customerName,
          'customerPhotoURL': customerPhotoURL,
          'customerPhone': visiblePhone,
          'customerGender': gender,
          'customerAddress': customerAddress,
          'serviceType': serviceType,
          'contactMethod': contactMethod,
          'type': isProfileView
              ? 'profile_view'
              : contactMethod == 'whatsapp'
                  ? 'direct_whatsapp'
                  : 'direct_call',
          'title': title,
          'body': body,
          if (customerLocation != null) 'customerLocation': customerLocation,
          if (leadAlreadySaved) 'leadAlreadySaved': true,
          if (referralCode != null && referralCode.isNotEmpty)
            'referralCode': referralCode,
          if (referralDiscountPercent != null &&
              referralDiscountPercent.isNotEmpty)
            'referralDiscountPercent': referralDiscountPercent,
          if (referralOwnerId != null && referralOwnerId.isNotEmpty)
            'referralOwnerId': referralOwnerId,
          if (referralOwnerName != null && referralOwnerName.isNotEmpty)
            'referralOwnerName': referralOwnerName,
          if (hasReferralDiscount) 'hasReferralDiscount': true,
        }),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    try {
      final response = await _withRetry(
        () => _dio.post('/auth/google', data: {'idToken': idToken}),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> signInWithToken(String idToken) async {
    try {
      final response = await _withRetry(
        () => _dio.post('/auth/signin', data: {'idToken': idToken}),
      );
      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        final token = map['data']?['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await setBackendToken(token);
        }
      }
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> setRole(
    String role, {
    String? gender,
    String? displayName,
    String? phoneNumber,
  }) async {
    try {
      final response = await _withRetry(
        () => _dio.post('/users/set-role', data: {
          'role': role,
          if (gender != null) 'gender': gender,
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phoneNumber': phoneNumber.trim(),
        }),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> _handleError(dynamic error) async {
    try {
      if (error is DioException) {
        ErrorHandler.logError('API Request', error);
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout) {
          return {
            'success': false,
            'message':
                'Cannot connect to server. Please check your internet and try again.',
          };
        }
        if (error.type == DioExceptionType.receiveTimeout) {
          return {
            'success': false,
            'message': 'Server taking too long to respond. Please try again.',
          };
        }
        if (error.type == DioExceptionType.sendTimeout) {
          return {
            'success': false,
            'message': 'Connection timeout. Please check your internet.',
          };
        }
        return ErrorHandler.handleDioException(error);
      }
      final message = ErrorHandler.getErrorMessage(error);
      ErrorHandler.logError('API Error', error);
      return {'success': false, 'message': message};
    } catch (e) {
      ErrorHandler.logError('Error handler failed', e);
      return {'success': false, 'message': 'An unexpected error occurred.'};
    }
  }

  // ─── BOOKING ENDPOINTS ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createBooking({
    required String professionalId,
    required double proposedPrice,
    required String serviceType,
    String? contactMethod,
    String? scheduledTime,
    String? address,
    String? description,
    String? customerId,
    Map<String, dynamic>? customerLocation,
  }) async {
    try {
      final response = await _withRetry(() => _dio.post(
            ApiConstants.bookings,
            data: {
              'professionalPhone': professionalId,
              'professionalId': professionalId,
              'proposedPrice': proposedPrice,
              'serviceType': serviceType,
              if (contactMethod != null) 'contactMethod': contactMethod,
              if (customerId != null) 'customerId': customerId,
              if (scheduledTime != null) 'scheduledTime': scheduledTime,
              if (address != null) 'address': address,
              if (description != null) 'description': description,
              if (customerLocation != null)
                'customerLocation': customerLocation,
            },
          ));
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  bool _isRetryable(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  List<String> get _candidateBaseUrls {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final urls = <String>[
      if (fromDefine.isNotEmpty) fromDefine,
      ApiConstants.baseUrl,
      ...ApiConstants.fallbackBaseUrls,
    ];
    return urls.toSet().toList();
  }

  Future<Response<dynamic>> _withRetry(
    Future<Response<dynamic>> Function() action,
  ) async {
    DioException? lastError;
    final originalBaseUrl = _dio.options.baseUrl;

    for (final baseUrl in _candidateBaseUrls) {
      _dio.options.baseUrl = baseUrl;
      for (var attempt = 0; attempt < 2; attempt += 1) {
        try {
          return await action();
        } on DioException catch (e) {
          lastError = e;
          if (!_isRetryable(e)) {
            _dio.options.baseUrl = originalBaseUrl;
            rethrow;
          }
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }
    }

    _dio.options.baseUrl = originalBaseUrl;
    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
          message: 'Unable to connect to any configured backend URL.',
        );
  }

  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    try {
      final response = await _dio.get('${ApiConstants.bookings}/$bookingId');
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> acceptBooking(String bookingId) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.acceptBooking}/$bookingId/accept',
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> proposePrice(
      String bookingId, double price) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.bookings}/$bookingId/propose-price',
        data: {'price': price},
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> counterPrice(
      String bookingId, double counterPrice) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.bookings}/$bookingId/counter-price',
        data: {'counterPrice': counterPrice},
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> rejectBooking(String bookingId) async {
    try {
      final response = await _dio.patch(
        '${ApiConstants.rejectBooking}/$bookingId/reject',
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await _dio.delete(
        '${ApiConstants.cancelBookingEndpoint}/$bookingId',
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> startJob(String bookingId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.startJobEndpoint}/$bookingId/start',
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> completeJob(String bookingId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.completeJobEndpoint}/$bookingId/complete',
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> customerConfirmCompletion(
      String bookingId) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.completeJobEndpoint}/$bookingId/customer-complete',
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> rateBooking({
    required String bookingId,
    required int rating,
    String? review,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.rateBookingEndpoint}/$bookingId/rate',
        data: {'rating': rating, if (review != null) 'review': review},
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMyBookings({String? customerId}) async {
    try {
      final response = await _dio.get(
        ApiConstants.myBookings,
        queryParameters: customerId != null ? {'customerId': customerId} : null,
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getActiveBookings() async {
    try {
      final response = await _dio.get(ApiConstants.activeBookings);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── PROFESSIONALS ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNearbyProfessionals({
    required double lat,
    required double lng,
    double radius = 20,
    String? serviceType,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.nearbyProfessionals,
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
          if (serviceType != null) 'serviceType': serviceType,
        },
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getProfessionalProfile(String phone) async {
    try {
      final response =
          await _dio.get('${ApiConstants.professionalProfile}/$phone');
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> saveProfessionalProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(ApiConstants.updateProfile, data: data);
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': true, 'data': response.data};
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateProfessionalProfile(
    Map<String, dynamic> data,
  ) =>
      saveProfessionalProfile(data);

  Future<Map<String, dynamic>> getAllProfessionalsApi() async {
    try {
      final response = await _dio.get(ApiConstants.professionalsAll);
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': true, 'data': response.data};
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> toggleAvailability({
    required String phone,
    required bool isAvailable,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConstants.toggleAvailability,
        data: {'phone': phone, 'isAvailable': isAvailable},
      );
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': true, 'data': response.data};
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadPortfolio(
      List<String> base64Images) async {
    try {
      final response = await _dio.post(
        ApiConstants.uploadPortfolio,
        data: {'images': base64Images},
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(String base64Image) async {
    final cleanBase64 =
        base64Image.contains(',') ? base64Image.split(',').last : base64Image;

    try {
      final response = await _dio.post(
        ApiConstants.uploadPhoto,
        data: {'image': cleanBase64},
      );
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': true, 'data': response.data};
      final url =
          data['data'] is Map ? data['data']['photoURL']?.toString() ?? '' : '';
      if (data['success'] == true && url.isNotEmpty) return data;
    } catch (e) {
      if (kDebugMode) debugPrint('Backend profile photo upload failed: $e');
    }

    try {
      final response = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null,
      )).post(
        'https://api.imgbb.com/1/upload',
        data: FormData.fromMap({
          'key': '8f3e5cbd42066c0539ba1b0a8f323fbf',
          'image': cleanBase64,
          'name': 'professional_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );
      final body = response.data;
      if (body is Map && body['success'] == true && body['data'] is Map) {
        final uploaded = Map<String, dynamic>.from(body['data'] as Map);
        final url =
            (uploaded['display_url'] ?? uploaded['url'] ?? '').toString();
        if (url.isNotEmpty) {
          return {
            'success': true,
            'data': {
              'photoURL': url,
              'thumbUrl': uploaded['thumb'] is Map
                  ? (uploaded['thumb']['url'] ?? '').toString()
                  : '',
              'deleteUrl': uploaded['delete_url']?.toString() ?? '',
            },
            'message': 'Image uploaded successfully.',
          };
        }
      }
      return {
        'success': false,
        'message': 'ImgBB upload failed. Please try another image.',
      };
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadImgBbImage(
    String base64Image, {
    String namePrefix = 'professional_asset',
  }) async {
    final cleanBase64 =
        base64Image.contains(',') ? base64Image.split(',').last : base64Image;

    try {
      final response = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null,
      )).post(
        'https://api.imgbb.com/1/upload',
        data: FormData.fromMap({
          'key': '8f3e5cbd42066c0539ba1b0a8f323fbf',
          'image': cleanBase64,
          'name': '${namePrefix}_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );
      final body = response.data;
      if (body is Map && body['success'] == true && body['data'] is Map) {
        final uploaded = Map<String, dynamic>.from(body['data'] as Map);
        final url =
            (uploaded['display_url'] ?? uploaded['url'] ?? '').toString();
        if (url.isNotEmpty) {
          return {
            'success': true,
            'data': {'url': url},
            'message': 'Image uploaded successfully.',
          };
        }
      }
      return {
        'success': false,
        'message': 'ImgBB upload failed. Please try another image.',
      };
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getEarnings() async {
    try {
      final response = await _dio.get(ApiConstants.earningsEndpoint);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── CHAT ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.sendMessage,
        data: {'receiverId': receiverId, 'text': text},
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMessages(String otherUserId) async {
    try {
      final response =
          await _dio.get('${ApiConstants.getMessages}/$otherUserId');
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getConversations() async {
    try {
      final response = await _dio.get(ApiConstants.conversations);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendAIMessage(
      String prompt, List<Map<String, String>> history,
      {Map<String, dynamic>? location}) async {
    try {
      final response = await _dio.post(
        ApiConstants.aiMessage,
        data: {
          'message': prompt,
          'history': history,
          if (location != null) 'location': location,
        },
      );
      return response.data;
    } catch (e) {
      if (kDebugMode) print('sendAIMessage failed: $e');
      return {
        'success': true,
        'data': {
          'reply':
              'Sorry, AI assistant is currently unavailable. Try again later.',
          'professionals': [],
        },
      };
    }
  }

  Future<Map<String, dynamic>> recommendService(String description) async {
    try {
      final response = await _withRetry(
        () => _dio.post(
          ApiConstants.aiRecommendService,
          data: {'description': description},
        ),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPopularServices({int limit = 50}) async {
    try {
      final response = await _withRetry(
        () => _dio.get(
          ApiConstants.searchPopular,
          queryParameters: {'limit': limit},
        ),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> trackServiceSearch({
    String? query,
    String? serviceType,
  }) async {
    try {
      final response = await _withRetry(
        () => _dio.post(
          ApiConstants.searchTrack,
          data: {
            if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
            if (serviceType != null && serviceType.trim().isNotEmpty)
              'serviceType': serviceType.trim(),
          },
        ),
      );
      return response.data;
    } catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> searchProfessionals(String query) async {
    try {
      final response = await _withRetry(
        () => _dio.get(
          ApiConstants.search,
          queryParameters: {'q': query.trim()},
        ),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createComplaint(
      Map<String, dynamic> data) async {
    try {
      final response = await _withRetry(
        () => _dio.post(ApiConstants.marketplaceComplaints, data: data),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFavorites() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.marketplaceFavorites),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> toggleFavorite(
    String professionalId, {
    bool favorite = true,
  }) async {
    try {
      final response = await _withRetry(
        () => favorite
            ? _dio.post('${ApiConstants.marketplaceFavorites}/$professionalId',
                data: {'favorite': true})
            : _dio
                .delete('${ApiConstants.marketplaceFavorites}/$professionalId'),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createReferral(Map<String, dynamic> data) async {
    try {
      final response = await _withRetry(
        () => _dio.post(ApiConstants.marketplaceReferrals, data: data),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> applyReferral(String code) async {
    try {
      final response = await _withRetry(
        () => _dio.post('${ApiConstants.marketplaceReferrals}/apply',
            data: {'code': code}),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMyReferrals() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.marketplaceReferrals),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createJobPost(Map<String, dynamic> data) async {
    try {
      final response = await _withRetry(
        () => _dio.post(ApiConstants.marketplaceJobs, data: data),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getJobPosts() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.marketplaceJobs),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createJobOffer(
    String postId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _withRetry(
        () => _dio.post('${ApiConstants.marketplaceJobs}/$postId/offers',
            data: data),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getJobOffers(String postId) async {
    try {
      final response = await _withRetry(
        () => _dio.get('${ApiConstants.marketplaceJobs}/$postId/offers'),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> selectJobOffer({
    required String postId,
    required String offerId,
  }) async {
    try {
      final response = await _withRetry(
        () => _dio.post(
          '${ApiConstants.marketplaceJobs}/$postId/offers/$offerId/select',
        ),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> counterJobOffer({
    required String postId,
    required String offerId,
    required double counterPrice,
    String? message,
  }) async {
    try {
      final response = await _withRetry(
        () => _dio.patch(
          '${ApiConstants.marketplaceJobs}/$postId/offers/$offerId/counter',
          data: {
            'counterPrice': counterPrice,
            if (message != null && message.trim().isNotEmpty)
              'message': message.trim(),
          },
        ),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateJobStatus({
    required String postId,
    required String status,
  }) async {
    try {
      final response = await _withRetry(
        () => _dio.patch(
          '${ApiConstants.marketplaceJobs}/$postId/status',
          data: {'status': status},
        ),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> requestFeaturedListing() async {
    try {
      final response = await _withRetry(
        () => _dio.post(ApiConstants.marketplaceFeaturedRequest, data: {}),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> uploadCertificate(
      Map<String, dynamic> data) async {
    try {
      final response = await _withRetry(
        () => _dio.post(ApiConstants.marketplaceCertificates, data: data),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getCertificates({String? professionalId}) async {
    try {
      final suffix = professionalId != null && professionalId.isNotEmpty
          ? '/$professionalId'
          : '';
      final response = await _withRetry(
        () => _dio.get('${ApiConstants.marketplaceCertificates}$suffix'),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── GEOLOCATION ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNearbyProfessionalsByLocation({
    required double lat,
    required double lng,
    double radiusKm = 20,
    String? serviceType,
    double? minRating,
    double? maxPrice,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.nearbyByLocation,
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radiusKm': radiusKm,
          if (serviceType != null) 'serviceType': serviceType,
          if (minRating != null) 'minRating': minRating,
          if (maxPrice != null) 'maxPrice': maxPrice,
        },
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getProfessionalLocation(String bookingId) async {
    try {
      final response = await _dio.post(
        ApiConstants.professionalLocation,
        data: {'bookingId': bookingId},
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> proposeCounterBid({
    required String bookingId,
    required double counterPrice,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.counterBooking}/$bookingId/counter',
        data: {'counterPrice': counterPrice},
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> validateProfile() async {
    try {
      final response = await _dio.post(ApiConstants.validateProfile);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resetTestData() async {
    try {
      final response = await _dio.post(ApiConstants.resetTestData);
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateProfessionalLocation({
    required double lat,
    required double lng,
    String? address,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.updateLocation,
        data: {
          'lat': lat,
          'lng': lng,
          if (address != null) 'address': address,
        },
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── ADMIN ────────────────────────────────────────────────────────────────────

  Options get _adminOptions => Options(
        sendTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 75),
      );

  Future<Map<String, dynamic>> adminLogin(String username) async {
    try {
      final response = await _withRetry(
        () => _dio.post(
          ApiConstants.adminLogin,
          data: {'username': username},
          options: _adminOptions,
        ),
      );
      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        final token = map['data']?['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await setBackendToken(token);
        }
      }
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.adminStats, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminProfessionals() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.adminProfessionals, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminCustomers() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.adminCustomers, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminBookings() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.adminBookings, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminTransactions() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.adminTransactions, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminComplaints() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.adminComplaints, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateAdminComplaint(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _withRetry(
        () => _dio.patch('${ApiConstants.adminComplaints}/$id',
            data: data, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteAdminComplaint(String id) async {
    try {
      final response = await _withRetry(
        () => _dio.delete('${ApiConstants.adminComplaints}/$id',
            options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminMarketplace() async {
    try {
      final response = await _withRetry(
        () => _dio.get(ApiConstants.adminMarketplace, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateCleanupSettings(int hours) async {
    try {
      final response = await _withRetry(
        () => _dio.patch(ApiConstants.adminCleanupSettings,
            data: {'hours': hours}, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteAdminUser(String uid) async {
    try {
      final response = await _withRetry(
        () => _dio.delete('${ApiConstants.adminUsers}/$uid',
            options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyAdminUser(
    String uid, {
    bool verified = true,
    bool? isActive,
  }) async {
    try {
      final response = await _withRetry(
        () => _dio.patch('${ApiConstants.adminUsers}/$uid/verify',
            data: {
              'verified': verified,
              if (isActive != null) 'isActive': isActive,
            },
            options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createAdminUser(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _withRetry(
        () => _dio.post(ApiConstants.adminUsers,
            data: data, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateAdminProfessional(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _withRetry(
        () => _dio.patch('${ApiConstants.adminProfessionals}/$uid',
            data: data, options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdminProfessionalReviews(String uid) async {
    try {
      final response = await _withRetry(
        () => _dio.get('${ApiConstants.adminProfessionals}/$uid/reviews',
            options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteAdminProfessionalReview(
    String uid,
    String reviewId,
  ) async {
    try {
      final response = await _withRetry(
        () => _dio.delete(
            '${ApiConstants.adminProfessionals}/$uid/reviews/$reviewId',
            options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteAdminBooking(String id) async {
    try {
      final response = await _withRetry(
        () => _dio.delete('${ApiConstants.adminBookings}/$id',
            options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> clearAdminData() async {
    try {
      final response = await _withRetry(
        () => _dio.delete('${ApiConstants.adminUsers}/clear-all',
            options: _adminOptions),
      );
      return response.data;
    } catch (e) {
      return _handleError(e);
    }
  }
}
