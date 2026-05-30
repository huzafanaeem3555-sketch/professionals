/// Model for professional location information
class ProfessionalLocationModel {
  final String uid;
  final String displayName;
  final String photoURL;
  final double lat;
  final double lng;
  final String address;
  final String phoneNumber;
  final double rating;
  final int totalRatings;
  final String serviceType;
  final double? distance; // km

  ProfessionalLocationModel({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.lat,
    required this.lng,
    required this.address,
    required this.phoneNumber,
    required this.rating,
    required this.totalRatings,
    required this.serviceType,
    this.distance,
  });

  factory ProfessionalLocationModel.fromMap(Map<String, dynamic> map) {
    return ProfessionalLocationModel(
      uid: map['uid'] ?? map['_id'] ?? '',
      displayName: map['displayName'] ?? map['userInfo']?['displayName'] ?? '',
      photoURL: map['photoURL'] ?? map['userInfo']?['photoURL'] ?? '',
      lat: (map['lat'] ?? map['userInfo']?['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? map['userInfo']?['lng'] ?? 0).toDouble(),
      address: map['address'] ?? map['userInfo']?['address'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['userInfo']?['phoneNumber'] ?? '',
      rating: (map['rating'] ?? map['userInfo']?['rating'] ?? 0).toDouble(),
      totalRatings: map['totalRatings'] ?? map['userInfo']?['totalRatings'] ?? 0,
      serviceType: map['serviceType'] ?? map['userInfo']?['serviceType'] ?? '',
      distance: map['distance'] != null ? (map['distance'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoURL': photoURL,
      'lat': lat,
      'lng': lng,
      'address': address,
      'phoneNumber': phoneNumber,
      'rating': rating,
      'totalRatings': totalRatings,
      'serviceType': serviceType,
      'distance': distance,
    };
  }
}

/// Model for nearby professional search results
class NearbyProfessionalsResult {
  final List<Map<String, dynamic>> professionals;
  final int totalCount;
  final String? searchRadius;

  NearbyProfessionalsResult({
    required this.professionals,
    required this.totalCount,
    this.searchRadius,
  });

  factory NearbyProfessionalsResult.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>? ?? {};
    return NearbyProfessionalsResult(
      professionals: List<Map<String, dynamic>>.from(
        data['professionals'] ?? [],
      ),
      totalCount: (data['totalCount'] ?? (data['professionals'] as List?)?.length ?? 0) as int,
      searchRadius: data['searchRadius']?.toString(),
    );
  }
}

