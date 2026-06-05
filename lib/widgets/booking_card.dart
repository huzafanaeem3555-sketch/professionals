import 'package:flutter/material.dart';
import '../utils/snackbar_helper.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final String currentUserId;
  final String? currentUserRole;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final VoidCallback? onCancel;
  final VoidCallback? onTrack;

  const BookingCard({
    super.key,
    required this.booking,
    required this.currentUserId,
    this.currentUserRole,
    this.onAccept,
    this.onReject,
    this.onCall,
    this.onChat,
    this.onCancel,
    this.onTrack,
  });

  Color _getStatusColor() {
    switch (booking.status) {
      case 'pending_acceptance':
        return AppColors.warning;
      case 'counter_offered':
        return const Color(0xFFFF9800); // Orange color for counter offer
      case 'confirmed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.primary;
      case 'completed':
        return AppColors.textSecondary;
      case 'rejected':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusLabel() {
    switch (booking.status) {
      case 'pending_acceptance':
        return '⏳ Awaiting Response';
      case 'counter_offered':
        return '⏳ Counter Offered';
      case 'confirmed':
        return '✅ Confirmed';
      case 'in_progress':
        return '🔧 In Progress';
      case 'completed':
        return '✔️ Completed';
      case 'rejected':
        return '❌ Rejected';
      case 'cancelled':
        return '❌ Cancelled';
      default:
        return booking.status;
    }
  }

  bool _isProfessional() => currentUserRole == 'professional';
  bool _isCustomer() => currentUserRole == 'customer';

  bool _isMyBooking() {
    if (_isProfessional()) {
      return booking.professionalId == currentUserId;
    } else {
      return booking.customerId == currentUserId;
    }
  }

  void _showCounterBidDialog(BuildContext context) {
    final controller =
        TextEditingController(text: booking.agreedPrice.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter Bid Price (Rs.)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your counter price for this job:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice > 0) {
                Navigator.pop(ctx);
                try {
                  final provider =
                      Provider.of<BookingProvider>(context, listen: false);
                  provider.proposeCounterBid(booking.bookingId, newPrice);
                  showTimedSnackBar(
                    context,
                    SnackBar(
                        content: Text(
                            'Counter bid sent: Rs. ${newPrice.toStringAsFixed(0)}')),
                  );
                } catch (e) {
                  debugPrint('Error proposing counter-bid: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Submit Counter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMyBooking()) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isProfessional()
                            ? 'Customer: ${booking.customerName ?? 'Customer'} (${booking.serviceType})'
                            : 'Pro: ${booking.professionalName ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor()),
                  ),
                  child: Text(
                    _getStatusLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(),
                    ),
                  ),
                ),
              ],
            ),

            if (booking.canShowContactPhone) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      booking.otherUserPhone!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 16),

            if (booking.status != 'pending_acceptance' &&
                booking.status != 'counter_offered')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppHelpers.formatCurrency(booking.agreedPrice),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (booking.scheduledTime != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Scheduled',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(booking.scheduledTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

            // Description if available
            if (booking.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Job Details: ${booking.description}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Action buttons
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    // Professional acknowledge new confirmed booking
    if (_isProfessional() && booking.status == 'confirmed') {
      buttons.addAll([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Accept', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ]);
    }

    // Professional-only actions (pending acceptance / negotiation)
    if (_isProfessional() && booking.status == 'pending_acceptance') {
      buttons.addAll([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Accept', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showCounterBidDialog(context),
            icon: const Icon(Icons.edit_sharp, size: 16),
            label: const Text('Counter', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ]);
    }

    // Professional awaiting customer counter response
    if (_isProfessional() && booking.status == 'counter_offered') {
      buttons.add(
        const Expanded(
          child: Center(
            child: Text(
              'Waiting for Customer Response',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    // Customer actions (counter offered)
    if (_isCustomer() && booking.status == 'counter_offered') {
      buttons.addAll([
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Accept Counter', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ]);
    }

    // Call action when phone is available
    if (booking.canShowContactPhone && onCall != null) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.call),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
          ),
        ),
      );
      if (buttons.length > 1) buttons.add(const SizedBox(width: 8));
    }

    // Chat action
    if ((booking.status == 'confirmed' || booking.status == 'in_progress') &&
        onChat != null) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    // Track action (customer tracking professional location)
    if (_isCustomer() &&
        (booking.status == 'confirmed' || booking.status == 'in_progress') &&
        onTrack != null) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onTrack,
            icon: const Icon(Icons.location_on),
            label: const Text('Track'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
            ),
          ),
        ),
      );
    }

    // Cancel action (customer, before job starts)
    if ((booking.status == 'pending_acceptance' ||
            booking.status == 'confirmed') &&
        _isCustomer() &&
        onCancel != null) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: 8));
      }
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel'),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: buttons,
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not set';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
