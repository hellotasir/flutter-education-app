import 'package:cloud_firestore/cloud_firestore.dart';

class LatLng {
  const LatLng({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory LatLng.fromMap(Map<String, dynamic> map) => LatLng(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory LatLng.fromGeoPoint(GeoPoint geoPoint) =>
      LatLng(latitude: geoPoint.latitude, longitude: geoPoint.longitude);

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

class AddressComponents {
  const AddressComponents({
    required this.street,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.formattedAddress,
  });

  final String street;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String formattedAddress;

  factory AddressComponents.fromMap(Map<String, dynamic> map) =>
      AddressComponents(
        street: map['street'] ?? '',
        city: map['city'] ?? '',
        state: map['state'] ?? '',
        country: map['country'] ?? '',
        postalCode: map['postal_code'] ?? '',
        formattedAddress: map['formatted_address'] ?? '',
      );

  Map<String, dynamic> toMap() => {
    'street': street,
    'city': city,
    'state': state,
    'country': country,
    'postal_code': postalCode,
    'formatted_address': formattedAddress,
  };

  AddressComponents copyWith({
    String? street,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? formattedAddress,
  }) => AddressComponents(
    street: street ?? this.street,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    postalCode: postalCode ?? this.postalCode,
    formattedAddress: formattedAddress ?? this.formattedAddress,
  );
}

enum LocationType { currentLocation, customAddress }

extension LocationTypeExtension on LocationType {
  String get value => switch (this) {
    LocationType.currentLocation => 'current_location',
    LocationType.customAddress => 'custom_address',
  };

  static LocationType fromString(String value) => switch (value) {
    'current_location' => LocationType.currentLocation,
    'custom_address' => LocationType.customAddress,
    _ => LocationType.currentLocation,
  };
}

class LocationModel {
  const LocationModel({
    this.id,
    required this.userId,
    required this.role,
    required this.type,
    required this.coordinates,
    required this.address,
    this.label,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.accuracy,
    this.isVisible,
  });

  final String? id;
  final String userId;
  final String role;
  final LocationType type;
  final LatLng coordinates;
  final AddressComponents address;
  final String? label;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? accuracy;
  final bool? isVisible;

  factory LocationModel.fromSnapshot(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return LocationModel._fromMap(map, id: doc.id);
  }

  factory LocationModel._fromMap(Map<String, dynamic> map, {String? id}) {
    final geoPoint = map['coordinates'] as GeoPoint?;
    final coords = geoPoint != null
        ? LatLng.fromGeoPoint(geoPoint)
        : LatLng.fromMap((map['coordinates'] as Map<String, dynamic>?) ?? {});

    return LocationModel(
      id: id,
      userId: map['user_id'] ?? '',
      role: map['role'] ?? 'student',
      type: LocationTypeExtension.fromString(map['type'] ?? ''),
      coordinates: coords,
      address: AddressComponents.fromMap(
        (map['address'] as Map<String, dynamic>?) ?? {},
      ),
      label: map['label'] as String?,
      isDefault: map['is_default'] as bool? ?? false,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      isVisible: map['is_visible'] as bool?,
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'role': role,
    'type': type.value,
    'coordinates': coordinates.toGeoPoint(),
    'address': address.toMap(),
    if (label != null) 'label': label,
    'is_default': isDefault,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
    if (accuracy != null) 'accuracy': accuracy,
    if (isVisible != null) 'is_visible': isVisible,
  };

  LocationModel copyWith({
    String? id,
    String? userId,
    String? role,
    LocationType? type,
    LatLng? coordinates,
    AddressComponents? address,
    String? label,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? accuracy,
    bool? isVisible,
  }) => LocationModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    type: type ?? this.type,
    coordinates: coordinates ?? this.coordinates,
    address: address ?? this.address,
    label: label ?? this.label,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    accuracy: accuracy ?? this.accuracy,
    isVisible: isVisible ?? this.isVisible,
  );
}
