# 👨‍💻 DEVELOPER GUIDE - ERROR HANDLING & UTILITIES

## 🎯 Overview

This document explains how to use the new **ErrorHandler** utility and best practices for error handling in the Service Connect app.

---

## 📦 ErrorHandler Utility

### Location
```
lib/utils/error_handler.dart
```

### What It Does
Centralizes error handling with:
- User-friendly error messages
- Structured logging
- Exception parsing
- Dio exception handling

---

## 🔧 USAGE EXAMPLES

### 1. Get User-Friendly Error Message
```dart
try {
  // Some operation
} catch (e) {
  final message = ErrorHandler.getErrorMessage(e);
  _setError(message);  // Shows: "Connection failed. Check internet."
}
```

### 2. Handle Dio Exceptions
```dart
import 'package:dio/dio.dart';

try {
  final response = await _dio.post('/api/endpoint');
} catch (e) {
  if (e is DioException) {
    final errorResult = ErrorHandler.handleDioException(e);
    // Returns: { success: false, message: "...", statusCode: 401 }
  }
}
```

### 3. Log Information
```dart
// Log success
ErrorHandler.logSuccess('User authenticated');  // Logs: ✅ SUCCESS: User authenticated

// Log error
ErrorHandler.logError('Auth failed', exception);  // Logs: ❌ ERROR in Auth failed: ...

// Log info
ErrorHandler.logInfo('Fetching user data');  // Logs: ℹ️ INFO: Fetching user data

// Log warning
ErrorHandler.logWarning('Network slow');  // Logs: ⚠️ WARNING: Network slow
```

---

## 🎨 PATTERNS & BEST PRACTICES

### Pattern 1: API Call with Error Handling
```dart
Future<bool> fetchData() async {
  try {
    ErrorHandler.logInfo('Fetching data...');
    final response = await _api.getData();
    
    if (response['success']) {
      ErrorHandler.logSuccess('Data fetched');
      return true;
    } else {
      _setError(response['message']);
      return false;
    }
  } catch (e) {
    _setError(ErrorHandler.getErrorMessage(e));
    ErrorHandler.logError('Fetch failed', e);
    return false;
  }
}
```

### Pattern 2: Authentication with Validation
```dart
Future<bool> signIn(String email, String password) async {
  _setLoading(true);
  try {
    // Validate input
    if (email.isEmpty || password.isEmpty) {
      _setError('Email and password required');
      return false;
    }
    
    // Call API
    final response = await _api.signInWithEmail(email, password);
    
    if (response['success']) {
      ErrorHandler.logSuccess('Sign-in successful: $email');
      return true;
    }
    
    _setError(response['message'] ?? 'Sign-in failed');
    return false;
  } catch (e) {
    _setError(ErrorHandler.getErrorMessage(e));
    ErrorHandler.logError('Sign-in error', e);
    return false;
  } finally {
    _setLoading(false);
  }
}
```

### Pattern 3: Token Management
```dart
Future<void> setToken(String? token) async {
  try {
    if (token != null && token.isNotEmpty) {
      await _prefs.setString('token', token);
      ErrorHandler.logSuccess('Token stored');
    } else {
      await _prefs.remove('token');
      ErrorHandler.logInfo('Token cleared');
    }
  } catch (e) {
    ErrorHandler.logWarning('Failed to manage token: $e');
  }
}
```

---

## 📋 ERROR MESSAGE MAPPING

The ErrorHandler automatically maps common exceptions to user messages:

### Firebase Errors
```
user-not-found           → "No account found with this email."
invalid-credential       → "Invalid email or password."
wrong-password          → "Invalid email or password."
email-already-in-use    → "This email is already registered."
weak-password           → "Password must be at least 6 characters."
invalid-email           → "Please enter a valid email address."
too-many-requests       → "Too many attempts. Try again later."
network-request-failed  → "No internet connection."
```

### Network Errors
```
SocketException         → "Connection failed. Check your internet."
TimeoutException        → "Request timed out. Please try again."
Connection reset        → "Connection lost. Please try again."
```

### HTTP Status Codes
```
401 Unauthorized        → "Session expired. Please login again."
403 Forbidden          → "You do not have permission to perform this action."
404 Not Found          → "Resource not found."
500 Server Error       → "Server error. Please try again later."
```

---

## 🔄 FLOW DIAGRAM

```
Exception Occurs
    ↓
Is it a DioException? 
    ├─ YES → handleDioException()
    │         ├─ Response available? → Extract error from response
    │         ├─ Status code 401? → "Session expired"
    │         ├─ Timeout? → "Request timed out"
    │         └─ Return: { success: false, message, statusCode }
    │
    └─ NO → getErrorMessage()
            ├─ Check for Firebase error codes
            ├─ Check for network error keywords
            ├─ Extract or truncate message
            └─ Return user-friendly message
    ↓
Display to User (via _setError in provider)
```

---

## 🧪 TESTING THE ERROR HANDLER

### Test 1: Network Timeout
```dart
// Simulate by disconnecting internet
try {
  await _api.getData();  // Will timeout
} catch (e) {
  final msg = ErrorHandler.getErrorMessage(e);
  // Should show: "Request timed out. Please try again."
}
```

### Test 2: Invalid Credentials
```dart
try {
  await _api.signInWithEmail('test@example.com', 'wrong');
} catch (e) {
  final msg = ErrorHandler.getErrorMessage(e);
  // Should show: "Invalid email or password."
}
```

### Test 3: Server Error
```dart
try {
  await _api.getData();  // Server returns 500
} catch (e) {
  if (e is DioException) {
    final result = ErrorHandler.handleDioException(e);
    // Should include: "Server error. Please try again later."
  }
}
```

---

## 📊 LOGGING EXAMPLES

### In Console Output:
```
✅ SUCCESS: Session restored: user@example.com
ℹ️ INFO: Fetching user role...
⚠️ WARNING: Failed to store token: FormatException
❌ ERROR in Sign-In failed: Invalid credentials exception

// Only shown in Debug Mode
// In Release builds these are suppressed
```

### Enable/Disable Logging
```dart
// Logging is controlled by kDebugMode
// In main.dart: debugShowCheckedModeBanner = false;
// Logs only show when running with --debug flag

flutter run              // Shows all logs
flutter run --release   // No debug logs
```

---

## 🔐 SECURITY NOTES

### Do's ✅
```
✅ Log user actions (signin, logout, booking creation)
✅ Log API errors (401, 500, timeout)
✅ Log warnings (token expiry, slow network)
✅ Show errors to user (in user-friendly format)
```

### Don'ts ❌
```
❌ Never log passwords
❌ Never log email addresses in errors
❌ Never log full error stack in production
❌ Never show technical errors to users
```

---

## 📈 MONITORING & DEBUGGING

### Check Logs in Flutter
```
# Run with verbose logging
flutter run -v

# In VS Code output panel, search for:
# ✅ SUCCESS:
# ❌ ERROR:
# ⚠️ WARNING:
# ℹ️ INFO:
```

### Common Issues & Solutions

#### Issue: "No token found - session not restored"
```
Cause: First launch or token cleared
Solution: User needs to login
Action: Show login screen (handled automatically)
```

#### Issue: "Failed to store token"
```
Cause: SharedPreferences error
Solution: App continues with Firebase fallback
Action: Log warning, retry on next auth
```

#### Issue: "Request timed out. Please try again."
```
Cause: Poor network, backend slow, or no internet
Solution: User can retry
Action: Implement retry button on error screen
```

---

## 🚀 BEST PRACTICES

### 1. Always Use Try-Catch in Async Functions
```dart
Future<bool> myFunction() async {
  try {
    // Your code here
    return true;
  } catch (e) {
    ErrorHandler.logError('myFunction failed', e);
    return false;
  }
}
```

### 2. Use Structured Logging
```dart
// Good ✅
ErrorHandler.logSuccess('Payment confirmed');

// Avoid ❌
debugPrint('Payment confirmed');
print('✅ ok');
```

### 3. Extract Error Messages Properly
```dart
// Good ✅
_setError(ErrorHandler.getErrorMessage(e));

// Avoid ❌
_setError(e.toString());
_setError(exception.runtimeType.toString());
```

### 4. Keep Error Messages Short
```dart
// Good ✅
"Connection timeout. Check internet."  // 45 chars

// Avoid ❌  
"The socket connection was terminated by the remote host due to a connection timeout error."  // Too long
```

---

## 📚 RELATED FILES

| File | Purpose | Key Methods |
|------|---------|-------------|
| error_handler.dart | Error parsing | getErrorMessage(), handleDioException() |
| api_service.dart | API calls | _handleError() uses ErrorHandler |
| auth_provider.dart | Auth state | Uses ErrorHandler for login/signup |
| booking_provider.dart | Booking logic | Uses ErrorHandler for bookings |

---

## 🔗 INTEGRATION WITH UI

### In Login Screen
```dart
Consumer<AuthProvider>(
  builder: (context, auth, _) {
    return Column(
      children: [
        // ... form fields ...
        
        // Show error message if present
        if (auth.error != null)
          Container(
            color: Colors.red[100],
            padding: EdgeInsets.all(16),
            child: Text(
              auth.error!,  // User-friendly message from ErrorHandler
              style: TextStyle(color: Colors.red[900]),
            ),
          ),
        
        ElevatedButton(
          onPressed: () => auth.signInWithEmail(email, password),
          child: Text('Sign In'),
        ),
      ],
    );
  },
)
```

### In API Calls
```dart
Future<void> loadBookings() async {
  try {
    final response = await _api.getMyBookings();
    if (response['success']) {
      _bookings = response['data'];
    } else {
      _error = response['message'];  // Already user-friendly
    }
  } catch (e) {
    _error = ErrorHandler.getErrorMessage(e);
  }
  notifyListeners();
}
```

---

## ✅ VERIFICATION CHECKLIST

Before using ErrorHandler in new code:

- [ ] Imported `error_handler.dart`
- [ ] All network calls wrapped in try-catch
- [ ] All catch blocks use `ErrorHandler.getErrorMessage()`
- [ ] All success/failure events logged
- [ ] No raw exceptions shown to users
- [ ] No sensitive data logged
- [ ] Error messages tested with UI
- [ ] Tested on real network scenarios

---

## 🎓 LEARNING PATH

1. **Read** this file (you are here)
2. **Review** error_handler.dart source code (150 lines)
3. **Check** how it's used in auth_provider.dart
4. **Test** by breaking network and checking error messages
5. **Implement** in your own new features

---

## 📞 QUICK REFERENCE

```dart
// Get user-friendly error message
ErrorHandler.getErrorMessage(exception)

// Handle Dio-specific errors
ErrorHandler.handleDioException(dioException)

// Log with context labels
ErrorHandler.logSuccess('message')
ErrorHandler.logError('context', exception)
ErrorHandler.logInfo('message')
ErrorHandler.logWarning('message')

// All logging is conditional on kDebugMode
// No logging in release builds
```

---

*Created: May 18, 2026*
*Version: 1.0*
*Status: CURRENT & ACCURATE*

