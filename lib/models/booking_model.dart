class BookingModel {
  final String bookingId;
  final String customerId;
  final String professionalId;
  final String serviceType;
  final String status;
  final double agreedPrice;
  final double platformCommission;
  final double professionalEarnings;
  final String paymentStatus;
  final String? easypaisaTransactionId;
  final String? scheduledTime;
  final String address;
  final String description;
  final int customerRating;
  final String? customerReview;
  final int createdAt;
  final String? professionalName;
  final String? professionalPhoto;
  final String? customerName;
  final String? customerPhoto;
  final String? otherUserPhone;

  BookingModel({
    required this.bookingId,
    required this.customerId,
    required this.professionalId,
    required this.serviceType,
    required this.status,
    required this.agreedPrice,
    required this.platformCommission,
    required this.professionalEarnings,
    required this.paymentStatus,
    this.easypaisaTransactionId,
    this.scheduledTime,
    this.address = '',
    this.description = '',
    this.customerRating = 0,
    this.customerReview,
    this.createdAt = 0,
    this.professionalName,
    this.professionalPhoto,
    this.customerName,
    this.customerPhoto,
    this.otherUserPhone,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final agreedPrice =
        toDouble(map['agreedPrice'] ?? map['proposedPrice'] ?? 0);
    final commission = toDouble(map['commissionAmount'] ??
        map['platformCommission'] ??
        (agreedPrice * 0.10));
    final earnings =
        toDouble(map['professionalEarnings'] ?? (agreedPrice * 0.90));

    String? scheduled;
    final rawScheduled = map['scheduledTime'];
    if (rawScheduled != null) {
      try {
        final ms = toInt(rawScheduled);
        if (ms > 0) {
          scheduled = DateTime.fromMillisecondsSinceEpoch(ms).toString();
        } else {
          // try parse ISO string
          if (rawScheduled is String) {
            scheduled = DateTime.tryParse(rawScheduled)?.toString();
          }
        }
      } catch (_) {
        scheduled = null;
      }
    }

    final createdAtVal = toInt(map['_createdAt'] ?? map['createdAt']);

    return BookingModel(
      bookingId: (map['bookingId'] ?? map['id'] ?? '').toString(),
      customerId: (map['customerId'] ?? '').toString(),
      professionalId: (map['professionalId'] ?? '').toString(),
      serviceType: (map['serviceType'] ?? '').toString(),
      status: (map['status'] ?? 'pending_acceptance').toString(),
      agreedPrice: agreedPrice,
      platformCommission: commission,
      professionalEarnings: earnings,
      paymentStatus: (map['paymentStatus'] ?? 'pending').toString(),
      easypaisaTransactionId: map['easypaisaTransactionId']?.toString(),
      scheduledTime: scheduled,
      address: (map['address'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      customerRating: toInt(map['customerRating'] ?? 0),
      customerReview: map['customerReview']?.toString(),
      createdAt: createdAtVal,
      customerName: (map['otherUserName'] ??
              map['customerName'] ??
              map['customerInfo']?['displayName'])
          ?.toString(),
      customerPhoto: (map['otherUserPhoto'] ??
              map['customerPhoto'] ??
              map['customerInfo']?['photoURL'])
          ?.toString(),
      professionalName: (map['otherUserName'] ??
              map['professionalName'] ??
              map['professionalInfo']?['displayName'])
          ?.toString(),
      professionalPhoto: (map['otherUserPhoto'] ??
              map['professionalPhoto'] ??
              map['professionalInfo']?['photoURL'])
          ?.toString(),
      otherUserPhone: map['otherUserPhone']?.toString() ??
          (map['contactInfo'] is Map
              ? map['contactInfo']['phone']?.toString()
              : null),
    );
  }

  bool get isConfirmed => status == 'confirmed';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get canRate => isCompleted && customerRating == 0;

  bool get canShowContactPhone =>
      otherUserPhone != null &&
      otherUserPhone!.isNotEmpty &&
      (status == 'confirmed' ||
          status == 'in_progress' ||
          status == 'completed');
}
