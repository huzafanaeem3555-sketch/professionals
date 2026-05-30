// ignore_for_file: unnecessary_null_comparison, unnecessary_non_null_assertion, invalid_null_aware_operator, dead_null_aware_expression
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../providers/professional_provider.dart';
import '../models/professional_model.dart';
import '../utils/constants.dart';
import '../widgets/map_card.dart';
import '../utils/contact_actions.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  final String uid;
  const ProfessionalProfileScreen({super.key, required this.uid});

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfessionalProvider>().loadProfile(widget.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfessionalProvider>();
    final pro = provider.selectedProfessional;
    final isLoading = provider.isLoading;

    if (isLoading && pro == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (pro == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Professional not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        backgroundImage: pro.photoURL.isNotEmpty
                            ? NetworkImage(pro.photoURL)
                            : null,
                        child: pro.photoURL.isEmpty
                            ? Text(
                                pro.name.isNotEmpty
                                    ? pro.name[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                    fontSize: 36, color: AppColors.primary),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pro.name.isNotEmpty ? pro.name : 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star,
                              color: AppColors.star, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${pro.ratingText} (${pro.totalRatings ?? 0} reviews)',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pro.isAvailableNow
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                pro.isAvailableNow ? Colors.green : Colors.grey,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: pro.isAvailableNow
                                    ? Colors.green
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              pro.isAvailableNow ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: pro.isAvailableNow
                                    ? Colors.green
                                    : Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      value: '${pro.completedJobs}',
                      label: 'Jobs Done',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      value: '${pro.experienceYears}yr',
                      label: 'Experience',
                      icon: Icons.work,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      value: pro.distanceText,
                      label: 'Distance',
                      icon: Icons.location_on,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => _showRatingDialog(context, pro),
                icon: const Icon(Icons.star_rate_rounded),
                label: const Text(
                  'Rate & Review',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // About
          if (pro.description.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'About',
                icon: Icons.person,
                child: Text(
                  pro.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
            ),

          // Services
          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Expertise',
              icon: Icons.category,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pro.serviceTypes.map((s) {
                  final cat = ServiceLabels.labelFor(s);
                  return Chip(
                    label: Text('${cat['icon']} ${cat['name']}'),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                  );
                }).toList(),
              ),
            ),
          ),

          if (pro.brochureImages.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Brochure',
                icon: Icons.image_outlined,
                child: SizedBox(
                  height: 170,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: pro.brochureImages.length,
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () => _showImagePreview(
                        context,
                        pro.brochureImages[i],
                        'Brochure',
                      ),
                      child: Container(
                        width: 230,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surfaceLight,
                          image: DecorationImage(
                            image: NetworkImage(pro.brochureImages[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Portfolio
          if (pro.portfolio.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Portfolio',
                icon: Icons.photo_library,
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: pro.portfolio.length,
                    itemBuilder: (ctx, i) => Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(pro.portfolio[i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: _SectionCard(
              title: 'Feedback',
              icon: Icons.reviews,
              child: _buildFeedbackList(pro),
            ),
          ),

          if (pro.lat != 0 && pro.lng != 0)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.map, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref('professionals/${widget.uid}')
                        .onValue,
                    builder: (context, snapshot) {
                      var lat = pro.lat ?? 0;
                      var lng = pro.lng ?? 0;
                      var subtitle = pro.address ?? 'Service Area';

                      final value = snapshot.data?.snapshot.value;
                      if (value is Map) {
                        final userData = Map<String, dynamic>.from(value);
                        final location = userData['location'];
                        if (location is Map) {
                          final rawLat = location['lat'];
                          final rawLng = location['lng'];
                          if (rawLat is num) lat = rawLat.toDouble();
                          if (rawLng is num) lng = rawLng.toDouble();
                          final address = location['address']?.toString() ?? '';
                          if (address.isNotEmpty) subtitle = address;
                        } else {
                          final rawLat = userData['lat'];
                          final rawLng = userData['lng'];
                          if (rawLat is num) lat = rawLat.toDouble();
                          if (rawLng is num) lng = rawLng.toDouble();
                        }
                        subtitle =
                            userData['address']?.toString().isNotEmpty == true
                                ? userData['address'].toString()
                                : subtitle;
                      }

                      return MapCard(
                        lat: lat,
                        lng: lng,
                        title: pro.name.isNotEmpty
                            ? pro.name
                            : 'Professional Location',
                        subtitle: subtitle,
                        height: 200,
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pro.isAvailableNow
                      ? () =>
                          _contactProfessional(context, pro, ContactMethod.call)
                      : null,
                  icon: const Icon(Icons.call),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Call Now', style: TextStyle(fontSize: 15)),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(
                      color: pro.isAvailableNow
                          ? AppColors.primary
                          : Colors.grey[400]!,
                    ),
                    foregroundColor:
                        pro.isAvailableNow ? AppColors.primary : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: pro.isAvailableNow
                      ? () => _contactProfessional(
                          context, pro, ContactMethod.whatsapp)
                      : null,
                  icon: const Icon(Icons.chat),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('WhatsApp', style: TextStyle(fontSize: 15)),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    backgroundColor: pro.isAvailableNow
                        ? const Color(0xFF25D366)
                        : Colors.grey[400],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRatingDialog(
    BuildContext context,
    ProfessionalModel pro,
  ) async {
    final customerId = await StorageService.getUid();
    if (customerId == null || customerId.isEmpty || !context.mounted) return;
    final userDetails = await StorageService.getUserDetails();
    final customerName = userDetails['name']?.trim().isNotEmpty == true
        ? userDetails['name']!.trim()
        : 'Customer';

    int rating = 5;
    final reviewCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Rate Professional'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => setDlgState(() => rating = i + 1),
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: AppColors.star,
                      size: 30,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: reviewCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Feedback',
                  hintText: 'Share your experience',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    final review = reviewCtrl.text.trim();
    reviewCtrl.dispose();
    if (submitted != true) return;

    final reviewsRef =
        FirebaseDatabase.instance.ref('professionalReviews/${pro.uid}');
    final reviewsSnap =
        await reviewsRef.get().timeout(const Duration(seconds: 10));
    final reviewRatings = <int>[];
    if (reviewsSnap.value is Map) {
      final reviewMap = Map<String, dynamic>.from(reviewsSnap.value as Map);
      for (final entry in reviewMap.entries) {
        if (entry.key == customerId || entry.value is! Map) continue;
        final data = Map<String, dynamic>.from(entry.value as Map);
        final value = data['rating'];
        if (value is num && value > 0) reviewRatings.add(value.round());
      }
    }
    reviewRatings.add(rating);
    final totalRatings = reviewRatings.length;
    final average =
        reviewRatings.fold<int>(0, (sum, value) => sum + value) / totalRatings;

    await reviewsRef.child(customerId).set({
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'review': review,
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });
    await FirebaseDatabase.instance.ref('professionals/${pro.uid}').update({
      'rating': double.parse(average.toStringAsFixed(2)),
      'totalRatings': totalRatings,
      'updatedAt': ServerValue.timestamp,
    });

    if (!context.mounted) return;
    await context.read<ProfessionalProvider>().loadProfile(pro.uid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks, your feedback was added.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildFeedbackList(ProfessionalModel pro) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('professionalReviews/${pro.uid}')
          .orderByChild('updatedAt')
          .onValue,
      builder: (context, snapshot) {
        var reviews = List<ProfessionalReview>.from(pro.reviews);
        final value = snapshot.data?.snapshot.value;
        if (value is Map) {
          reviews = value.entries
              .where((entry) => entry.value is Map)
              .map((entry) {
                final data = Map<String, dynamic>.from(entry.value as Map);
                return ProfessionalReview.fromJson({
                  'bookingId': entry.key,
                  'customerName': data['customerName'] ?? 'Customer',
                  'rating': data['rating'] ?? 0,
                  'review': data['review'] ?? '',
                  'createdAt': data['updatedAt'] ?? data['createdAt'] ?? 0,
                });
              })
              .where((review) => review.rating > 0)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        if (reviews.isEmpty) {
          return const Text(
            'No feedback yet',
            style: TextStyle(color: AppColors.textSecondary),
          );
        }

        return Column(
          children: reviews.map((review) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_border,
                            color: AppColors.star,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (review.review.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      review.review,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, String url, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Image unavailable'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contactProfessional(
    BuildContext context,
    ProfessionalModel pro,
    ContactMethod method,
  ) async {
    final customerPhone = await _ensureCustomerPhone(context);
    if (customerPhone == null || customerPhone.isEmpty) return;
    final contactLocation = await _resolveCustomerContactLocation(context);
    final customerAddress = contactLocation['address'] as String;
    final customerLocation =
        Map<String, dynamic>.from(contactLocation['location'] as Map);

    final serviceType =
        pro.serviceTypes.isNotEmpty ? pro.serviceTypes.first : 'general';
    final customerId = await StorageService.getUid() ?? '';
    final userDetails = await StorageService.getUserDetails();
    final customerName = userDetails['name']?.trim().isNotEmpty == true
        ? userDetails['name']!.trim()
        : 'Customer';
    var leadSaved = await FirebaseService().saveContactLead(
      professionalId: pro.uid,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      serviceType: serviceType,
      contactMethod: method.name,
      customerLocation: customerLocation,
    );
    if (!leadSaved) {
      final fallback = await ApiService().saveContactLeadPublic(
        targetUserId: pro.uid,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        serviceType: serviceType,
        contactMethod: method.name,
        customerLocation: customerLocation,
      );
      if (fallback['success'] == true) {
        leadSaved = true;
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not show your details to professional. Check backend/Firebase.'),
          ),
        );
        return;
      }
    }

    final uri = contactUriFor(
      method: method,
      phoneNumber: pro.phone,
      message:
          'Assalam-o-Alaikum, I found your profile on Service Connect and want to contact you about ${serviceType.replaceAll('_', ' ')}.',
    );
    final launched = await launchContactUri(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open contact app')),
      );
      return;
    }

    final notifyResult = await ApiService().sendContactNotification(
      targetUserId: pro.uid,
      title: method == ContactMethod.call
          ? 'Customer called you'
          : 'Customer sent WhatsApp message',
      body:
          '$customerName contacted you for ${serviceType.replaceAll('_', ' ')}. Phone: $customerPhone',
      contactMethod: method.name,
      type: method == ContactMethod.call ? 'direct_call' : 'direct_whatsapp',
      serviceType: serviceType,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      customerLocation: customerLocation,
      leadAlreadySaved: leadSaved,
    );
    if (notifyResult['success'] != true) {
      unawaited(ApiService().saveContactLeadPublic(
        targetUserId: pro.uid,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        serviceType: serviceType,
        contactMethod: method.name,
        customerLocation: customerLocation,
        leadAlreadySaved: leadSaved,
      ));
    }
  }

  Future<Map<String, dynamic>> _resolveCustomerContactLocation(
    BuildContext context,
  ) async {
    final uid = await StorageService.getUid();
    var lat = 0.0;
    var lng = 0.0;
    var address = '';

    try {
      final position =
          await LocationService().getCurrentPosition(maxAttempts: 1);
      lat = position.latitude;
      lng = position.longitude;
      address = await LocationService().getAddressFromCoordinates(lat, lng);
    } catch (_) {
      try {
        if (uid != null && uid.isNotEmpty) {
          final snap = await FirebaseDatabase.instance
              .ref('users/$uid')
              .get()
              .timeout(const Duration(seconds: 5));
          if (snap.value is Map) {
            final data = Map<String, dynamic>.from(snap.value as Map);
            final storedLocation = data['location'];
            address = (data['address'] ?? '').toString().trim();
            if (storedLocation is Map) {
              address =
                  (storedLocation['address'] ?? address).toString().trim();
              final rawLat = storedLocation['lat'];
              final rawLng = storedLocation['lng'];
              if (rawLat is num && rawLng is num) {
                lat = rawLat.toDouble();
                lng = rawLng.toDouble();
              }
            }
          }
        }
      } catch (_) {}
    }

    if (address.isEmpty && (lat != 0 || lng != 0)) {
      address =
          'GPS location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
    if (address.isEmpty) address = 'Location unavailable';

    final location = {'lat': lat, 'lng': lng, 'address': address};
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseDatabase.instance.ref('users/$uid').update({
          'address': address,
          'location': location,
          '_updatedAt': DateTime.now().millisecondsSinceEpoch,
        }).timeout(const Duration(seconds: 8), onTimeout: () {});
      } catch (_) {}
    }
    return {'address': address, 'location': location};
  }

  Future<String?> _ensureCustomerPhone(BuildContext context) async {
    final uid = await StorageService.getUid();
    if (uid == null || uid.isEmpty || !context.mounted) return null;

    DataSnapshot snap;
    try {
      snap = await FirebaseDatabase.instance
          .ref('users/$uid/phoneNumber')
          .get()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not check your phone number. Try again.')),
        );
      }
      return null;
    }
    final existing = snap.value?.toString().trim() ?? '';
    if (existing.isNotEmpty) return existing;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '03XXXXXXXXX'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              final valid = RegExp(r'^(03\d{9}|3\d{9})$')
                  .hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''));
              if (valid) Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    final value = result?.trim() ?? '';
    if (value.isEmpty) return null;
    try {
      await FirebaseDatabase.instance.ref('users/$uid').update({
        'phoneNumber': value,
        '_updatedAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 8));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save phone number. Try again.')),
        );
      }
      return null;
    }
    return value;
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }
}
