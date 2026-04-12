import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_education_app/others/services/local_notification_service.dart';
import 'package:flutter_education_app/others/services/poll_timestamp_store.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    try {
      // Fresh isolate — must re-initialise Firebase
      await Firebase.initializeApp();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true; // not logged in, skip silently

      final token = await user.getIdToken();
      if (token == null) return true;

      await LocalNotificationService.instance.init();

      final since = await PollTimestampStore.instance.load();
      final now = DateTime.now();

      final requests = await _queryViaRest(
        projectId: _projectId,
        idToken: token,
        userId: user.uid,
        since: since,
      );

      await PollTimestampStore.instance.save(now);

      for (final req in requests) {
        await LocalNotificationService.instance.showFriendRequest(
          requestId: req['id'] as String,
          fromUsername: req['from_username'] as String,
          fromFullName: req['from_full_name'] as String,
          fromUserId: req['from_user_id'] as String,
        );
      }

      return true;
    } catch (e) {
      print('[BGPoller] Error: $e');
      return false; // WorkManager will retry with backoff
    }
  });
}

// ── REST query (isolate-safe) ─────────────────────────────────────────────────

// Replace with your Firebase project ID or read from dart-define:
// --dart-define=FIREBASE_PROJECT_ID=your-project-id
const _projectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: 'your-project-id',
);

Future<List<Map<String, String>>> _queryViaRest({
  required String projectId,
  required String idToken,
  required String userId,
  required DateTime since,
}) async {
  final url = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId'
    '/databases/(default)/documents:runQuery',
  );

  final body = jsonEncode({
    'structuredQuery': {
      'from': [
        {'collectionId': 'friend_requests'},
      ],
      'where': {
        'compositeFilter': {
          'op': 'AND',
          'filters': [
            {
              'fieldFilter': {
                'field': {'fieldPath': 'to_user_id'},
                'op': 'EQUAL',
                'value': {'stringValue': userId},
              },
            },
            {
              'fieldFilter': {
                'field': {'fieldPath': 'status'},
                'op': 'EQUAL',
                'value': {'stringValue': 'pending'},
              },
            },
            {
              'fieldFilter': {
                'field': {'fieldPath': 'sent_at'},
                'op': 'GREATER_THAN',
                'value': {'timestampValue': since.toUtc().toIso8601String()},
              },
            },
          ],
        },
      },
      // Only fetch fields needed for the notification — minimises read bytes
      'select': {
        'fields': [
          {'fieldPath': 'from_user_id'},
          {'fieldPath': 'from_username'},
          {'fieldPath': 'from_full_name'},
        ],
      },
    },
  });

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: body,
  );

  if (response.statusCode != 200) return [];

  final results = jsonDecode(response.body) as List<dynamic>;
  final docs = <Map<String, String>>[];

  for (final result in results) {
    final doc = result['document'] as Map<String, dynamic>?;
    if (doc == null) continue;

    final fields = doc['fields'] as Map<String, dynamic>?;
    if (fields == null) continue;

    String str(String key) {
      final f = fields[key] as Map<String, dynamic>?;
      return f?['stringValue'] as String? ?? '';
    }

    docs.add({
      'id': (doc['name'] as String).split('/').last,
      'from_user_id': str('from_user_id'),
      'from_username': str('from_username'),
      'from_full_name': str('from_full_name'),
    });
  }

  return docs;
}

// ── Registration ──────────────────────────────────────────────────────────────

class BackgroundPoller {
  BackgroundPoller._();
  static final instance = BackgroundPoller._();

  static const _uniqueName = 'friendRequestPoll';

  Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  Future<void> register() async {
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _uniqueName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
  }
}
