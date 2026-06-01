import 'package:flutter/material.dart';
import '../models/professional_model.dart';
import '../utils/constants.dart';

class ProfessionalCard extends StatelessWidget {
  final ProfessionalModel professional;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onViewProfile;

  const ProfessionalCard({
    super.key,
    required this.professional,
    this.onCall,
    this.onWhatsApp,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          const BoxShadow(
            color: Color(0x0F000000), // ~6% opacity black
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: onViewProfile,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: professional.photoURL.isNotEmpty
                            ? NetworkImage(professional.photoURL)
                            : null,
                        child: professional.photoURL.isEmpty
                            ? Text(
                                professional.name.isNotEmpty
                                    ? professional.name[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: professional.isAvailableNow
                                ? AppColors.available
                                : AppColors.unavailable,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                professional.name.isNotEmpty
                                    ? professional.name
                                    : 'Unknown',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (professional.isVerified)
                              const Icon(Icons.verified,
                                  color: AppColors.primary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Services
                        Text(
                          professional.serviceTypes.take(3).map((s) {
                            final cat = AppStrings.serviceCategories.firstWhere(
                                (c) => c['key'] == s,
                                orElse: () => {'name': s, 'icon': 'SV'});
                            return '${cat['icon']} ${cat['name']}';
                          }).join('  '),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            // Rating
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: AppColors.star, size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  professional.ratingText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  ' (${professional.totalRatings})',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Distance
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: AppColors.textSecondary, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  professional.distanceText,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Completed jobs
                        Text(
                          '${professional.completedJobs} jobs completed | ${professional.experienceYears}yr exp',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewProfile,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
