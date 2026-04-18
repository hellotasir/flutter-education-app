import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();

  Future<void> saveToken(String userId) async {
    try {
      final token = await NotificationService.instance.getFcmToken();
      if (token == null) {
        debugPrint('[FcmTokenService] No FCM token available yet.');
        return;
      }
      await _upsert(userId, token);

      NotificationService.instance.onTokenRefresh.listen((newToken) async {
        await _upsert(userId, newToken);
      });
    } catch (e) {
      debugPrint('[FcmTokenService] Error saving token: $e');
    }
  }

  Future<void> _upsert(String userId, String token) async {
    final client = Supabase.instance.client;
    final response = await client.from('user_fcm_tokens').upsert({
      'user_id': userId,
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    });
    debugPrint('[FcmTokenService] Token saved for user $userId → $response');
  }

  Future<void> removeToken(String userId) async {
    try {
      await Supabase.instance.client
          .from('user_fcm_tokens')
          .delete()
          .eq('user_id', userId);
      debugPrint('[FcmTokenService] Token removed for user $userId');
    } catch (e) {
      debugPrint('[FcmTokenService] Error removing token: $e');
    }
  }
}