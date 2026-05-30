import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/constants.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';

const String _kGoogleWebClientId =
    '581660506706-rle7rsp19n1hc7l04tgp2dq53j0ijhb3.apps.googleusercontent.com';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _kGoogleWebClientId,
  );

  User? getCurrentUser() => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<T> _withStepTimeout<T>(
    Future<T> future,
    Duration timeout,
    String message,
  ) {
    return future.timeout(timeout, onTimeout: () => throw Exception(message));
  }

  Future<User?> signInWithGoogle() async {
    if (kDebugMode) debugPrint('[Auth] Google account picker');
    final googleUser = await _withStepTimeout(
      _googleSignIn.signIn(),
      const Duration(seconds: 45),
      'Google account picker timed out. Please try again.',
    );
    if (googleUser == null) return null;

    final googleAuth = await _withStepTimeout(
      googleUser.authentication,
      const Duration(seconds: 25),
      'Google authentication timed out. Please check internet and try again.',
    );

    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google idToken is empty. Add SHA-1 in Firebase Console and re-download google-services.json.',
      );
    }

    if (kDebugMode) debugPrint('[Auth] Backend login ${ApiConstants.baseUrl}');
    final apiRes = await _withStepTimeout(
      ApiService().loginWithGoogle(idToken),
      const Duration(seconds: 25),
      'Backend login timed out at ${ApiConstants.baseUrl}.',
    );
    if (apiRes['success'] != true) {
      throw Exception(apiRes['message']?.toString() ?? 'Google login failed.');
    }

    final data = apiRes['data'];
    if (data is! Map) throw Exception('Invalid backend login response.');

    final backendToken = data['token']?.toString();
    if (backendToken != null && backendToken.isNotEmpty) {
      await ApiService().setBackendToken(backendToken);
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );

    if (kDebugMode) debugPrint('[Auth] Firebase sign-in');
    final credentialResult = await _withStepTimeout(
      _auth.signInWithCredential(credential),
      const Duration(seconds: 35),
      'Firebase sign-in timed out. Please check internet and try again.',
    );

    final firebaseUser = credentialResult.user;
    if (firebaseUser == null) {
      throw Exception('Firebase Google sign-in returned empty user.');
    }

    await _persistSession(
      firebaseUser: firebaseUser,
      idToken: idToken,
      backendUser:
          data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null,
    );
    await NotificationService.syncTokenForCurrentUser();

    if (kDebugMode) debugPrint('[Auth] Signed in uid=${firebaseUser.uid}');
    return firebaseUser;
  }

  Future<void> _persistSession({
    required User firebaseUser,
    required String idToken,
    Map<String, dynamic>? backendUser,
  }) async {
    final email =
        firebaseUser.email ?? backendUser?['email']?.toString() ?? '';
    final name = firebaseUser.displayName ??
        backendUser?['displayName']?.toString() ??
        backendUser?['name']?.toString() ??
        '';
    final photo =
        firebaseUser.photoURL ?? backendUser?['photoURL']?.toString() ?? '';
    final role = backendUser?['role']?.toString();

    await StorageService.setUid(firebaseUser.uid);
    await StorageService.setIdToken(idToken);
    await StorageService.setUserDetails(
      name: name,
      email: email,
      photo: photo,
      idToken: idToken,
    );
    if (role != null && role.isNotEmpty) {
      await StorageService.setRole(role);
    }

    try {
      await FirebaseDatabase.instance.ref('users/${firebaseUser.uid}').update({
        'uid': firebaseUser.uid,
        'email': email,
        'displayName': name,
        'name': name,
        'photoURL': photo,
        if (role != null && role.isNotEmpty) 'role': role,
        '_updatedAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 8));
    } catch (error) {
      if (kDebugMode) debugPrint('[Auth] RTDB user sync warning: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await ApiService().clearToken();
      await StorageService.clearAll();
    } catch (error) {
      if (kDebugMode) debugPrint('[Auth] signOut warning: $error');
      await StorageService.clearAll();
    }
  }
}
