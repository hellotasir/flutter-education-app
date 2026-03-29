import 'dart:io';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// SupabaseStorageService
//
// No required constructor arguments.
// Bucket defaults to 'user-media'; override at call site if needed.
//
// Storage layout:
//   avatars/{userId}/{roleLabel}.{ext}   — profile photo per role
//   covers/{userId}/cover.{ext}          — cover photo
// =============================================================================

class SupabaseStorageService {
  SupabaseStorageService({this.bucket = 'user-media'});

  final String bucket;

  SupabaseClient get _client => Supabase.instance.client;

  // ── Avatar ────────────────────────────────────────────────────────────────

  /// Uploads [file] as the avatar for [userId] in [roleLabel] mode.
  /// Uses upsert so repeated uploads for the same role overwrite the previous.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadAvatar(
    String userId,
    String roleLabel,
    File file,
  ) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final ext = mimeType.split('/').last;
      final path = 'avatars/$userId/$roleLabel.$ext';

      await _client.storage
          .from(bucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );

      return _client.storage.from(bucket).getPublicUrl(path);
    } on StorageException catch (e) {
      throw Exception('Avatar upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error uploading avatar: $e');
    }
  }

  // ── Cover photo ───────────────────────────────────────────────────────────

  /// Uploads [file] as the cover photo for [userId].
  /// Returns the public URL of the uploaded image.
  Future<String> uploadCoverPhoto(String userId, File file) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final ext = mimeType.split('/').last;
      final path = 'covers/$userId/cover.$ext';

      await _client.storage
          .from(bucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );

      return _client.storage.from(bucket).getPublicUrl(path);
    } on StorageException catch (e) {
      throw Exception('Cover photo upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error uploading cover photo: $e');
    }
  }

  // ── Signed URL ────────────────────────────────────────────────────────────

  /// Returns a time-limited signed URL for a private [storagePath].
  /// Default expiry: 1 hour.
  Future<String> getSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(storagePath, expiresInSeconds);
    } on StorageException catch (e) {
      throw Exception('Failed to create signed URL: ${e.message}');
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes a file at [storagePath] from the bucket.
  Future<void> deleteFile(String storagePath) async {
    try {
      await _client.storage.from(bucket).remove([storagePath]);
    } on StorageException catch (e) {
      throw Exception('Failed to delete file: ${e.message}');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Derives the avatar storage path for [userId] in [roleLabel] mode.
  /// Useful when you need to delete an existing avatar before uploading a new one.
  String avatarPath(String userId, String roleLabel, String ext) =>
      'avatars/$userId/$roleLabel.$ext';

  /// Derives the cover storage path for [userId].
  String coverPath(String userId, String ext) => 'covers/$userId/cover.$ext';
}
