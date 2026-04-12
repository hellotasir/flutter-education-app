import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';
import 'package:flutter_education_app/features/chat/models/friend_request_model.dart';
import 'package:flutter_education_app/others/services/database_service.dart';
import 'package:flutter_education_app/others/services/local_notification_service.dart';
import 'package:flutter_education_app/others/services/poll_timestamp_store.dart';

class ForegroundPoller {
  ForegroundPoller({required FirestoreService<FriendRequestModel> service})
    : _service = service;

  final FirestoreService<FriendRequestModel> _service;

  static const _interval = Duration(seconds: 30);
  Timer? _timer;

  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    if (isRunning) return;
    _poll(); // immediate first poll
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final since = await PollTimestampStore.instance.load();
      final now = DateTime.now();

      final requests = await _service.getAll(
        query: (col) => col
            .where('to_user_id', isEqualTo: _service.currentUserId)
            .where('status', isEqualTo: FriendRequestStatus.pending.name)
            // Only docs newer than last check → 0 reads when nothing is new
            .where('sent_at', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('sent_at', descending: true),
      );

      // Save timestamp before showing notifications
      await PollTimestampStore.instance.save(now);

      for (final req in requests) {
        await LocalNotificationService.instance.showFriendRequest(
          requestId: req.id ?? req.fromUserId,
          fromUsername: req.fromUsername,
          fromFullName: req.fromFullName,
          fromUserId: req.fromUserId,
        );
      }
    } catch (e) {
      // Swallow — don't crash the app if a poll fails
      print('[ForegroundPoller] Error: $e');
    }
  }
}
