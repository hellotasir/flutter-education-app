import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_education_app/features/map/repositories/local_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_education_app/features/map/models/local_model.dart';
import 'package:http/http.dart' as http;

class LocationPermissionException implements Exception {
  const LocationPermissionException(this.message);
  final String message;
}

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException(this.message);
  final String message;
}

class GeocodingException implements Exception {
  const GeocodingException(this.message);
  final String message;
}

/// Thin wrapper around OpenStreetMap Nominatim so the rest of the service
/// never has to know about HTTP or JSON parsing.
class _NominatimClient {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  // Nominatim requires a meaningful User-Agent string.
  static const _headers = {
    'User-Agent': 'FlutterEducationApp/1.0 (your@email.com)',
    'Accept-Language': 'en',
  };

  /// Reverse-geocode: coordinates → address JSON map.
  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/reverse?format=jsonv2&lat=$lat&lon=$lng');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw GeocodingException(
        'Nominatim reverse geocode failed: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Forward-geocode: address string → list of result JSON maps.
  Future<List<Map<String, dynamic>>> forwardGeocode(String query) async {
    final uri = Uri.parse(
      '$_baseUrl/search?format=jsonv2&q=${Uri.encodeComponent(query)}&limit=1',
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw GeocodingException(
        'Nominatim forward geocode failed: ${response.statusCode}',
      );
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }
}

class LocationService {
  LocationService({LocationRepository? repository})
    : _repo = repository ?? LocationRepository(),
      _nominatim = _NominatimClient();

  final LocationRepository _repo;
  final _NominatimClient _nominatim;

  // ---------------------------------------------------------------------------
  // Device position
  // ---------------------------------------------------------------------------

  Future<Position> _acquirePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException(
        'Location services are disabled.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionException(
          'Location permission was denied.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException(
        'Location permission is permanently denied.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }


  Future<AddressComponents> _reverseGeocode(double lat, double lng) async {
    try {
      final json = await _nominatim.reverseGeocode(lat, lng);

      // Nominatim wraps address parts inside an "address" sub-object.
      final addr = (json['address'] as Map<String, dynamic>?) ?? {};

      final street = [
        addr['house_number'] as String?,
        addr['road'] as String?,
      ].where((s) => s != null && s.isNotEmpty).join(' ');

      final city =
          (addr['city'] as String?) ??
          (addr['town'] as String?) ??
          (addr['village'] as String?) ??
          '';

      final state = (addr['state'] as String?) ?? '';
      final country = (addr['country'] as String?) ?? '';
      final postalCode = (addr['postcode'] as String?) ?? '';
      final formatted = (json['display_name'] as String?) ?? '$lat, $lng';

      return AddressComponents(
        street: street,
        city: city,
        state: state,
        country: country,
        postalCode: postalCode,
        formattedAddress: formatted,
      );
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException(e.toString());
    }
  }


  Future<({double lat, double lng})> _forwardGeocodeCoords(
    String rawAddress,
  ) async {
    final results = await _nominatim.forwardGeocode(rawAddress);
    if (results.isEmpty) throw const GeocodingException('Address not found.');
    return (
      lat: double.parse(results.first['lat'] as String),
      lng: double.parse(results.first['lon'] as String),
    );
  }


  Future<LocationModel> saveCurrentLocation({
    required String userId,
    required String role,
    bool isVisible = true,
  }) async {
    final position = await _acquirePosition();
    final address = await _reverseGeocode(
      position.latitude,
      position.longitude,
    );
    final now = DateTime.now();

    final model = LocationModel(
      userId: userId,
      role: role,
      type: LocationType.currentLocation,
      coordinates: LatLng(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      address: address,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
      accuracy: position.accuracy,
      isVisible: isVisible,
    );

    await _repo.upsertCurrentLocation(model);
    return model;
  }

  Future<LocationModel> saveCustomLocation({
    required String userId,
    required String role,
    required String rawAddress,
    String? label,
    bool isDefault = false,
    bool isVisible = true,
  }) async {
    // Single forward-geocode call; reuse coords for both address + LatLng.
    final coords = await _forwardGeocodeCoords(rawAddress);
    final address = await _reverseGeocode(coords.lat, coords.lng);
    final now = DateTime.now();

    final model = LocationModel(
      userId: userId,
      role: role,
      type: LocationType.customAddress,
      coordinates: LatLng(latitude: coords.lat, longitude: coords.lng),
      address: address,
      label: label,
      isDefault: isDefault,
      createdAt: now,
      updatedAt: now,
      isVisible: isVisible,
    );

    final id = await _repo.addCustomLocation(model);
    return model.copyWith(id: id);
  }

  Future<void> deleteCustomLocation(String docId) =>
      _repo.deleteCustomLocation(docId);

  Future<void> setDefaultLocation({
    required String userId,
    required String role,
    required String locationId,
  }) => _repo.setDefaultLocation(userId, role, locationId);

  Stream<LocationModel?> watchCurrentLocation(String userId, String role) =>
      _repo.watchCurrentLocation(userId, role);

  Stream<List<LocationModel>> watchAllLocations(String userId, String role) =>
      _repo.watchAllLocations(userId, role);

  Future<LocationModel?> getDefaultLocation(String userId, String role) =>
      _repo.getDefaultLocation(userId, role);

  Future<LocationModel?> getCurrentLocation(String userId, String role) =>
      _repo.getCurrentLocation(userId, role);

  Future<double?> distanceBetween({
    required String userIdA,
    required String roleA,
    required String userIdB,
    required String roleB,
  }) async {
    final locA = await _repo.getCurrentLocation(userIdA, roleA);
    final locB = await _repo.getDefaultLocation(userIdB, roleB);

    if (locA == null || locB == null) return null;

    return _haversineKm(locA.coordinates, locB.coordinates);
  }


  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double deg) => deg * math.pi / 180;
}
