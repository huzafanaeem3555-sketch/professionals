class UserModel {
  final String uid;
  final String? email;
  final String? name;
  final String? photoURL;
  final String? role;
  final bool profileCompleted;
  final String? phoneNumber;
  final double rating;
  final int totalRatings;
  final double lat;
  final double lng;
  final double walletBalance;

  UserModel({
    required this.uid,
    this.email,
    this.name,
    this.photoURL,
    this.role,
    this.profileCompleted = false,
    this.phoneNumber,
    this.rating = 0,
    this.totalRatings = 0,
    this.lat = 0,
    this.lng = 0,
    this.walletBalance = 5000.0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'],
      name: map['name'] ?? map['displayName'],
      photoURL: map['photoURL'],
      role: map['role'],
      profileCompleted: map['profileCompleted'] == true || (map['profileCompleted'] is String && map['profileCompleted'] == 'true'),
      phoneNumber: map['phoneNumber'],
      rating: (map['rating'] ?? 0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      lat: (map['lat'] ?? map['location']?['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? map['location']?['lng'] ?? 0).toDouble(),
      walletBalance: (map['walletBalance'] ?? 5000.0).toDouble(),
    );
  }

  /// A lightweight guest user used for continue-as-guest flows.
  factory UserModel.guest() {
    return UserModel(
      uid: 'guest',
      email: null,
      name: 'Guest',
      photoURL: null,
      role: '',
      phoneNumber: null,
      rating: 0,
      totalRatings: 0,
      lat: 0,
      lng: 0,
      walletBalance: 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoURL': photoURL,
      'role': role,
      'profileCompleted': profileCompleted,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      'rating': rating,
      'totalRatings': totalRatings,
      'lat': lat,
      'lng': lng,
    };
  }

  UserModel copyWith({
    String? name,
    String? role,
    bool? profileCompleted,
    String? phoneNumber,
    double? rating,
    int? totalRatings,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      name: name ?? this.name,
      photoURL: photoURL,
      role: role ?? this.role,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      lat: lat,
      lng: lng,
    );
  }

  bool get hasRole => role != null && role!.isNotEmpty;
  bool get isCustomer => role == 'customer';
  bool get isProfessional => role == 'professional';
  String get firstLetter => name?.isNotEmpty == true ? name![0].toUpperCase() : 'U';
}
