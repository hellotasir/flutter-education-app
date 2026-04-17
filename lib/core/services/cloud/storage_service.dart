import 'dart:io';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService();

  final String bucket = 'user-media';
  static const _chatBucket = 'chat-media';

  SupabaseClient get _client => Supabase.instance.client;
  
  Future<String> uploadChatMedia({
    required File file,
    required String senderId,
    required String folder,
  }) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final ext = _extFromMime(mimeType);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$folder/$senderId/$timestamp.$ext';

      await _client.storage
          .from(_chatBucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      return _client.storage.from(_chatBucket).getPublicUrl(path);
    } on StorageException catch (e) {
      throw Exception('Chat media upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error uploading chat media: $e');
    }
  }

  Future<String> uploadThumbnail({
    required File thumbnailFile,
    required String senderId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'thumbnails/$senderId/$timestamp.jpg';

      await _client.storage
          .from(_chatBucket)
          .upload(
            path,
            thumbnailFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      return _client.storage.from(_chatBucket).getPublicUrl(path);
    } on StorageException catch (e) {
      throw Exception('Thumbnail upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error uploading thumbnail: $e');
    }
  }


  Future<String> uploadGroupPhoto(File imageFile, String adminUserId) async {
    try {
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final ext = _extFromMime(mimeType);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'groups/$adminUserId/$timestamp.$ext';

      await _client.storage
          .from(_chatBucket)
          .upload(
            path,
            imageFile,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      return _client.storage.from(_chatBucket).getPublicUrl(path);
    } on StorageException catch (e) {
      throw Exception('Group photo upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error uploading group photo: $e');
    }
  }


  Future<String> uploadAvatar(
    String userId,
    String roleLabel,
    File file,
  ) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final ext = _extFromMime(mimeType);
      final path = avatarPath(userId, roleLabel, ext);

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

  Future<String> uploadCoverPhoto(String userId, File file) async {
    try {
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final ext = _extFromMime(mimeType);
      final path = coverPath(userId, ext);

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

  Future<void> deleteFile(String storagePath) async {
    try {
      await _client.storage.from(bucket).remove([storagePath]);
    } on StorageException catch (e) {
      throw Exception('Failed to delete file: ${e.message}');
    }
  }

  String avatarPath(String userId, String roleLabel, String ext) =>
      'avatars/$userId/$roleLabel.$ext';

  String coverPath(String userId, String ext) => 'covers/$userId/cover.$ext';


  String _extFromMime(String mimeType) {
    const map = <String, String>{
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'video/mp4': 'mp4',
      'video/quicktime': 'mov',
      'audio/mpeg': 'mp3',
      'audio/mp4': 'm4a',
      'audio/aac': 'aac',
      'audio/wav': 'wav',
      'audio/x-wav': 'wav',
      'application/pdf': 'pdf',
      'application/msword': 'doc',
      'application/vnd.openxmlformats-officedocument'
              '.wordprocessingml.document':
          'docx',
      'application/vnd.ms-excel': 'xls',
      'application/vnd.openxmlformats-officedocument'
              '.spreadsheetml.sheet':
          'xlsx',
      'text/plain': 'txt',
      'application/zip': 'zip',
    };
    return map[mimeType] ?? mimeType.split('/').last;
  }
}