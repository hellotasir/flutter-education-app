// ignore_for_file: unused_element

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/features/track/models/local_model.dart';
import 'package:flutter_education_app/features/track/repositories/local_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// High-level service that glues together:
///   • Device GPS  (via `geolocator`)
///   • Nominatim / OpenStreetMap  (reverse + forward geocoding — no API key required)
///   • Distance calculation (Haversine)
///   • Firestore persistence  (via [LocationRepository])
///
/// ─────────────────────────────────────────────────────────────────────────────
/// USAGE PATTERN
/// ─────────────────────────────────────────────────────────────────────────────
///
///   // Student saves GPS fix
///   await locationService.saveStudentCurrentLocation(userId: userId);
///
///   // Instructor saves GPS fix
///   await locationService.saveInstructorCurrentLocation(userId: userId);
///
///   // Instructor adds custom address
///   await locationService.saveInstructorCustomAddress(
///     userId: userId,
///     rawAddress: '221B Baker Street, London',
///     label: 'Studio',
///     isDefault: true,
///   );
///
///   // Student measures distance to instructor
///   final km = await locationService.distanceToInstructor(
///     studentUserId: studentId,
///     instructorUserId: instructorId,
///   );
///
class LocationService {
  LocationService({LocationRepository? repository, http.Client? httpClient})
    : _repository = repository ?? LocationRepository(),
      _http = httpClient ?? http.Client();

  final LocationRepository _repository;
  final http.Client _http;

  /// Nominatim base URL — free, no API key, no credit card required.
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// User-Agent is required by Nominatim's usage policy.
  /// Replace 'EduMapApp/1.0' with your actual app name + version.
  static const Map<String, String> _nominatimHeaders = {
    'Accept-Language': 'en',
    'User-Agent': 'EduMapApp/1.0',
  };

  // ── Permission & GPS ────────────────────────────────────────────────────────

  /// Requests location permission if not already granted.
  /// Throws [LocationPermissionException] when permanently denied.
  Future<void> ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionException(
        'Location permission is permanently denied. '
        'Please enable it in device settings.',
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException(
        'Location services are disabled on this device.',
      );
    }
  }

  Future<void> setDefaultAddress({
    required String userId,
    required String locationId,
  }) {
    return _repository.setDefaultAddress(userId, locationId);
  }

  Future<LocationModel?> getInstructorDefaultLocation(String instructorUserId) {
    return _repository.getInstructorDefaultLocation(instructorUserId);
  }

  /// Gets the device's current GPS position.
  Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    await ensurePermission();
    return Geolocator.getCurrentPosition(
      desiredAccuracy: accuracy,
      timeLimit: const Duration(seconds: 15),
    );
  }

  // ── Geocoding (Nominatim / OpenStreetMap) ───────────────────────────────────

  /// Reverse-geocodes [latLng] into a human-readable [AddressComponents].
  /// Uses Nominatim — free, no API key required.
  Future<AddressComponents> reverseGeocode(LatLng latLng) async {
    final uri = Uri.parse(
      '$_nominatimBaseUrl/reverse'
      '?lat=${latLng.latitude}'
      '&lon=${latLng.longitude}'
      '&format=json',
    );

    final response = await _http.get(uri, headers: _nominatimHeaders);

    if (response.statusCode != 200) {
      throw GeocodingException(
        'Reverse geocode failed with status ${response.statusCode}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body.containsKey('error')) {
      return const AddressComponents(
        street: '',
        city: '',
        state: '',
        country: '',
        postalCode: '',
        formattedAddress: 'Unknown location',
      );
    }

    return _parseNominatimAddress(body);
  }

  /// Forward-geocodes a [rawAddress] string into [LatLng] + [AddressComponents].
  /// Uses Nominatim — free, no API key required.
  Future<({LatLng coordinates, AddressComponents address})> forwardGeocode(
    String rawAddress,
  ) async {
    final uri = Uri.parse(
      '$_nominatimBaseUrl/search'
      '?q=${Uri.encodeComponent(rawAddress)}'
      '&format=json'
      '&limit=1',
    );

    final response = await _http.get(uri, headers: _nominatimHeaders);

    if (response.statusCode != 200) {
      throw GeocodingException(
        'Forward geocode failed with status ${response.statusCode}',
      );
    }

    final results = jsonDecode(response.body) as List<dynamic>;

    if (results.isEmpty) {
      throw GeocodingException('No results found for address: $rawAddress');
    }

    final first = results.first as Map<String, dynamic>;

    return (
      coordinates: LatLng(
        latitude: double.parse(first['lat'] as String),
        longitude: double.parse(first['lon'] as String),
      ),
      address: _parseNominatimAddress(first),
    );
  }

  // ── Student operations ──────────────────────────────────────────────────────

  /// Fetches device GPS, reverse-geocodes it, and saves as the student's
  /// current location. Always overwrites the previous document.
  Future<LocationModel> saveStudentCurrentLocation({
    required String userId,
  }) async {
    final position = await getCurrentPosition();
    final coords = LatLng(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final address = await reverseGeocode(coords);

    final model = LocationModel(
      userId: userId,
      role: 'student',
      type: LocationType.currentLocation,
      coordinates: coords,
      address: address,
      isDefault: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      accuracy: position.accuracy,
      isVisible: false, // students' locations are never shown to others
    );

    await _repository.upsertStudentLocation(model);
    debugPrint('📍 Student location saved: ${address.formattedAddress}');
    return model;
  }

  // ── Instructor operations ───────────────────────────────────────────────────

  /// Fetches device GPS, reverse-geocodes it, and upserts the instructor's
  /// current-location document.
  Future<LocationModel> saveInstructorCurrentLocation({
    required String userId,
    bool isVisible = true,
  }) async {
    final position = await getCurrentPosition();
    final coords = LatLng(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final address = await reverseGeocode(coords);

    final model = LocationModel(
      userId: userId,
      role: 'instructor',
      type: LocationType.currentLocation,
      coordinates: coords,
      address: address,
      isDefault: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      accuracy: position.accuracy,
      isVisible: isVisible,
    );

    await _repository.upsertInstructorCurrentLocation(model);
    debugPrint('📍 Instructor GPS location saved: ${address.formattedAddress}');
    return model;
  }

  /// Forward-geocodes [rawAddress] and saves it as an instructor custom address.
  Future<LocationModel> saveInstructorCustomAddress({
    required String userId,
    required String rawAddress,
    String? label,
    bool isDefault = false,
    bool isVisible = true,
  }) async {
    final result = await forwardGeocode(rawAddress);

    final model = LocationModel(
      userId: userId,
      role: 'instructor',
      type: LocationType.customAddress,
      coordinates: result.coordinates,
      address: result.address,
      label: label,
      isDefault: isDefault,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isVisible: isVisible,
    );

    final docId = await _repository.addInstructorCustomAddress(model);
    debugPrint(
      '📍 Instructor custom address saved [$docId]: ${result.address.formattedAddress}',
    );
    return model.copyWith(id: docId);
  }

  /// Updates an existing instructor custom address (identified by [model.id]).
  Future<LocationModel> updateInstructorCustomAddress({
    required LocationModel model,
    String? newRawAddress,
    String? label,
    bool? isDefault,
    bool? isVisible,
  }) async {
    LocationModel updated = model.copyWith(
      label: label,
      isDefault: isDefault,
      isVisible: isVisible,
      updatedAt: DateTime.now(),
    );

    if (newRawAddress != null) {
      final result = await forwardGeocode(newRawAddress);
      updated = updated.copyWith(
        coordinates: result.coordinates,
        address: result.address,
      );
    }

    await _repository.updateInstructorCustomAddress(updated);
    return updated;
  }

  /// Deletes an instructor custom address document.
  Future<void> deleteInstructorCustomAddress(String docId) =>
      _repository.deleteInstructorCustomAddress(docId);

  // ── Distance calculation ────────────────────────────────────────────────────

  /// Computes the straight-line (Haversine) distance in **kilometres**
  /// between a student's saved location and an instructor's default address.
  ///
  /// Returns `null` if either location is unavailable.
  Future<double?> distanceToInstructor({
    required String studentUserId,
    required String instructorUserId,
  }) async {
    final studentLoc = await _repository.getStudentLocation(studentUserId);
    final instructorLoc = await _repository.getInstructorDefaultLocation(
      instructorUserId,
    );

    if (studentLoc == null || instructorLoc == null) return null;

    return _haversineKm(studentLoc.coordinates, instructorLoc.coordinates);
  }

  /// Computes distance between two [LatLng] points using the Haversine formula.
  double _haversineKm(LatLng a, LatLng b) {
    const double earthRadiusKm = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final h =
        sinDLat * sinDLat +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            sinDLon *
            sinDLon;
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  // ── Streams (pass-through convenience) ─────────────────────────────────────

  Stream<LocationModel?> watchStudentLocation(String userId) =>
      _repository.watchStudentLocation(userId);

  Stream<List<LocationModel>> watchInstructorLocations(String userId) =>
      _repository.watchInstructorLocations(userId);

  // ── Private ─────────────────────────────────────────────────────────────────

  /// Parses a Nominatim response (both /reverse and /search) into [AddressComponents].
  AddressComponents _parseNominatimAddress(Map<String, dynamic> body) {
    final address = body['address'] as Map<String, dynamic>? ?? {};

    final street = [
      address['house_number']?.toString() ?? '',
      address['road']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    final city =
        (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['county'] ??
                '')
            .toString();

    return AddressComponents(
      street: street,
      city: city,
      state: address['state']?.toString() ?? '',
      country: address['country']?.toString() ?? '',
      postalCode: address['postcode']?.toString() ?? '',
      formattedAddress: body['display_name']?.toString() ?? '',
    );
  }
}

// ── Typed exceptions ──────────────────────────────────────────────────────────

class LocationPermissionException implements Exception {
  LocationPermissionException(this.message);
  final String message;
  @override
  String toString() => 'LocationPermissionException: $message';
}

class LocationServiceDisabledException implements Exception {
  LocationServiceDisabledException(this.message);
  final String message;
  @override
  String toString() => 'LocationServiceDisabledException: $message';
}

class GeocodingException implements Exception {
  GeocodingException(this.message);
  final String message;
  @override
  String toString() => 'GeocodingException: $message';
}

extension _IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
