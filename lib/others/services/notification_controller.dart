// lib/features/notifications/services/notification_coordinator.dart
//
// Wires your existing FirestoreService<FriendRequestModel> into the poller.
// Call init() once in main(), start() on login, stop() on logout.

import 'package:flutter/widgets.dart';
import 'package:flutter_education_app/features/chat/models/friend_request_model.dart';
import 'package:flutter_education_app/features/chat/repositories/friend_request_repository.dart';
import 'package:flutter_education_app/others/services/database_service.dart';
import 'package:flutter_education_app/others/services/forground_poller.dart';
import 'package:flutter_education_app/others/services/local_notification_service.dart';
import 'package:flutter_education_app/others/services/poll_timestamp_store.dart';
import 'background_poller.dart';

class NotificationCoordinator with WidgetsBindingObserver {
  NotificationCoordinator._();
  static final instance = NotificationCoordinator._();

  // Build the service the same way FirestoreProvider does, but as a singleton
  // so we don't depend on a BuildContext here.
  late final ForegroundPoller _foregroundPoller = ForegroundPoller(
    service: FirestoreService<FriendRequestModel>(
      const FriendRequestRepository(),
    ),
  );

  bool _started = false;

  /// Call once after Firebase.initializeApp(), before runApp().
  Future<void> init() async {
    await LocalNotificationService.instance.init();
    await BackgroundPoller.instance.init();
  }

  /// Call after user logs in.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await BackgroundPoller.instance.register();
    _foregroundPoller.start();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Call on logout.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _foregroundPoller.stop();
    await BackgroundPoller.instance.cancel();
    await PollTimestampStore.instance.clear();
    WidgetsBinding.instance.removeObserver(this);
  }

  // ── App lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foregroundPoller.start();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foregroundPoller.stop(); // WorkManager handles background
      default:
        break;
    }
  }
}
