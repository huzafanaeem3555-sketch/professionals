import 'package:flutter/material.dart';
import '../utils/snackbar_helper.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';

class NegotiationScreen extends StatefulWidget {
  final String bookingId;

  const NegotiationScreen({super.key, this.bookingId = ''});

  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends State<NegotiationScreen>
    with TickerProviderStateMixin {
  final _priceController = TextEditingController();
  final _db = FirebaseDatabase.instance.ref();
  final _firebase = FirebaseService();

  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  bool _actionLoading = false;
  StreamSubscription? _sub;
  String _currentUid = '';
  bool _isCustomer = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _init();
  }

  Future<void> _init() async {
    final role = await StorageService.getRole();
    _currentUid = await StorageService.getUid() ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    _isCustomer = role == 'customer';

    if (widget.bookingId.isNotEmpty) {
      _listenBooking(widget.bookingId);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenBooking(String bookingId) {
    final ref = _db.child('bookings/$bookingId');
    _sub = ref.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _booking = map..['bookingId'] = bookingId;
          if (map['customerId'] != null && _currentUid.isNotEmpty) {
            _isCustomer = map['customerId'].toString() == _currentUid;
          }
          _isLoading = false;
        });
        _slideCtrl.forward();
      } else {
        setState(() => _isLoading = false);
      }
    }, onError: (_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _sub?.cancel();
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) => 'Rs. ${amount.toStringAsFixed(0)}';

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    final ts = timestamp is int
        ? timestamp
        : timestamp is double
            ? timestamp.toInt()
            : null;
    if (ts == null) return 'Just now';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Firebase Actions ─────────────────────────────────────────────────────────

  Future<void> _proposePrice(double price) async {
    setState(() => _actionLoading = true);
    try {
      await _db.child('bookings/${widget.bookingId}').update({
        'proposedPrice': price,
        if (_isCustomer) 'counterPrice': price,
        'status': _isCustomer
            ? 'pending_professional_response'
            : 'pending_customer_response',
        'updatedAt': ServerValue.timestamp,
      });

      // Push to negotiation history
      await _db
          .child('bookings/${widget.bookingId}/negotiationHistory')
          .push()
          .set({
        'from': _isCustomer ? 'customer' : 'professional',
        'price': price,
        'timestamp': ServerValue.timestamp,
      });

      _priceController.clear();
      _showSnack('Offer sent successfully! ✓', success: true);
    } catch (e) {
      _showSnack('Error: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _acceptOffer() async {
    final booking = _booking;
    if (booking == null) return;

    final price = (booking['proposedPrice'] ?? 0.0).toDouble();
    if (price <= 0) {
      _showSnack('No price to accept yet', success: false);
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final confirmed = await _firebase.confirmBookingDeal(widget.bookingId);
      if (!confirmed) {
        _showSnack('Could not confirm deal. Please try again.', success: false);
        return;
      }

      // Push acceptance to history
      await _db
          .child('bookings/${widget.bookingId}/negotiationHistory')
          .push()
          .set({
        'from': _isCustomer ? 'customer' : 'professional',
        'price': price,
        'action': 'accepted',
        'timestamp': ServerValue.timestamp,
      });

      _showSnack('Deal confirmed at ${_formatCurrency(price)}! 🎉',
          success: true);
    } catch (e) {
      _showSnack('Error: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _declineOrCancel() async {
    final confirmed = await _showConfirmDialog(
      _isCustomer ? 'Cancel Request?' : 'Decline Request?',
      _isCustomer
          ? 'Are you sure you want to cancel this service request?'
          : 'Are you sure you want to decline this booking?',
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      await _db.child('bookings/${widget.bookingId}').update({
        'status': _isCustomer ? 'cancelled' : 'rejected',
        'updatedAt': ServerValue.timestamp,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Error: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _submitBid() async {
    final txt = _priceController.text.trim();
    if (txt.isEmpty) {
      _showSnack('Please enter a price amount', success: false);
      return;
    }
    final price = double.tryParse(txt);
    if (price == null || price <= 0) {
      _showSnack('Enter a valid price greater than 0', success: false);
      return;
    }
    await _proposePrice(price);
  }

  void _showSnack(String msg, {required bool success}) {
    showTimedSnackBar(
        context,
        SnackBar(
          content: Row(children: [
            Icon(success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ]),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final booking = _booking;
    if (booking == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(child: Text('Booking not found')),
      );
    }

    final status = booking['status']?.toString() ?? 'pending_acceptance';
    final proposedPrice = (booking['proposedPrice'] ?? 0.0).toDouble();
    final agreedPrice = (booking['agreedPrice'] ?? 0.0).toDouble();
    final isConfirmed = status == 'confirmed';
    final isCancelled = status == 'cancelled' || status == 'rejected';

    // Determine whose turn it is
    final myTurn = !isConfirmed &&
        !isCancelled &&
        ((status == 'pending_acceptance' && !_isCustomer) ||
            (status == 'pending_customer_response' && _isCustomer) ||
            (status == 'pending_professional_response' && !_isCustomer));

    final activePrice = status == 'pending_customer_response'
        ? proposedPrice
        : (status == 'pending_professional_response' ? proposedPrice : 0.0);

    // History
    final rawHistory = booking['negotiationHistory'];
    final List<Map<String, dynamic>> history = [];
    if (rawHistory is Map) {
      rawHistory.forEach((k, v) {
        if (v is Map) {
          final entry = Map<String, dynamic>.from(v);
          entry['_key'] = k;
          history.add(entry);
        }
      });
      history.sort((a, b) => ((a['timestamp'] ?? 0) as num)
          .compareTo((b['timestamp'] ?? 0) as num));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Status Banner
          _buildStatusBanner(status, proposedPrice, agreedPrice, isConfirmed,
              isCancelled, myTurn),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Job Details Card
                  _buildJobDetailsCard(booking),
                  const SizedBox(height: 16),

                  // Agreed Price if confirmed
                  if (isConfirmed && agreedPrice > 0)
                    _buildAgreedPriceCard(agreedPrice, booking),

                  // Negotiation history
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSectionTitle('💬 Bid History'),
                    const SizedBox(height: 10),
                    ...history.asMap().entries.map((e) => _buildHistoryItem(
                        e.value, e.key == history.length - 1)),
                  ] else if (!isConfirmed && !isCancelled) ...[
                    const SizedBox(height: 16),
                    _buildEmptyHistory(),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom action panel
          SlideTransition(
            position: _slideAnim,
            child: _buildBottomPanel(
                status, myTurn, activePrice, isConfirmed, isCancelled),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Price Negotiation',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      centerTitle: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String status, double proposed, double agreed,
      bool isConfirmed, bool isCancelled, bool myTurn) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    if (isConfirmed) {
      bgColor = const Color(0xFFE8F5E9);
      textColor = AppColors.success;
      icon = Icons.check_circle_rounded;
      title = '🎉 Deal Confirmed!';
      subtitle =
          'Agreed price: ${_formatCurrency(agreed)}. Contact the other party to start.';
    } else if (isCancelled) {
      bgColor = const Color(0xFFFFEBEE);
      textColor = AppColors.error;
      icon = Icons.cancel_rounded;
      title = status == 'cancelled' ? 'Request Cancelled' : 'Request Declined';
      subtitle = 'This booking is no longer active.';
    } else if (myTurn) {
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
      icon = Icons.notifications_active_rounded;
      title = _isCustomer
          ? '🔔 Your Turn — Review Offer'
          : '🔔 Your Turn — Propose Price';
      subtitle = proposed > 0
          ? 'Professional offered ${_formatCurrency(proposed)}. Accept or counter.'
          : 'Customer is waiting. Propose your initial price.';
    } else {
      bgColor = const Color(0xFFEEF2FF);
      textColor = AppColors.primary;
      icon = Icons.hourglass_top_rounded;
      title = _isCustomer
          ? '⏳ Waiting for Professional...'
          : '⏳ Waiting for Customer...';
      subtitle = proposed > 0
          ? 'Your offer of ${_formatCurrency(proposed)} is being reviewed.'
          : 'The other party will respond shortly.';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: textColor.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: myTurn ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
            child: Icon(icon, color: textColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.75),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetailsCard(Map<String, dynamic> booking) {
    final service = booking['serviceType']?.toString() ?? 'Service';
    final address = booking['address']?.toString() ?? '';
    final description = booking['description']?.toString() ?? '';
    final customerPhone = booking['customerPhone']?.toString() ?? '';
    final customerId = booking['customerId']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_outline,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary)),
                    Text('Job Details',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          if (address.isNotEmpty)
            _detailRow(Icons.location_on_rounded, 'Location', address,
                color: const Color(0xFFE53935)),
          if (!_isCustomer && customerId.isNotEmpty) ...[
            const SizedBox(height: 8),
            _detailRow(
                Icons.person_rounded,
                'Customer ID',
                customerId.length > 10
                    ? '${customerId.substring(0, 10)}...'
                    : customerId,
                color: AppColors.primary),
          ],
          if (!_isCustomer && customerPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  Clipboard.setData(ClipboardData(text: customerPhone)),
              child: _detailRow(Icons.phone_rounded, 'Phone', customerPhone,
                  color: AppColors.success),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Problem Description',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Color color = AppColors.primary}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary))),
      ],
    );
  }

  Widget _buildAgreedPriceCard(double price, Map<String, dynamic> booking) {
    final professionalPhone = booking['professionalPhone']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppColors.success.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handshake_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Deal Agreed!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(price),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          const Text('Agreed Service Price',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          if (professionalPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Contact: $professionalPhone',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary));
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, bool isLatest) {
    final from = item['from']?.toString() ?? '';
    final price = (item['price'] ?? 0.0).toDouble();
    final ts = item['timestamp'];
    final action = item['action']?.toString() ?? '';
    final isFromMe = (from == 'customer' && _isCustomer) ||
        (from == 'professional' && !_isCustomer);
    final isAccepted = action == 'accepted';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: isFromMe
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark])
                      : const LinearGradient(
                          colors: [Color(0xFF6B7280), Color(0xFF4B5563)]),
                  shape: BoxShape.circle,
                  boxShadow: isLatest
                      ? [
                          BoxShadow(
                              color:
                                  (isFromMe ? AppColors.primary : Colors.grey)
                                      .withOpacity(0.35),
                              blurRadius: 8)
                        ]
                      : null,
                ),
                child: Icon(
                    isAccepted
                        ? Icons.check_rounded
                        : (isFromMe
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded),
                    color: Colors.white,
                    size: 16),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isLatest
                    ? (isFromMe
                        ? AppColors.primary.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.08))
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isLatest
                      ? (isFromMe
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3))
                      : AppColors.divider,
                  width: isLatest ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAccepted
                              ? (isFromMe
                                  ? 'You accepted'
                                  : 'Other party accepted')
                              : (isFromMe
                                  ? 'You offered'
                                  : (from == 'professional'
                                      ? 'Professional offered'
                                      : 'Customer offered')),
                          style: TextStyle(
                              fontWeight:
                                  isLatest ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                              color: isLatest
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary),
                        ),
                        if (ts != null) ...[
                          const SizedBox(height: 2),
                          Text(_formatTimeAgo(ts),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textLight)),
                        ],
                      ],
                    ),
                  ),
                  if (price > 0)
                    Text(
                      _formatCurrency(price),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isLatest
                              ? (isFromMe
                                  ? AppColors.primary
                                  : AppColors.textPrimary)
                              : AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 40, color: AppColors.textLight),
          SizedBox(height: 12),
          Text('No bids yet',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  fontSize: 14)),
          SizedBox(height: 4),
          Text('Propose your price below to start negotiating',
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(String status, bool myTurn, double activePrice,
      bool isConfirmed, bool isCancelled) {
    if (isConfirmed || isCancelled) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, -4))
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(isConfirmed ? 'Back to Bookings' : 'Close'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      );
    }

    if (!myTurn) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    Text(
                      _isCustomer
                          ? 'Waiting for professional to respond...'
                          : 'Waiting for customer to respond...',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _declineOrCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(_isCustomer ? 'Cancel Request' : 'Decline',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // My turn — show price input
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current offer info
            if (activePrice > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      AppColors.primaryLight.withOpacity(0.05)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Offer',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    Text(
                      _formatCurrency(activePrice),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Price input + counter button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: InputDecoration(
                      labelText:
                          activePrice > 0 ? 'Counter Offer' : 'Your Price',
                      prefixText: 'Rs. ',
                      prefixStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary),
                      hintText: '0',
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _actionLoading ? null : _submitBid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: _actionLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(activePrice > 0 ? 'Counter' : 'Bid',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Accept / Cancel row
            Row(
              children: [
                if (activePrice > 0) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _actionLoading ? null : _acceptOffer,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Accept Deal',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionLoading ? null : _declineOrCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(_isCustomer ? 'Cancel' : 'Decline',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
