import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_education_app/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kChannelId = 'friend_requests';
const _kChannelName = 'Friend Requests';
const _kUserId = 'bg_user_id';
const _kSeenIds = 'bg_seen_request_ids';

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: _kChannelId,
      initialNotificationTitle: 'Running in background',
      initialNotificationContent: 'Watching for new friend requests...',
      foregroundServiceNotificationId: 9999,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: _onServiceStart,
      onBackground: _onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> _onServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env.development');

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final localNotifications = FlutterLocalNotificationsPlugin();

  await localNotifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (_) {},
  );

  final androidImpl = localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidImpl?.createNotificationChannel(
    const AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      importance: Importance.high,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final savedUserId = prefs.getString(_kUserId);
  if (savedUserId != null && savedUserId.isNotEmpty) {
    _startWatching(savedUserId, localNotifications, service);
  }

  service.on('setUser').listen((data) async {
    final uid = data?['userId'] as String?;
    if (uid == null || uid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserId, uid);
    _startWatching(uid, localNotifications, service);
  });

  service.on('clearUser').listen((_) async {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserId);
    await p.remove(_kSeenIds);
    await AppBadgePlus.updateBadge(0);
  });

  service.on('stop').listen((_) => service.stopSelf());

  Timer.periodic(const Duration(seconds: 30), (_) {
    service.invoke('heartbeat', {'ts': DateTime.now().toIso8601String()});
  });
}

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

void _startWatching(
  String userId,
  FlutterLocalNotificationsPlugin localNotifications,
  ServiceInstance service,
) {
  _firestoreSub?.cancel();

  _firestoreSub = FirebaseFirestore.instance
      .collection('friend_requests')
      .where('to_user_id', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .listen((snap) async {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null) continue;
          await _handleNewRequest(
            change.doc.id,
            data,
            userId,
            localNotifications,
            service,
          );
        }
      });
}

Future<void> _handleNewRequest(
  String requestId,
  Map<String, dynamic> data,
  String userId,
  FlutterLocalNotificationsPlugin localNotifications,
  ServiceInstance service,
) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getStringList(_kSeenIds) ?? [];

  if (requestId.isEmpty || seen.contains(requestId)) return;

  final fullName = data['from_full_name'] as String? ?? '';
  final username = data['from_username'] as String? ?? 'Someone';
  final senderName = fullName.isNotEmpty ? fullName : '@$username';
  final payload = 'friend_request::$requestId';

  await localNotifications.show(
    id: requestId.hashCode,
    title: 'New Friend Request',
    body: '$senderName sent you a friend request',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
  );

  seen.add(requestId);
  await prefs.setStringList(_kSeenIds, seen);

  final pendingSnap = await FirebaseFirestore.instance
      .collection('friend_requests')
      .where('to_user_id', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .count()
      .get();

  final pendingCount = pendingSnap.count ?? 0;

  await AppBadgePlus.updateBadge(pendingCount);

  service.invoke('badgeCount', {'count': pendingCount});

  service.invoke('newFriendRequest', {
    'senderName': senderName,
    'payload': payload,
  });
}
