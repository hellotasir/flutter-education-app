import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/features/track/models/local_model.dart';

/// Handles all Firestore CRUD for the `locations` collection.
///
/// Collection path: `locations/{locationId}`
///
/// Design notes
/// ─────────────
/// • Students may have exactly **one** location document (current position).
///   Saving a new position **overwrites** the previous one.
/// • Instructors may have **multiple** location documents:
///     – one `current_location` (upserted by GPS)
///     – N `custom_address` entries (home, studio, etc.)
///   Each instructor document carries an `is_default` flag so the app knows
///   which address to show students in search results.
class LocationRepository {
  LocationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'locations';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  // ── Shared helpers ──────────────────────────────────────────────────────────

  /// Converts a raw [DocumentSnapshot] to [LocationModel].
  LocationModel fromSnapshot(DocumentSnapshot doc) =>
      LocationModel.fromSnapshot(doc);

  // ── Student API ─────────────────────────────────────────────────────────────

  /// Upserts the student's **current location** document.
  ///
  /// Students only ever have a single location document.  This uses a
  /// deterministic document ID (`student_{userId}`) so repeated calls always
  /// overwrite instead of creating duplicates.
  Future<void> upsertStudentLocation(LocationModel location) async {
    assert(
      location.role == 'student',
      'Use upsertStudentLocation for students only',
    );
    assert(
      location.type == LocationType.currentLocation,
      'Students can only upload current location',
    );

    final docId = 'student_${location.userId}';
    final data = location.toMap()
      ..['updated_at'] = FieldValue.serverTimestamp();

    await _ref.doc(docId).set(data, SetOptions(merge: true));
    debugPrint('✅ Student location upserted [$docId]');
  }

  /// Stream of the student's single location document.
  Stream<LocationModel?> watchStudentLocation(String userId) {
    final docId = 'student_$userId';
    return _ref.doc(docId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return fromSnapshot(snap);
    });
  }

  /// One-shot fetch of the student's location.
  Future<LocationModel?> getStudentLocation(String userId) async {
    final docId = 'student_$userId';
    final snap = await _ref.doc(docId).get();
    if (!snap.exists) return null;
    return fromSnapshot(snap);
  }

  // ── Instructor API ──────────────────────────────────────────────────────────

  /// Upserts the instructor's **GPS current location** (one per instructor).
  Future<void> upsertInstructorCurrentLocation(LocationModel location) async {
    assert(location.role == 'instructor');
    assert(location.type == LocationType.currentLocation);

    final docId = 'instructor_current_${location.userId}';
    final data = location.toMap()
      ..['updated_at'] = FieldValue.serverTimestamp();

    await _ref.doc(docId).set(data, SetOptions(merge: true));
    debugPrint('✅ Instructor current location upserted [$docId]');
  }

  /// Adds a **custom address** for an instructor (e.g. "Home", "Studio").
  ///
  /// Returns the new document ID.
  Future<String> addInstructorCustomAddress(LocationModel location) async {
    assert(location.role == 'instructor');
    assert(location.type == LocationType.customAddress);

    final data = location.toMap()
      ..['created_at'] = FieldValue.serverTimestamp()
      ..['updated_at'] = FieldValue.serverTimestamp();

    // If this is marked default, clear existing defaults first
    if (location.isDefault) {
      await _clearInstructorDefaults(location.userId);
    }

    final docRef = await _ref.add(data);
    debugPrint('✅ Instructor custom address added [${docRef.id}]');
    return docRef.id;
  }

  /// Updates an existing custom address document.
  Future<void> updateInstructorCustomAddress(LocationModel location) async {
    assert(location.id != null, 'Document ID required for update');
    assert(location.role == 'instructor');

    if (location.isDefault) {
      await _clearInstructorDefaults(location.userId);
    }

    final data = location.toMap()
      ..['updated_at'] = FieldValue.serverTimestamp();

    await _ref.doc(location.id).update(data);
    debugPrint('✅ Instructor custom address updated [${location.id}]');
  }

  /// Deletes a custom address by document ID.
  Future<void> deleteInstructorCustomAddress(String docId) async {
    await _ref.doc(docId).delete();
    debugPrint('✅ Instructor custom address deleted [$docId]');
  }

  /// Sets a specific address as the instructor's default.
  Future<void> setDefaultAddress(String userId, String docId) async {
    final batch = _db.batch();

    // Clear all existing defaults for this instructor
    final existing = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: 'instructor')
        .where('is_default', isEqualTo: true)
        .get();

    for (final doc in existing.docs) {
      batch.update(doc.reference, {'is_default': false});
    }

    // Set the new default
    batch.update(_ref.doc(docId), {
      'is_default': true,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('✅ Default address set [$docId]');
  }

  /// Stream of **all** instructor location documents (current + custom).
  Stream<List<LocationModel>> watchInstructorLocations(String userId) {
    return _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: 'instructor')
        .snapshots()
        .map(
          (snap) => snap.docs.map(fromSnapshot).toList()
            ..sort((a, b) {
              // current_location always first
              if (a.type == LocationType.currentLocation) return -1;
              if (b.type == LocationType.currentLocation) return 1;
              // then default custom address
              if (a.isDefault) return -1;
              if (b.isDefault) return 1;
              return 0;
            }),
        );
  }

  /// Fetch the instructor's **default** address (shown to students in search).
  ///
  /// Priority: custom default → current location → first available.
  Future<LocationModel?> getInstructorDefaultLocation(String userId) async {
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: 'instructor')
        .where('is_visible', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return null;

    final locations = snap.docs.map(fromSnapshot).toList();

    // 1) prefer custom default
    final customDefault = locations.firstWhereOrNull(
      (l) => l.type == LocationType.customAddress && l.isDefault,
    );
    if (customDefault != null) return customDefault;

    // 2) fall back to current location
    final current = locations.firstWhereOrNull(
      (l) => l.type == LocationType.currentLocation,
    );
    if (current != null) return current;

    // 3) any visible location
    return locations.first;
  }

  // ── Student-visible instructor addresses ────────────────────────────────────

  /// Returns the **visible** instructor addresses a student can see.
  ///
  /// Students only see address strings, never raw coordinates, unless the
  /// app explicitly needs to compute distance — in which case coordinates
  /// are needed but should not be surfaced in the UI.
  Future<List<LocationModel>> getVisibleInstructorLocations(
    String instructorId,
  ) async {
    final snap = await _ref
        .where('user_id', isEqualTo: instructorId)
        .where('role', isEqualTo: 'instructor')
        .where('is_visible', isEqualTo: true)
        .get();

    return snap.docs.map(fromSnapshot).toList();
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _clearInstructorDefaults(String userId) async {
    final batch = _db.batch();
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: 'instructor')
        .where('is_default', isEqualTo: true)
        .get();

    for (final doc in snap.docs) {
      batch.update(doc.reference, {'is_default': false});
    }
    await batch.commit();
  }
}

// Tiny helper — avoids importing collection_package
extension _IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
