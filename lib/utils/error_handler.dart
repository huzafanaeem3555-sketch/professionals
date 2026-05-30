import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Global exception handling utility with proper logging and user-friendly messages
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Convert any exception to a user-friendly error message
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';
    
    final msg = error.toString();
    
    // Network errors
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Connection failed. Check your internet connection.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('Connection reset')) {
      return 'Connection lost. Please try again.';
    }
    
    // Firebase errors
    if (msg.contains('user-not-found')) {
      return 'No account found with this email.';
    }
    if (msg.contains('invalid-credential') || msg.contains('wrong-password')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered.';
    }
    if (msg.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (msg.contains('network-request-failed')) {
      return 'Network error. Check your internet connection.';
    }
    
    // Generic errors
    if (msg.contains('Exception: ')) {
      return msg.replaceAll('Exception: ', '');
    }
    
    return msg.length > 150 ? '${msg.substring(0, 150)}...' : msg;
  }

  /// Handle DioException with detailed logging
  static Map<String, dynamic> handleDioException(DioException error) {
    if (kDebugMode) {
      debugPrint('🔴 Dio Error: ${error.type}');
      debugPrint('   URL: ${error.requestOptions.path}');
      debugPrint('   Status: ${error.response?.statusCode}');
      debugPrint('   Message: ${error.message}');
      if (error.response?.data != null) {
        debugPrint('   Response: ${error.response?.data}');
      }
    }
    
    String message = 'Network error';
    
    if (error.response != null) {
      message = error.response?.data['message'] ?? 'Server error';
      if (error.response?.statusCode == 401) {
        message = 'Session expired. Please login again.';
      } else if (error.response?.statusCode == 403) {
        message = 'You do not have permission to perform this action.';
      } else if (error.response?.statusCode == 404) {
        message = 'Resource not found.';
      } else if (error.response?.statusCode == 500) {
        message = 'Server error. Please try again later.';
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout. Check your internet.';
    } else if (error.type == DioExceptionType.receiveTimeout) {
      message = 'Response timeout. Please try again.';
    } else if (error.type == DioExceptionType.sendTimeout) {
      message = 'Request timeout. Please try again.';
    }
    
    return {
      'success': false,
      'message': message,
      'statusCode': error.response?.statusCode,
    };
  }

  /// Log error with proper formatting
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ ERROR in $context: ${error.toString()}');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Log info message
  static void logInfo(String message) {
    if (kDebugMode) debugPrint('ℹ️ INFO: $message');
  }

  /// Log success message
  static void logSuccess(String message) {
    if (kDebugMode) debugPrint('✅ SUCCESS: $message');
  }

  /// Log warning message
  static void logWarning(String message) {
    if (kDebugMode) debugPrint('⚠️ WARNING: $message');
  }
}

