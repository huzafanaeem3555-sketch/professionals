import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AppFeatureGuideScreen extends StatelessWidget {
  const AppFeatureGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('HirePro Guide'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GuideHero(),
          SizedBox(height: 14),
          _GuideSection(
            title: '👤 For Customers',
            items: [
              '🔎 Search nearby professionals by service, area, rating, and distance.',
              '🤖 Use AI Estimator to understand the service type, price range, urgency, and needed material.',
              '⚡ Use Need Now for urgent jobs and alert nearby available professionals.',
              '📝 Post a job, receive offers, compare prices, and contact professionals on WhatsApp or call.',
              '⭐ Save favorite professionals, give ratings, submit complaints, and rebook trusted pros.',
            ],
          ),
          _GuideSection(
            title: '🛠️ For Professionals',
            items: [
              '📋 Build and edit a full profile with services, area, packages, certificates, and availability.',
              '💼 Browse customer jobs, send offers, negotiate price, and contact customers directly.',
              '📊 Track contacts, jobs, ranking, service packages, and growth analytics from the dashboard.',
              '🏅 Request Featured, Sponsored, or Premium placement to appear higher in listings.',
            ],
          ),
          _GuideSection(
            title: '💎 Paid Growth',
            items: [
              '🥉 Basic Plan: profile boost and paid verification support.',
              '🥈 Featured Plan: featured badge and higher category placement.',
              '🥇 Premium Plan: top listing, sponsored category visibility, and advanced analytics.',
              '📱 To activate a monthly plan, contact admin on WhatsApp: 03345555362.',
            ],
          ),
          _GuideSection(
            title: '🛡️ Safety & Admin',
            items: [
              '✅ Female customer and professional accounts stay pending until admin verification.',
              '🚫 Male users do not see female-only profiles, and female users do not see male-only profiles.',
              '📣 Notifications are sent for jobs, offers, contacts, verification, bookings, and ratings.',
              '🧾 Admin can review users, complaints, sponsored plans, top listings, and app activity.',
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideHero extends StatelessWidget {
  const _GuideHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HirePro helps customers find trusted professionals fast.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Search, post jobs, compare offers, contact on WhatsApp, rate work, and grow professional profiles with paid plans.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _GuideSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
