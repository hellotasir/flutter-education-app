import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _kChannelId = 'friend_requests';
const _kChannelName = 'Friend Requests';

class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  final _tapController = StreamController<String>.broadcast();
  Stream<String> get tapStream => _tapController.stream;

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl!.createNotificationChannel(
      const AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        importance: Importance.high,
      ),
    );

    await androidImpl.requestNotificationsPermission();

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_tapController.isClosed) _tapController.add(payload);
      });
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
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
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);
  Future<void> cancelAll() => _plugin.cancelAll();

  void _onTap(NotificationResponse response) {
    final p = response.payload;
    if (p != null && p.isNotEmpty && !_tapController.isClosed) {
      _tapController.add(p);
    }
  }

  void dispose() => _tapController.close();
}

@pragma('vm:entry-point')
void _onBackgroundTap(NotificationResponse response) {}
