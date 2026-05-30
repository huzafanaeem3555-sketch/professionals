class ProfessionalModel {
  final String uid;
  final String phone;
  final String name;
  final List<String> services;
  final List<String> customServices;
  final LocationData location;
  final String description;
  final bool isAvailable;
  final double rating;
  final String photoURL;
  final double? distance;
  final int totalRatings;
  final int completedJobs;
  final int experienceYears;
  final bool isVerified;
  final double hourlyRate;
  final List<String> portfolio;
  final List<String> brochureImages;
  final List<ProfessionalReview> reviews;

  ProfessionalModel({
    required this.uid,
    required this.phone,
    required this.name,
    required this.services,
    this.customServices = const [],
    required this.location,
    required this.description,
    required this.isAvailable,
    required this.rating,
    required this.photoURL,
    this.distance,
    this.totalRatings = 0,
    this.completedJobs = 0,
    this.experienceYears = 0,
    this.isVerified = false,
    this.hourlyRate = 0,
    this.portfolio = const [],
    this.brochureImages = const [],
    this.reviews = const [],
  });

  factory ProfessionalModel.fromJson(Map<String, dynamic> json) {
    final locationData = json['location'] != null
        ? LocationData.fromJson(Map<String, dynamic>.from(json['location']))
        : LocationData(lat: 0, lng: 0, address: '');

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double toDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    return ProfessionalModel(
      uid: (json['uid'] ?? json['phone'] ?? '').toString(),
      phone: (json['phone'] ?? json['phoneNumber'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      services: List<String>.from(json['services'] ?? const []),
      customServices: List<String>.from(json['customServices'] ?? const []),
      location: locationData,
      description: (json['description'] ?? '').toString(),
      isAvailable: json['isAvailable'] != false,
      rating: toDouble(json['rating']),
      photoURL: (json['photoURL'] ??
              json['photoUrl'] ??
              json['profileImage'] ??
              json['imageUrl'] ??
              json['avatar'] ??
              '')
          .toString(),
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      totalRatings: toInt(json['totalRatings']),
      completedJobs: toInt(json['completedJobs']),
      experienceYears: toInt(json['experienceYears']),
      isVerified: json['isVerified'] == true || json['verified'] == true,
      hourlyRate: toDouble(json['hourlyRate']),
      portfolio: (json['portfolio'] is List)
          ? List<String>.from(json['portfolio'])
          : const [],
      brochureImages: (json['brochureImages'] is List)
          ? List<String>.from(json['brochureImages'])
          : (json['bannerImages'] is List)
              ? List<String>.from(json['bannerImages'])
              : const [],
      reviews: (json['reviews'] is List)
          ? (json['reviews'] as List)
              .whereType<Map>()
              .map((e) =>
                  ProfessionalReview.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phone': phone,
      'name': name,
      'services': services,
      'customServices': customServices,
      'location': location.toJson(),
      'description': description,
      'isAvailable': isAvailable,
      'rating': rating,
      'photoURL': photoURL,
      'totalRatings': totalRatings,
      'completedJobs': completedJobs,
      'experienceYears': experienceYears,
      'isVerified': isVerified,
      'hourlyRate': hourlyRate,
      'portfolio': portfolio,
      'brochureImages': brochureImages,
      'reviews': reviews.map((e) => e.toJson()).toList(),
    };
  }

  ProfessionalModel copyWith({
    String? uid,
    String? phone,
    String? name,
    List<String>? services,
    List<String>? customServices,
    LocationData? location,
    String? description,
    bool? isAvailable,
    double? rating,
    String? photoURL,
    double? distance,
    int? totalRatings,
    int? completedJobs,
    int? experienceYears,
    bool? isVerified,
    double? hourlyRate,
    List<String>? portfolio,
    List<String>? brochureImages,
    List<ProfessionalReview>? reviews,
  }) {
    return ProfessionalModel(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      services: services ?? this.services,
      customServices: customServices ?? this.customServices,
      location: location ?? this.location,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      photoURL: photoURL ?? this.photoURL,
      distance: distance ?? this.distance,
      totalRatings: totalRatings ?? this.totalRatings,
      completedJobs: completedJobs ?? this.completedJobs,
      experienceYears: experienceYears ?? this.experienceYears,
      isVerified: isVerified ?? this.isVerified,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      portfolio: portfolio ?? this.portfolio,
      brochureImages: brochureImages ?? this.brochureImages,
      reviews: reviews ?? this.reviews,
    );
  }

  String get ratingText => rating > 0 ? rating.toStringAsFixed(1) : 'New';
  String get distanceText =>
      distance != null ? '${distance!.toStringAsFixed(1)} km' : 'N/A';
  List<String> get allServices {
    final seen = <String>{};
    final merged = <String>[];
    for (final service in [...services, ...customServices]) {
      final normalized = service.trim();
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) merged.add(normalized);
    }
    return merged;
  }

  String get serviceText =>
      allServices.isNotEmpty ? allServices.join(', ') : 'No services';

  List<String> get serviceTypes => allServices;
  bool get isAvailableNow => isAvailable;
  List<dynamic> get fixedPriceServices => const [];
  double get lat => location.lat;
  double get lng => location.lng;
  String get address => location.address;

  factory ProfessionalModel.fromMap(Map<String, dynamic> map) =>
      ProfessionalModel.fromJson(map);
}

class LocationData {
  final double lat;
  final double lng;
  final String address;

  LocationData({
    required this.lat,
    required this.lng,
    required this.address,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      address: (json['address'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'address': address,
    };
  }
}

class ProfessionalReview {
  final String bookingId;
  final String customerName;
  final int rating;
  final String review;
  final int createdAt;

  const ProfessionalReview({
    required this.bookingId,
    required this.customerName,
    required this.rating,
    required this.review,
    required this.createdAt,
  });

  factory ProfessionalReview.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return ProfessionalReview(
      bookingId: (json['bookingId'] ?? '').toString(),
      customerName: (json['customerName'] ?? 'Customer').toString(),
      rating: toInt(json['rating']),
      review: (json['review'] ?? '').toString(),
      createdAt: toInt(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'customerName': customerName,
        'rating': rating,
        'review': review,
        'createdAt': createdAt,
      };
}
