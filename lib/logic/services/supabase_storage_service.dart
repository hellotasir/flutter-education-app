import 'dart:io';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  SupabaseStorageService({String bucket = 'user-media'}) : _bucket = bucket;

  final String _bucket;

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> uploadAvatar(String uid, String roleLabel, File file) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final ext = mimeType.split('/').last;
      final storagePath = 'avatars/$uid/$roleLabel.$ext';

      await _client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(upsert: true, contentType: mimeType),
          );

      return _client.storage.from(_bucket).getPublicUrl(storagePath);
    } on StorageException catch (e) {
      throw Exception('Avatar upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected upload error: $e');
    }
  }

  Future<String> getSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      return await _client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, expiresInSeconds);
    } on StorageException catch (e) {
      throw Exception('Failed to get signed URL: ${e.message}');
    }
  }

  Future<void> deleteFile(String storagePath) async {
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
    } on StorageException catch (e) {
      throw Exception('Failed to delete file: ${e.message}');
    }
  }
}
