import '../utils/constants.dart';

class AppHelpers {
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String formatCurrency(double amount) {
    final whole = amount.toStringAsFixed(0);
    final formatted = whole.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return 'Rs. $formatted';
  }

  static double calculateCommission(double price, {double rate = 0.10}) {
    return price * rate;
  }

  static double calculateEarnings(double price, {double rate = 0.10}) {
    return price * (1 - rate);
  }

  static String formatDate(dynamic date) {
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      dt = DateTime.tryParse(date);
    } else if (date is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(date);
    }
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $ampm';
  }

  static int getStatusColor(String status) {
    switch (status) {
      case 'pending_payment':
        return AppColors.warning.toARGB32();
      case 'pending_customer_response':
      case 'pending_professional_response':
        return AppColors.accent.toARGB32();
      case 'confirmed':
        return AppColors.primary.toARGB32();
      case 'in_progress':
        return AppColors.accent.toARGB32();
      case 'completed':
        return AppColors.success.toARGB32();
      case 'cancelled':
      case 'rejected':
        return AppColors.error.toARGB32();
      default:
        return AppColors.textSecondary.toARGB32();
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending_payment':
        return 'Payment Pending';
      case 'pending_customer_response':
        return 'Awaiting Customer';
      case 'pending_professional_response':
        return 'Awaiting Professional';
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
        return formatStatus(status);
    }
  }

  static String formatStatus(String status) {
    switch (status) {
      case 'pending_payment':
        return 'Pending';
      case 'pending_customer_response':
        return 'Customer Review';
      case 'pending_professional_response':
        return 'Professional Review';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'Active';
      case 'completed':
        return 'Done';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  static String timeAgo(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(dt);
  }

  static String formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    int ts;
    if (timestamp is int) {
      ts = timestamp;
    } else if (timestamp is double) {
      ts = timestamp.toInt();
    } else if (timestamp is String) {
      ts = int.tryParse(timestamp) ??
          double.tryParse(timestamp)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
    } else {
      return 'Just now';
    }
    return timeAgo(ts);
  }
}
