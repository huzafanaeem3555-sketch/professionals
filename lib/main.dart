import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import 'utils/app_navigator.dart';
import 'utils/app_theme.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/professional_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/location_tracking_provider.dart';
import 'services/notification_service.dart'; // ADD THIS IMPORT
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/role_selection_screen.dart';
import 'screens/customer_home_screen.dart';
import 'screens/professional_setup_screen.dart';
import 'screens/professional_dashboard.dart';
import 'screens/professional_profile_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/negotiation_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/notification_inbox_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    }
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    } catch (_) {}
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Initialize Notification Service
  try {
    await NotificationService.initialize();
    debugPrint('✅ Notification Service initialized');
  } catch (e) {
    debugPrint('❌ Notification Service error: $e');
  }

  runApp(const ServiceConnectApp());
}

class ServiceConnectApp extends StatelessWidget {
  const ServiceConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ProfessionalProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => LocationTrackingProvider()),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'Professionals',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: '/',
        routes: {
          '/': (ctx) => const SplashScreen(),
          '/login': (ctx) => const LoginScreen(),
          '/role-selection': (ctx) => const RoleSelectionScreen(),
          '/customer-home': (ctx) => const CustomerHomeScreen(),
          '/professional-setup': (ctx) => const ProfessionalSetupScreen(),
          '/professional-home': (ctx) => const ProfessionalDashboard(),
          '/wallet': (ctx) => const WalletScreen(),
          '/notifications': (ctx) => const NotificationInboxScreen(),
          '/admin-login': (ctx) => const AdminLoginScreen(),
          '/admin-dashboard': (ctx) => const AdminDashboard(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/chat') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUserId: args?['otherUserId']?.toString() ?? '',
                otherUserName: args?['otherUserName']?.toString() ?? 'User',
                otherUserPhoto: args?['otherUserPhoto']?.toString(),
                bookingId: args?['bookingId']?.toString(),
              ),
            );
          }
          if (settings.name == '/negotiation') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => NegotiationScreen(
                bookingId: args?['bookingId']?.toString() ?? '',
              ),
            );
          }
          if (settings.name == '/professional-profile') {
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ProfessionalProfileScreen(
                uid: args?['uid']?.toString() ?? '',
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
