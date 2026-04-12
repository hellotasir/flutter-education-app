// lib/features/notifications/services/local_notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'friend_requests',
            'Friend Requests',
            description: 'Incoming friend requests',
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  Future<void> showFriendRequest({
    required String requestId,
    required String fromUsername,
    required String fromFullName,
    required String fromUserId,
  }) async {
    await init();
    final name = fromFullName.isNotEmpty ? fromFullName : '@$fromUsername';

    await _plugin.show(
      id: requestId.hashCode,
      title: 'New Friend Request 👋',
      body: '$name wants to be your friend',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'friend_requests',
          'Friend Requests',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'friend_request|$requestId|$fromUserId',
    );
  }
}
