import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../models/booking_model.dart';
import 'booking_screen.dart';
import 'booking_tracking_screen.dart';
import 'customer_booking_detail.dart';
import 'package:url_launcher/url_launcher.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseDatabase.instance.ref();
  final _firebase = FirebaseService();

  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String _customerId = '';
  StreamSubscription<DatabaseEvent>? _sub;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _customerId = await StorageService.getUid() ?? '';
    _sub?.cancel();

    _sub = _db
        .child('bookings')
        .orderByChild('customerId')
        .equalTo(_customerId)
        .onValue
        .listen((event) async {
      final list = <Map<String, dynamic>>[];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        for (final entry in map.entries) {
          final b = Map<String, dynamic>.from(entry.value as Map);
          b['bookingId'] = entry.key;

          final status = b['status']?.toString() ?? '';
          final canReveal =
              ['confirmed', 'in_progress', 'completed'].contains(status);
          final proId = b['professionalId']?.toString() ??
              b['professionalPhone']?.toString() ??
              '';
          if (proId.isNotEmpty) {
            final pro = await _firebase.getProfessionalById(proId) ??
                await _firebase.getProfessionalByPhone(proId);
            if (pro != null) {
              b['professionalName'] = pro['name'] ?? 'Professional';
              b['professionalServices'] = pro['services'];
              b['professionalRating'] = pro['rating'];
              if (canReveal) {
                b['professionalPhone'] ??= pro['phone'] ?? pro['phoneNumber'];
                b['professionalLocation'] ??= pro['location'];
              }
            }
          }
          list.add(b);
        }
        list.sort(
            (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      }
      if (mounted) {
        setState(() {
          _bookings = list;
          _loading = false;
        });
      }
    });
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking?'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _firebase.cancelBooking(bookingId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled')),
      );
    }
  }

  void _openNegotiation(String bookingId) {
    Navigator.pushNamed(context, '/negotiation',
        arguments: {'bookingId': bookingId});
  }

  void _openChat(Map<String, dynamic> booking) {
    final proId = booking['professionalId']?.toString() ??
        booking['professionalPhone']?.toString() ??
        '';
    final proName = booking['professionalName']?.toString() ?? 'Professional';
    Navigator.pushNamed(context, '/chat', arguments: {
      'otherUserId': proId,
      'otherUserName': proName,
      'bookingId': booking['bookingId'],
    });
  }

  Future<void> _callProfessional(Map<String, dynamic> booking) async {
    final phone = booking['professionalPhone']?.toString() ??
        booking['contactInfo']?['phone']?.toString() ??
        '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openTracking(Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingTrackingScreen(
          bookingId: booking['bookingId']?.toString() ?? '',
          initialBooking: BookingModel.fromMap(booking),
        ),
      ),
    );
  }

  void _rateBooking(Map<String, dynamic> booking) {
    _showRatingDialog(booking);
  }

  void _openBookingDetail(Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerBookingDetailScreen(booking: booking),
      ),
    );
  }

  void _repeatBooking(Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          professionalId: booking['professionalId']?.toString(),
          serviceType: booking['serviceType']?.toString(),
        ),
      ),
    );
  }

  void _showRatingDialog(Map<String, dynamic> booking) async {
    int rating = 5;
    final reviewCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rate Professional',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                booking['professionalName'] ?? 'Professional',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDlgState(() => rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: AppColors.star,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write a review (optional)...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _firebase.rateBooking(
                  booking['bookingId'],
                  rating,
                  reviewCtrl.text.trim().isEmpty
                      ? null
                      : reviewCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your review! ⭐'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeStatuses = [
      'pending',
      'pending_acceptance',
      'confirmed',
      'in_progress',
      'pending_customer_response',
      'pending_professional_response',
    ];
    final active =
        _bookings.where((b) => activeStatuses.contains(b['status'])).toList();
    final done =
        _bookings.where((b) => !activeStatuses.contains(b['status'])).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Active (${active.length})'),
            Tab(text: 'History (${done.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(active, isActive: true),
                _buildList(done, isActive: false),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list, {required bool isActive}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.calendar_today_outlined : Icons.history,
                size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active bookings' : 'No history yet',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Book a professional from the home screen'
                  : 'Completed bookings will appear here',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _BookingCard(
          booking: list[i],
          isActive: isActive,
          onNegotiate: () => _openNegotiation(list[i]['bookingId']),
          onChat: () => _openChat(list[i]),
          onCall: () => _callProfessional(list[i]),
          onTrack: () => _openTracking(list[i]),
          onDetail: () => _openBookingDetail(list[i]),
          onCancel: () => _cancelBooking(list[i]['bookingId']),
          onRate: () => _rateBooking(list[i]),
          onRepeat: () => _repeatBooking(list[i]),
        ),
      ),
    );
  }
}

// ── Booking Card ──────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isActive;
  final VoidCallback onNegotiate;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final VoidCallback onTrack;
  final VoidCallback onDetail;
  final VoidCallback onCancel;
  final VoidCallback onRate;
  final VoidCallback onRepeat;

  const _BookingCard({
    required this.booking,
    required this.isActive,
    required this.onNegotiate,
    required this.onChat,
    required this.onCall,
    required this.onTrack,
    required this.onDetail,
    required this.onCancel,
    required this.onRate,
    required this.onRepeat,
  });

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
      case 'pending_acceptance':
        return 'Awaiting Professional';
      case 'pending_customer_response':
        return '⚡ Review Price Offer';
      case 'pending_professional_response':
        return 'Counter Sent';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
      case 'pending_acceptance':
        return Colors.orange;
      case 'pending_customer_response':
        return AppColors.primary;
      case 'confirmed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] ?? 'pending';
    final service = booking['serviceType'] ?? 'Service';
    final proName = booking['professionalName'] ?? 'Professional';
    final agreedPrice =
        (booking['agreedPrice'] ?? booking['proposedPrice'] ?? 0.0).toDouble();
    final address = booking['address']?.toString() ?? '';
    final proPhone = booking['professionalPhone']?.toString() ?? '';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled' || status == 'rejected';
    final needsNegotiation = status == 'pending_customer_response';
    final isConfirmed = status == 'confirmed';
    final isInProgress = status == 'in_progress';
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Status header bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                  bottom: BorderSide(color: statusColor.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: statusColor),
                ),
                const Spacer(),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pro info row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        proName.isNotEmpty ? proName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(proName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary)),
                          Text(service,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    if (agreedPrice > 0)
                      Text(
                        'Rs. ${agreedPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary),
                      ),
                  ],
                ),

                if (address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(address,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                if (proPhone.isNotEmpty &&
                    (isConfirmed || isInProgress || isCompleted)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.phone,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        proPhone,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],

                // Action buttons
                if (!isCancelled) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (needsNegotiation)
                        _actionButton(
                          '⚡ Review Offer',
                          AppColors.primary,
                          onNegotiate,
                          filled: true,
                        ),
                      if (isConfirmed || isInProgress || isCompleted)
                        _actionButton(
                          '💬 Chat',
                          AppColors.primary,
                          onChat,
                        ),
                      if ((isConfirmed || isInProgress) && proPhone.isNotEmpty)
                        _actionButton(
                          '📞 Call',
                          AppColors.success,
                          onCall,
                          filled: true,
                        ),
                      if (isConfirmed || isInProgress)
                        _actionButton(
                          'Track',
                          const Color(0xFF00BCD4),
                          onTrack,
                        ),
                      if (isInProgress)
                        _actionButton(
                          'Details',
                          AppColors.primary,
                          onDetail,
                        ),
                      if (isCompleted && (booking['customerRating'] == null))
                        _actionButton('⭐ Rate', AppColors.star, onRate),
                      if (isCompleted)
                        _actionButton(
                          'Repeat',
                          AppColors.primary,
                          onRepeat,
                          filled: true,
                        ),
                      if (isActive &&
                          !isCompleted &&
                          !isConfirmed &&
                          !isInProgress)
                        _actionButton(
                          'Cancel',
                          AppColors.error,
                          onCancel,
                          isOutline: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap,
      {bool filled = false, bool isOutline = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: filled
              ? color
              : (isOutline ? Colors.transparent : color.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(10),
          border: isOutline ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
