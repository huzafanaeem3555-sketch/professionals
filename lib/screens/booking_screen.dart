import 'package:flutter/material.dart';
import '../utils/snackbar_helper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/booking_provider.dart';
import '../utils/constants.dart';
import '../models/professional_model.dart';

class BookingScreen extends StatefulWidget {
  final String? professionalId;
  final String? serviceType;
  final double? suggestedPrice;
  final ProfessionalModel? professional;
  final double? customerLat;
  final double? customerLng;

  const BookingScreen({
    super.key,
    this.professionalId,
    this.serviceType,
    this.suggestedPrice,
    this.professional,
    this.customerLat,
    this.customerLng,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String get _displayService =>
      widget.serviceType ??
      (widget.professional?.services.isNotEmpty == true
          ? widget.professional!.services.first
          : 'Service');

  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submitRequest() async {
    final description = _descriptionController.text.trim();
    final address = _addressController.text.trim();

    if (description.isEmpty) {
      showTimedSnackBar(
        context,
        const SnackBar(content: Text('Please enter issue description')),
      );
      return;
    }
    if (address.isEmpty) {
      showTimedSnackBar(
        context,
        const SnackBar(content: Text('Please enter service address')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      DateTime? scheduledTime;
      if (_selectedDate != null && _selectedTime != null) {
        scheduledTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      final pro = widget.professional;
      final proUid = pro?.uid ?? widget.professionalId ?? '';
      final success = await context.read<BookingProvider>().createBooking(
        professionalId: proUid,
        serviceType: pro?.services.isNotEmpty == true
            ? pro!.services.first
            : (widget.serviceType ?? 'general'),
        proposedPrice: 0,
        scheduledTime: scheduledTime?.toIso8601String(),
        address: address,
        description: description,
        customerLocation: {
          'lat': widget.customerLat ?? 0,
          'lng': widget.customerLng ?? 0,
        },
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Request Sent'),
            content: const Text(
              'Your request has been sent. Professional will send a price offer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        showTimedSnackBar(
          context,
          SnackBar(
            content: Text(
              context.read<BookingProvider>().error ?? 'Request failed',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showTimedSnackBar(
        context,
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Service'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.build, size: 32, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _displayService,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel('Preferred Day/Time (Optional)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime == null
                          ? 'Select Time'
                          : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('Service Address'),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'House #, street, area',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('Issue Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your issue clearly...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Send Request',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
}
