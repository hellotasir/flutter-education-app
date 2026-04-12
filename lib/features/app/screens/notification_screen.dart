// lib/features/notifications/notification_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/widgets/material_widget.dart';
import 'package:intl/intl.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class _FriendRequest {
  const _FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromFullName,
    required this.fromProfilePhoto,
    required this.sentAt,
  });

  final String id;
  final String fromUserId;
  final String fromUsername;
  final String fromFullName;
  final String fromProfilePhoto;
  final DateTime sentAt;

  String get displayName =>
      fromFullName.isNotEmpty ? fromFullName : '@$fromUsername';

  static _FriendRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return _FriendRequest(
      id: doc.id,
      fromUserId: d['from_user_id'] as String? ?? '',
      fromUsername: d['from_username'] as String? ?? '',
      fromFullName: d['from_full_name'] as String? ?? '',
      fromProfilePhoto: d['from_profile_photo'] as String? ?? '',
      sentAt: (d['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _db = FirebaseFirestore.instance;

  // NOTE: This snapshot listener is ONLY active while the screen is open.
  // It does NOT replace the REST polling — it's just for live UI updates
  // while the user is looking at this screen.
  Stream<List<_FriendRequest>> get _stream => _db
      .collection('friend_requests')
      .where('to_user_id', isEqualTo: _uid)
      .where('status', isEqualTo: 'pending')
      .orderBy('sent_at', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_FriendRequest.fromDoc).toList());

  Future<void> _respond(String docId, String status) async {
    await _db.collection('friend_requests').doc(docId).update({
      'status': status,
      'responded_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _dismissAll(List<_FriendRequest> list) async {
    final batch = _db.batch();
    for (final r in list) {
      batch.update(_db.collection('friend_requests').doc(r.id), {
        'status': 'rejected',
        'responded_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            StreamBuilder<List<_FriendRequest>>(
              stream: _stream,
              builder: (_, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Dismiss all',
                  icon: const Icon(Icons.clear_all),
                  onPressed: () => _dismissAll(list),
                );
              },
            ),
          ],
        ),
        body: StreamBuilder<List<_FriendRequest>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final requests = snap.data ?? [];

            if (requests.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No notifications yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) => _RequestTile(
                request: requests[i],
                onAccept: () => _respond(requests[i].id, 'accepted'),
                onDecline: () => _respond(requests[i].id, 'rejected'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final _FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: request.fromProfilePhoto.isNotEmpty
            ? NetworkImage(request.fromProfilePhoto)
            : null,
        child: request.fromProfilePhoto.isEmpty
            ? Text(
                request.displayName[0].toUpperCase(),
                style: const TextStyle(fontSize: 18),
              )
            : null,
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: request.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const TextSpan(text: ' sent you a friend request'),
          ],
        ),
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        DateFormat('MMM d · h:mm a').format(request.sentAt),
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Accept'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onDecline,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}
