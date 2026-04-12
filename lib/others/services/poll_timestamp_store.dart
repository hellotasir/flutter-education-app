// lib/features/notifications/services/poll_timestamp_store.dart
//
// Persists the last-polled timestamp in SharedPreferences.
// Both the foreground Timer and the WorkManager isolate share this value
// so they never re-notify for the same document.

import 'package:shared_preferences/shared_preferences.dart';

class PollTimestampStore {
  PollTimestampStore._();
  static final instance = PollTimestampStore._();

  static const _key = 'notif_last_polled_ms';

  /// Load the last saved timestamp. Defaults to 5 minutes ago on first run.
  Future<DateTime> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key);
    if (ms == null) {
      return DateTime.now().subtract(const Duration(minutes: 5));
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> save(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, dt.millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}