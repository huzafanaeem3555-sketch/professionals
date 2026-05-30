import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _saving = false;

  bool _isProfessionalProfileComplete(Map<String, dynamic> proMap) {
    final hasName = (proMap['name']?.toString().trim().isNotEmpty ?? false);
    final services = proMap['services'];
    final customServices = proMap['customServices'];
    final hasServices = (services is List && services.isNotEmpty) ||
        (customServices is List && customServices.isNotEmpty);
    final location = proMap['location'];
    final hasLocation = location is Map &&
        location['lat'] != null &&
        location['lng'] != null &&
        ((location['lat'] as num).toDouble() != 0 ||
            (location['lng'] as num).toDouble() != 0);
    return hasName && hasServices && hasLocation;
  }

  Future<void> _selectRole(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = user.uid;

      // 1. Save role to SharedPreferences
      await StorageService.setRole(role);

      // 2. Save role to Firebase Realtime Database users/{uid}/role
      await FirebaseDatabase.instance.ref().child('users/$uid/role').set(role);

      // 3. Save role via backend API
      try {
        await ApiService().setRole(role);
      } catch (apiErr) {
        debugPrint('Backend setRole error (continuing anyway): $apiErr');
      }

      if (!mounted) return;

      if (role == 'customer') {
        await StorageService.getCustomerId();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/customer-home');
      } else {
        // Professional flow
        // Check if professional details are saved in professionals node
        final proSnap = await FirebaseDatabase.instance
            .ref()
            .child('professionals/$uid')
            .get();
        if (!mounted) return;

        if (!mounted) return;
        if (proSnap.exists) {
          final proMap = Map<String, dynamic>.from(proSnap.value as Map);
          final phone = proMap['phoneNumber']?.toString();
          if (phone != null && phone.isNotEmpty) {
            await StorageService.setProfessionalPhone(phone);
          }
          if (!mounted) return;
          if (_isProfessionalProfileComplete(proMap)) {
            Navigator.pushReplacementNamed(context, '/professional-home');
          } else {
            Navigator.pushReplacementNamed(context, '/professional-setup');
          }
        } else {
          Navigator.pushReplacementNamed(context, '/professional-setup');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save role: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.handyman, size: 72, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please select your role to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const Spacer(),
              if (_saving)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: () => _selectRole('customer'),
                  icon: const Icon(Icons.person_search, size: 22),
                  label: const Text(
                    'I am a Customer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _selectRole('professional'),
                  icon: const Icon(Icons.engineering, size: 22),
                  label: const Text(
                    'I am a Professional',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side:
                        const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
