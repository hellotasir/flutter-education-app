import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'friend_requests';
  static const String _channelName = 'Friend Requests';
  static const String _channelDesc =
      'Notifications for incoming friend requests';
  static const String _badgeCountKey = 'notification_badge_count';

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    await _createAndroidChannel();
    await _requestAndroidPermissions();
  }

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestAndroidPermissions() async {
    if (!Platform.isAndroid) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showFriendRequestNotification({
    required String docId,
    required String fromFullName,
    required String fromUsername,
    required String fromProfilePhoto,
  }) async {
    final id = docId.hashCode.abs() % 100000;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: fromProfilePhoto.isNotEmpty
          ? FilePathAndroidBitmap(fromProfilePhoto)
          : null,
      styleInformation: BigTextStyleInformation(
        '$fromUsername sent you a friend request. Tap to respond.',
        summaryText: 'Friend Request',
      ),
      ticker: 'New friend request from $fromUsername',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: id,
      title: '👋 New Friend Request',
      body: '$fromFullName (@$fromUsername) wants to connect with you.',
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: docId,
    );

    await incrementBadge();
    debugPrint('[NotificationService] Showed notification for docId=$docId');
  }

  Future<void> incrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_badgeCountKey) ?? 0) + 1;
    await prefs.setInt(_badgeCountKey, next);
    final isSupported = await AppBadgePlus.isSupported();
    if (isSupported) {
      await AppBadgePlus.updateBadge(next);
    }
  }

  Future<void> decrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final next = ((prefs.getInt(_badgeCountKey) ?? 0) - 1).clamp(0, 999);
    await prefs.setInt(_badgeCountKey, next);
    final isSupported = await AppBadgePlus.isSupported();
    if (isSupported) {
      await AppBadgePlus.updateBadge(next);
    }
  }

  Future<void> clearBadge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_badgeCountKey, 0);
    final isSupported = await AppBadgePlus.isSupported();
    if (isSupported) {
      await AppBadgePlus.updateBadge(0);
    }
  }

  Future<int> getBadgeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_badgeCountKey) ?? 0;
  }

  Future<void> cancelNotification(String docId) async {
    final id = docId.hashCode.abs() % 100000;
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    await clearBadge();
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped, docId=${response.payload}');
  }
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  debugPrint('[NotificationService] Background tap: ${response.payload}');
}
