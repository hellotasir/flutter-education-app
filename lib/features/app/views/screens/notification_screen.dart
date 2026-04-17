// lib/features/notifications/notification_screen.dart

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/views/widgets/material_widget.dart';
import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';
import 'package:flutter_education_app/features/chat/models/friend_request_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    required this.currentUserId,
    required this.chatRepository,
  });

  final String currentUserId;
  final ChatRepository chatRepository;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Stream<List<FriendRequestModel>> get _stream => widget.currentUserId.isEmpty
      ? Stream.value([])
      : widget.chatRepository.watchIncomingRequests(widget.currentUserId);

  @override
  void initState() {
    super.initState();
    _clearBadge();
  }

  Future<void> _clearBadge() async {
    // Clear app icon badge
    await AppBadgePlus.updateBadge(0);

    // Clear seen IDs so the background service re-notifies if needed
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bg_seen_request_ids');
  }

  Future<void> _respond(String requestId, FriendRequestStatus status) =>
      widget.chatRepository.respondToFriendRequest(requestId, status);

  Future<void> _dismissAll(List<FriendRequestModel> requests) => Future.wait(
    requests.map(
      (r) => widget.chatRepository.respondToFriendRequest(
        r.id!,
        FriendRequestStatus.rejected,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: _stream,
      builder: (context, snap) {
        final requests = snap.data ?? [];

        // Keep badge in sync while screen is open
        AppBadgePlus.updateBadge(0);

        return MaterialWidget(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Notifications'),
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              actions: [
                if (requests.isNotEmpty)
                  IconButton(
                    tooltip: 'Dismiss all',
                    icon: const Icon(Icons.clear_all),
                    onPressed: () => _dismissAll(requests),
                  ),
              ],
            ),
            body: _buildBody(context, snap, requests),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<FriendRequestModel>> snap,
    List<FriendRequestModel> requests,
  ) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load notifications.\n\n${snap.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No notifications yet.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final req = requests[i];
        return _RequestTile(
          request: req,
          onAccept: () => _respond(req.id!, FriendRequestStatus.accepted),
          onDecline: () => _respond(req.id!, FriendRequestStatus.rejected),
        );
      },
    );
  }
}



class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequestModel request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Prefers full name; falls back to @username.
  String get _displayName => request.fromFullName.isNotEmpty
      ? request.fromFullName
      : '@${request.fromUsername}';

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
                _displayName[0].toUpperCase(),
                style: const TextStyle(fontSize: 18),
              )
            : null,
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: _displayName,
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
