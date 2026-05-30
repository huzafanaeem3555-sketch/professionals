import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../utils/auth_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minSplashDuration = Duration(seconds: 3);
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final startTime = DateTime.now();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Firebase initialization timed out');
          },
        );
      }

      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService().initializeToken().timeout(
              const Duration(seconds: 5),
              onTimeout: () {},
            );
      }

      final elapsed = DateTime.now().difference(startTime);
      final remaining = _minSplashDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final savedToken = await StorageService.getToken();
        final savedUid = await StorageService.getUid();
        if (savedToken == null ||
            savedToken.isEmpty ||
            savedUid == null ||
            savedUid.isEmpty) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          await NotificationService.syncTokenForCurrentUser();
          await AuthNavigation.routeAfterAuth(context);
          return;
        }
        final freshIdToken = await currentUser.getIdToken(true) ?? '';
        if (freshIdToken.isNotEmpty) {
          final Map<String, dynamic> syncResult = await ApiService().signInWithToken(freshIdToken).timeout(
            const Duration(seconds: 15),
            onTimeout: () => <String, dynamic>{'success': false},
          );
          if (syncResult['success'] == true) {
            final data = syncResult['data'];
            if (data is Map) {
              final backendToken = data['token']?.toString();
              if (backendToken != null && backendToken.isNotEmpty) {
                await ApiService().setBackendToken(backendToken);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Session sync warning: $e');
      }

      await NotificationService.syncTokenForCurrentUser();
      await AuthNavigation.routeAfterAuth(context);
    } on TimeoutException catch (e) {
      debugPrint('Splash timeout: $e');
      await _goLoginSafe(startTime);
    } on FirebaseException catch (e) {
      debugPrint('Splash Firebase error: ${e.code} ${e.message}');
      await _goLoginSafe(startTime);
    } catch (e) {
      debugPrint('Splash bootstrap error: $e');
      if (!mounted) return;
      final savedToken = await StorageService.getToken();
      final savedUid = await StorageService.getUid();
      if ((savedToken != null && savedToken.isNotEmpty) ||
          (savedUid != null && savedUid.isNotEmpty)) {
        await AuthNavigation.routeAfterAuth(context);
      } else {
        await _goLoginSafe(startTime);
      }
    }
  }

  Future<void> _goLoginSafe(DateTime startTime) async {
    final elapsed = DateTime.now().difference(startTime);
    final remaining = _minSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(scale: _scaleAnimation, child: child),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trusted Service Experts',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.86),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
