import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/auth_navigation.dart';
import '../widgets/app_logo.dart';

class GenderVerificationScreen extends StatelessWidget {
  const GenderVerificationScreen({
    super.key,
    required this.role,
  });

  final String role;
  static const String whatsappNumber = '923195682936';

  Future<void> _openWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(
      'Assalam-o-Alaikum, I want to verify my female ${role == 'professional' ? 'professional' : 'customer'} account on Hirepro. I will send my voice note.',
    );
    final uri = Uri.parse('https://wa.me/$whatsappNumber?text=$message');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  Future<void> _checkAgain(BuildContext context) async {
    await AuthNavigation.routeAfterAuth(context);
  }

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: AppLogo(size: 118, padding: 7)),
              const SizedBox(height: 26),
              const Text(
                'Female Account Verification',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please verify your female account by sending a voice note on WhatsApp. Admin will activate your account after confirmation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Text(
                  'WhatsApp: 03195682936',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _openWhatsApp(context),
                icon: const Icon(Icons.chat),
                label: const Text('Open WhatsApp Verification'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _checkAgain(context),
                icon: const Icon(Icons.refresh),
                label: const Text('I am verified, check again'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Go back to login'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
