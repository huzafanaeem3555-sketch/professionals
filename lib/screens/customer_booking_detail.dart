import 'package:flutter/material.dart';
import '../utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import '../providers/booking_provider.dart';
import '../utils/constants.dart';

class CustomerBookingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> booking;

  const CustomerBookingDetailScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? '';
    final service = booking['serviceType']?.toString() ?? 'Service';
    final price =
        (booking['agreedPrice'] ?? booking['proposedPrice'] ?? 0).toDouble();
    final phone = booking['professionalPhone']?.toString() ?? '';
    final canConfirmCompletion = status == 'in_progress';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Detail'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Status: $status'),
            const SizedBox(height: 6),
            Text('Price: Rs. ${price.toStringAsFixed(0)}'),
            const SizedBox(height: 6),
            if (phone.isNotEmpty) Text('Professional Phone: $phone'),
            const Spacer(),
            if (canConfirmCompletion)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final ok = await context
                        .read<BookingProvider>()
                        .customerConfirmCompletion(booking['bookingId']);
                    if (!context.mounted) return;
                    showTimedSnackBar(
                      context,
                      SnackBar(
                        content: Text(ok
                            ? 'Service marked complete. Waiting for professional confirmation.'
                            : 'Could not confirm completion. Try again.'),
                        backgroundColor:
                            ok ? AppColors.success : AppColors.error,
                      ),
                    );
                    if (ok) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Completion'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
