import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';
import 'package:flutter_education_app/features/chat/models/friend_request_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/avatar.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/empty_state.dart';
import 'package:timeago/timeago.dart' as timeago;

class RequestsTab extends StatelessWidget {
  const RequestsTab({
    super.key,
    required this.currentUserId,
    required this.chatRepository,
  });

  final String currentUserId;
  final ChatRepository chatRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: chatRepository.watchIncomingRequests(currentUserId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final requests = snap.data ?? [];

        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.person_add_alt_1_outlined,
            title: 'No pending requests',
            subtitle: 'Requests from others will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 96),
          itemCount: requests.length,
          itemBuilder: (context, i) {
            return _RequestTile(
              request: requests[i],
              chatRepository: chatRepository,
            );
          },
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.chatRepository});

  final FriendRequestModel request;
  final ChatRepository chatRepository;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Avatar(
            displayName: request.fromUsername,
            photoUrl: request.fromProfilePhoto.isNotEmpty
                ? request.fromProfilePhoto
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // FIX 3: show full name if present, otherwise username
                  request.fromFullName.isNotEmpty
                      ? request.fromFullName
                      : request.fromUsername,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                if (request.fromFullName.isNotEmpty)
                  Text(
                    '@${request.fromUsername}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(request.sentAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () async {
                  await chatRepository.respondToFriendRequest(
                    request.id!,
                    FriendRequestStatus.accepted,
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Accept'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await chatRepository.respondToFriendRequest(
                    request.id!,
                    FriendRequestStatus.rejected,
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
