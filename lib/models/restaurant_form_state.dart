import 'dart:io';

class RestaurantFormState {
  final String restaurantName;
  final String description;
  final String address;
  final String phone;
  final String wilaya;
  final Map<String, dynamic> workingHours;
  final File? logo;
  final String? logoUrl;
  final double? latitude;
  final double? longitude;
  final bool isLoading;
  final String? errorMessage;
  final String sector;
  final String? groceryType;
  final Map<String, String> socialMedia;

  const RestaurantFormState({
    this.restaurantName = '',
    this.description = '',
    this.address = '',
    this.phone = '',
    this.wilaya = '',
    this.workingHours = const {},
    this.logo,
    this.logoUrl,
    this.latitude,
    this.longitude,
    this.isLoading = false,
    this.errorMessage,
    this.sector = 'restaurant',
    this.groceryType,
    this.socialMedia = const {},
  });

  RestaurantFormState copyWith({
    String? restaurantName,
    String? description,
    String? address,
    String? phone,
    String? wilaya,
    Map<String, dynamic>? workingHours,
    File? logo,
    String? logoUrl,
    double? latitude,
    double? longitude,
    bool? isLoading,
    String? errorMessage,
    String? sector,
    String? groceryType,
    Map<String, String>? socialMedia,
  }) {
    return RestaurantFormState(
      restaurantName: restaurantName ?? this.restaurantName,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      wilaya: wilaya ?? this.wilaya,
      workingHours: workingHours ?? this.workingHours,
      logo: logo ?? this.logo,
      logoUrl: logoUrl ?? this.logoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      sector: sector ?? this.sector,
      groceryType: groceryType ?? this.groceryType,
      socialMedia: socialMedia ?? this.socialMedia,
    );
  }

  /// Check if form is valid for submission
  bool get isValid {
    return restaurantName.isNotEmpty &&
        address.isNotEmpty &&
        phone.isNotEmpty &&
        wilaya.isNotEmpty &&
        workingHours.isNotEmpty &&
        latitude != null &&
        longitude != null &&
        (sector != 'grocery' || groceryType != null);
  }

  /// Get entity label based on sector
  String get entityLabel {
    switch (sector) {
      case 'grocery':
        return 'Grocery';
      case 'handyman':
        return 'Handyman';
      default:
        return 'Restaurant';
    }
  }

  /// Get entity icon based on sector
  String get entityIcon {
    switch (sector) {
      case 'grocery':
        return 'local_grocery_store';
      case 'handyman':
        return 'build';
      default:
        return 'restaurant';
    }
  }

  /// Social media getters
  String? get facebook => socialMedia['facebook'];
  String? get instagram => socialMedia['instagram'];
  String? get tiktok => socialMedia['tiktok'];

  /// Create from map
  factory RestaurantFormState.fromMap(Map<String, dynamic> map) {
    return RestaurantFormState(
      restaurantName: map['restaurantName'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      // Store wilaya as key-friendly value; default to empty
      wilaya: (map['wilaya'] ?? '').toString(),
      workingHours: Map<String, dynamic>.from(map['workingHours'] ?? {}),
      logo: map['logo'] != null ? File(map['logo']) : null,
      logoUrl: map['logoUrl'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      isLoading: map['isLoading'] ?? false,
      errorMessage: map['errorMessage'],
      sector: map['sector'] ?? 'restaurant',
      groceryType: map['groceryType'],
      socialMedia: Map<String, String>.from(map['socialMedia'] ?? {}),
    );
  }

  /// Convert to map for API submission
  Map<String, dynamic> toMap() {
    return {
      'restaurantName': restaurantName,
      'restaurantDescription': description,
      'restaurantAddress': address,
      'restaurantPhone': phone,
      'wilaya': wilaya,
      'openingHours': workingHours.toString(),
      'logoUrl': logoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'sector': sector,
      'groceryType': groceryType,
      'socialMedia': socialMedia,
    };
  }

  @override
  String toString() {
    return 'RestaurantFormState(restaurantName: $restaurantName, address: $address, sector: $sector, isValid: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RestaurantFormState &&
        other.restaurantName == restaurantName &&
        other.description == description &&
        other.address == address &&
        other.phone == phone &&
        other.wilaya == wilaya &&
        other.workingHours == workingHours &&
        other.logo == logo &&
        other.logoUrl == logoUrl &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.sector == sector &&
        other.groceryType == groceryType &&
        other.socialMedia == socialMedia;
  }

  @override
  int get hashCode {
    return restaurantName.hashCode ^
        description.hashCode ^
        address.hashCode ^
        phone.hashCode ^
        wilaya.hashCode ^
        workingHours.hashCode ^
        logo.hashCode ^
        logoUrl.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        isLoading.hashCode ^
        errorMessage.hashCode ^
        sector.hashCode ^
        groceryType.hashCode ^
        socialMedia.hashCode;
  }
}
