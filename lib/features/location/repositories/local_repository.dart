import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';

class LocationRepository {
  LocationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'locations';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  LocationModel _fromSnapshot(DocumentSnapshot doc) =>
      LocationModel.fromSnapshot(doc);

  Future<void> upsertCurrentLocation(LocationModel location) async {
    assert(location.type == LocationType.currentLocation);

    final prefix = location.role == 'student'
        ? 'student'
        : 'instructor_current';
    final docId = '${prefix}_${location.userId}';
    final data = location.toMap()
      ..['updated_at'] = FieldValue.serverTimestamp();

    await _ref.doc(docId).set(data, SetOptions(merge: true));
    debugPrint('location upserted [$docId]');
  }

  Stream<LocationModel?> watchCurrentLocation(String userId, String role) {
    final prefix = role == 'student' ? 'student' : 'instructor_current';
    final docId = '${prefix}_$userId';
    return _ref
        .doc(docId)
        .snapshots()
        .map((snap) => snap.exists ? _fromSnapshot(snap) : null);
  }

  Future<LocationModel?> getCurrentLocation(String userId, String role) async {
    final prefix = role == 'student' ? 'student' : 'instructor_current';
    final snap = await _ref.doc('${prefix}_$userId').get();
    if (!snap.exists) return null;
    return _fromSnapshot(snap);
  }

  Future<String> addCustomLocation(LocationModel location) async {
    assert(location.type == LocationType.customAddress);

    final data = location.toMap()
      ..['created_at'] = FieldValue.serverTimestamp()
      ..['updated_at'] = FieldValue.serverTimestamp();

    if (location.isDefault) {
      await _clearDefaults(location.userId, location.role);
    }

    final docRef = await _ref.add(data);
    return docRef.id;
  }

  Future<void> updateCustomLocation(LocationModel location) async {
    assert(location.id != null);
    if (location.isDefault) {
      await _clearDefaults(location.userId, location.role);
    }
    final data = location.toMap()
      ..['updated_at'] = FieldValue.serverTimestamp();
    await _ref.doc(location.id).update(data);
  }

  Future<void> deleteCustomLocation(String docId) async {
    await _ref.doc(docId).delete();
  }

  Future<void> setDefaultLocation(
    String userId,
    String role,
    String docId,
  ) async {
    final batch = _db.batch();

    final existing = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .where('is_default', isEqualTo: true)
        .get();

    for (final doc in existing.docs) {
      batch.update(doc.reference, {'is_default': false});
    }

    batch.update(_ref.doc(docId), {
      'is_default': true,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<LocationModel>> watchAllLocations(String userId, String role) {
    return _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .snapshots()
        .map(
          (snap) => snap.docs.map(_fromSnapshot).toList()
            ..sort((a, b) {
              if (a.type == LocationType.currentLocation) return -1;
              if (b.type == LocationType.currentLocation) return 1;
              if (a.isDefault) return -1;
              if (b.isDefault) return 1;
              return 0;
            }),
        );
  }

  Future<LocationModel?> getDefaultLocation(String userId, String role) async {
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .where('is_visible', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return null;

    final locations = snap.docs.map(_fromSnapshot).toList();

    final customDefault = locations.firstWhereOrNull(
      (l) => l.type == LocationType.customAddress && l.isDefault,
    );
    if (customDefault != null) return customDefault;

    final current = locations.firstWhereOrNull(
      (l) => l.type == LocationType.currentLocation,
    );
    if (current != null) return current;

    return locations.first;
  }

  Future<void> _clearDefaults(String userId, String role) async {
    final batch = _db.batch();
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .where('is_default', isEqualTo: true)
        .get();

    for (final doc in snap.docs) {
      batch.update(doc.reference, {'is_default': false});
    }
    await batch.commit();
  }
}

extension _IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
